import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

/// App-owned, offline inference. Never downloads files or uses a configured URL.
class BundledQwenService {
  BundledQwenService({Directory? bundleDirectory})
      : bundleDirectory = bundleDirectory ??
            Directory(p.join(p.dirname(Platform.resolvedExecutable), 'local_ai'));

  static final instance = BundledQwenService();
  static const modelName = 'Qwen3-1.7B';
  static const modelFile = 'Qwen3-1.7B-Q8_0.gguf';
  static const modelSha256 =
      '061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a';
  static const requestTimeout = Duration(seconds: 150);
  final Directory bundleDirectory;
  Process? _process;
  Future<void>? _starting;
  Uri? _baseUri;
  String? _sessionKey;
  bool _generating = false;
  Timer? _idleTimer;
  int _generation = 0;
  String? _verifiedModel;

  File get _server => File(p.join(bundleDirectory.path, 'runtime',
      Platform.isWindows ? 'llama-server.exe' : 'llama-server'));
  File get _model => File(p.join(bundleDirectory.path, 'models', modelFile));
  bool get isInstalled => (Platform.isWindows || Platform.isLinux) &&
      _server.existsSync() && _model.existsSync();

  http.Client _client() {
    // Corporate proxies must never receive an offline prompt or session key.
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 3);
    return IOClient(client);
  }

  Future<void> ensureReady() async {
    _idleTimer?.cancel();
    if (_process != null && _baseUri != null && _starting == null) return;
    final current = _starting;
    if (current != null) return current;
    final future = _start();
    _starting = future;
    try {
      await future;
    } finally {
      if (identical(_starting, future)) _starting = null;
    }
  }

  Future<void> _start() async {
    if (!isInstalled) {
      throw StateError('내장 Qwen 파일을 찾을 수 없습니다. Qwen 포함 Windows 설치본으로 설치해 주세요.');
    }
    final generation = ++_generation;
    if (_verifiedModel != _model.path) {
      final digest = await sha256.bind(_model.openRead()).first;
      if (digest.toString() != modelSha256) {
        throw StateError('내장 모델 파일이 손상되었습니다. Qwen 포함 설치본으로 다시 설치해 주세요.');
      }
      _verifiedModel = _model.path;
    }
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = listener.port;
    await listener.close();
    final random = Random.secure();
    final key = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    final uri = Uri.parse('http://127.0.0.1:$port');
    final threads = max(1, min(8, Platform.numberOfProcessors ~/ 2));
    Process? child;
    final client = _client();
    try {
      child = await Process.start(_server.path, [
        '--model', _model.path,
        '--alias', modelName,
        '--host', '127.0.0.1', '--port', '$port',
        '--ctx-size', '8192', '--parallel', '1',
        '--threads', '$threads', '--threads-batch', '$threads',
        '--n-gpu-layers', '0', '--jinja',
        '--chat-template-kwargs', '{"enable_thinking":false}',
        '--no-webui', '--no-context-shift',
      ], workingDirectory: _server.parent.path, environment: {
        'LLAMA_API_KEY': key,
        'HF_HUB_OFFLINE': '1',
        'NO_PROXY': '127.0.0.1,localhost',
      });
      if (Platform.isWindows) {
        final attached = await const MethodChannel('voc_mate/qwen_process')
            .invokeMethod<bool>('attach', child.pid);
        if (attached != true) {
          throw StateError('내장 모델 실행 관리자를 준비하지 못했습니다. 앱을 다시 실행해 주세요.');
        }
      }
      _process = child;
      // Drain without retaining prompts, credentials, or user content in logs.
      unawaited(child.stdout.drain<void>());
      unawaited(child.stderr.drain<void>());
      unawaited(child.exitCode.then((_) {
        if (identical(_process, child)) {
          _process = null;
          _baseUri = null;
          _sessionKey = null;
        }
      }));
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline)) {
        if (generation != _generation || !identical(_process, child)) {
          throw StateError('내장 Qwen 실행이 중단되었습니다. 다시 시도해 주세요.');
        }
        try {
          final health = await client.get(uri.resolve('/health'))
              .timeout(const Duration(seconds: 2));
          if (health.statusCode != 200) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          // /models requires the session key, unlike the public /health route.
          final response = await client.get(uri.resolve('/v1/models'), headers: {
            'Authorization': 'Bearer $key',
          }).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            final payload = jsonDecode(response.body) as Map<String, dynamic>;
            final models = payload['data'] as List? ?? const [];
            if (models.any((m) => m is Map && m['id'] == modelName)) {
              _baseUri = uri;
              _sessionKey = key;
              return;
            }
          }
        } catch (_) {
          // A process that is still loading may not have opened its listener.
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      throw TimeoutException('내장 Qwen을 준비하지 못했습니다. 메모리를 확보한 뒤 다시 시도해 주세요.');
    } catch (_) {
      if (child != null) child.kill();
      if (identical(_process, child)) _process = null;
      _baseUri = null;
      _sessionKey = null;
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<String> generate(String systemPrompt, String userPrompt,
      {double temperature = 0.3, int maxTokens = 512}) async {
    if (_generating) {
      throw StateError('내장 Qwen이 이전 요청을 처리 중입니다. 완료 후 다시 시도해 주세요.');
    }
    _generating = true;
    final client = _client();
    try {
      await ensureReady();
      final response = await client.post(_baseUri!.resolve('/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_sessionKey',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': temperature.clamp(0.1, 1.0),
            'max_tokens': maxTokens.clamp(64, 768),
            'top_p': 0.8, 'top_k': 20, 'min_p': 0.0,
            'stream': false,
            'chat_template_kwargs': {'enable_thinking': false},
          })).timeout(requestTimeout);
      if (response.statusCode != 200) {
        if (response.statusCode == 400 || response.statusCode == 413) {
          throw StateError('내장 모델의 입력 한도를 넘었거나 요청을 처리할 수 없습니다. 질문이나 참고 자료를 줄여 주세요.');
        }
        throw StateError('내장 Qwen 응답 오류 (${response.statusCode}). 다시 시도해 주세요.');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choice = (payload['choices'] as List).first as Map;
      if (choice['finish_reason'] == 'length') {
        throw StateError('내장 모델의 답변이 길이 제한으로 중단되었습니다. 질문 범위를 좁혀 다시 시도해 주세요.');
      }
      final raw = (choice['message'] as Map)['content']?.toString() ?? '';
      final answer = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
      if (answer.isEmpty) throw StateError('내장 Qwen이 빈 답변을 반환했습니다. 다시 시도해 주세요.');
      return answer;
    } on TimeoutException {
      // Cancel the local work too; a timed-out generation must not fill a queue.
      await stop();
      throw TimeoutException('내장 Qwen 응답 시간이 초과되었습니다. 질문 범위를 줄여 다시 시도해 주세요.');
    } finally {
      client.close();
      _generating = false;
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(minutes: 5), () => unawaited(stop()));
    }
  }

  Future<void> stop() async {
    ++_generation;
    _idleTimer?.cancel();
    final child = _process;
    _process = null;
    _baseUri = null;
    _sessionKey = null;
    if (child != null) {
      child.kill();
      try {
        await child.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        child.kill(ProcessSignal.sigkill);
      }
    }
  }
}
