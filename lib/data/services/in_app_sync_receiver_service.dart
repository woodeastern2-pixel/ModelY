import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/voc_category_catalog.dart';
import '../../domain/repositories/settings_repository.dart';

class InAppSyncReceiverService {
  InAppSyncReceiverService._();

  static final InAppSyncReceiverService instance = InAppSyncReceiverService._();
  static const int maxRequestBodyBytes = 10 * 1024 * 1024;

  HttpServer? _server;
  bool _starting = false;
  int _port = 8788;
  InternetAddress _address = InternetAddress.anyIPv4;
  SettingsRepository? _settingsRepository;
  Timer? _watchdog;
  String? _lastError;
  DateTime? _lastStartedAt;
  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;
  String? get lastError => _lastError;
  DateTime? get lastStartedAt => _lastStartedAt;

  Future<void> start({
    required SettingsRepository settingsRepository,
    int port = 8788,
    InternetAddress? address,
  }) async {
    _settingsRepository = settingsRepository;
    _port = port;
    _address = address ?? InternetAddress.anyIPv4;

    await _ensureRunning();
    _watchdog ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_ensureRunning()),
    );
  }

  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _ensureRunning() async {
    if (_server != null || _starting) {
      return;
    }
    final settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      return;
    }

    _starting = true;

    try {
      final server = await HttpServer.bind(_address, _port, shared: true);
      _server = server;
      _lastError = null;
      _lastStartedAt = DateTime.now();

      _logEvent(
        eventType: 'receiver.start',
        sourceApp: null,
        syncMode: null,
        status: 'running',
        endpoint: '/health',
        message: 'In-app sync receiver started on ${_address.address}:$_port',
        counts: const {},
      );

      server.listen(
        (request) => _handleRequest(request, settingsRepository),
        onError: (Object error, StackTrace stackTrace) {
          _lastError = 'Server stream error: $error';
          _server = null;
          _logEvent(
            eventType: 'receiver.error',
            sourceApp: null,
            syncMode: null,
            status: 'error',
            endpoint: null,
            message: _lastError,
            counts: const {},
          );
        },
        onDone: () {
          _server = null;
          _logEvent(
            eventType: 'receiver.stop',
            sourceApp: null,
            syncMode: null,
            status: 'stopped',
            endpoint: null,
            message: 'In-app receiver stream closed',
            counts: const {},
          );
        },
        cancelOnError: false,
      );
    } catch (e) {
      _lastError = 'In-app sync receiver start failed: $e';
      _logEvent(
        eventType: 'receiver.start',
        sourceApp: null,
        syncMode: null,
        status: 'failed',
        endpoint: null,
        message: _lastError,
        counts: const {},
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> _handleRequest(
    HttpRequest request,
    SettingsRepository settingsRepository,
  ) async {
    final path = _normalizePath(request.uri.path);
    try {
      if (request.method == 'GET' && (path == '/' || path == '/health')) {
        await _handleHealth(request);
        return;
      }

      if (request.method == 'GET' &&
          (path == '/webhook/sync/export' || path == '/webhook/voc/export')) {
        final token = (await settingsRepository
                    .getValue(AppConstants.settingVocSyncBearerToken))
                ?.trim() ??
            '';
        final authOk = _checkAuthorization(request, token);
        if (!authOk) {
          await _writeJson(
            request.response,
            HttpStatus.unauthorized,
            {'detail': 'invalid or missing authorization'},
          );
          return;
        }
        await _handleVocExport(request, settingsRepository);
        return;
      }

      if (request.method != 'POST') {
        await _writeJson(
          request.response,
          HttpStatus.methodNotAllowed,
          {'detail': 'method not allowed'},
        );
        return;
      }

      final token = (await settingsRepository
                  .getValue(AppConstants.settingVocSyncBearerToken))
              ?.trim() ??
          '';
      final authOk = _checkAuthorization(request, token);
      if (!authOk) {
        await _writeJson(
          request.response,
          HttpStatus.unauthorized,
          {'detail': 'invalid or missing authorization'},
        );
        return;
      }

      final raw = await _readRequestBody(request);
      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        await _writeJson(
          request.response,
          HttpStatus.badRequest,
          {'detail': 'invalid payload'},
        );
        return;
      }

      if (path == '/webhook/voc' || path == '/voc') {
        await _handleVocEvent(request, payload);
        return;
      }

      if (path == '/webhook/sync/full' || path == '/webhook/sync') {
        await _handleFullSync(request, payload);
        return;
      }

      await _writeJson(
        request.response,
        HttpStatus.notFound,
        {'detail': 'not found'},
      );
    } on _PayloadTooLargeException {
      await _writeJson(
        request.response,
        HttpStatus.requestEntityTooLarge,
        {'detail': 'request body exceeds 10 MB'},
      );
    } catch (e) {
      await _writeJson(
        request.response,
        HttpStatus.internalServerError,
        {'detail': 'receiver error: $e'},
      );
      _logEvent(
        eventType: 'receiver.error',
        sourceApp: null,
        syncMode: null,
        status: 'error',
        endpoint: path,
        message: 'Request handling failed: $e',
        counts: const {},
      );
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${AppConstants.tableVocs}',
    );
    final vocCount = (row.first['cnt'] as int?) ?? 0;

    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'status': 'ok',
        'receiver': 'in-app',
        'voc_count': vocCount,
      },
    );
  }

  Future<void> _handleVocExport(
    HttpRequest request,
    SettingsRepository settingsRepository,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final vocRows = await db.query(
      AppConstants.tableVocs,
      orderBy: 'created_at DESC',
    );
    final manualRows = await db.query(
      AppConstants.tableKnowledgeBase,
      where: 'category = ? OR project = ?',
      whereArgs: const ['시스템매뉴얼', 'manual-upload'],
      orderBy: 'created_at DESC',
    );

    final appName =
        (await settingsRepository.getValue(AppConstants.settingAppInstanceName))
                ?.trim() ??
            '';

    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'ok': true,
        'event': 'sync.export',
        'source_app': appName.isEmpty ? 'unknown-app' : appName,
        'snapshot': {
          'vocs': vocRows,
          'manuals': manualRows,
        },
      },
    );
  }

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  Future<void> _handleVocEvent(
    HttpRequest request,
    Map<String, dynamic> payload,
  ) async {
    final event = payload['event']?.toString() ?? '';
    if (event != 'voc.created') {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'detail': 'unsupported event'},
      );
      return;
    }

    final voc = (payload['voc'] is Map)
        ? Map<String, dynamic>.from(payload['voc'] as Map)
        : <String, dynamic>{};
    final sourceApp = payload['source_app']?.toString() ?? 'unknown-app';

    final now = DateTime.now().toIso8601String();
    final sourceRef = '$sourceApp:${voc['id'] ?? ''}';
    final db = await DatabaseHelper.instance.database;

    final exists = await db.query(
      AppConstants.tableVocs,
      columns: ['id'],
      where: 'source = ? AND source_ref = ?',
      whereArgs: ['peer-sync', sourceRef],
      limit: 1,
    );

    if (exists.isNotEmpty) {
      await _writeJson(
        request.response,
        HttpStatus.ok,
        {
          'ok': true,
          'action': 'duplicate',
          'id': exists.first['id'],
          'source_ref': sourceRef,
        },
      );
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final normalizedCategory = VocCategoryCatalog.normalize(
      voc['category']?.toString(),
      title: voc['title']?.toString(),
      content: voc['content']?.toString(),
      aiCategory: voc['ai_category']?.toString(),
      tags: voc['tags']?.toString(),
    );
    await db.insert(AppConstants.tableVocs, {
      'id': id,
      'title': (voc['title']?.toString().trim().isNotEmpty == true)
          ? voc['title'].toString().trim()
          : '제목없음',
      'content': (voc['content']?.toString().trim().isNotEmpty == true)
          ? voc['content'].toString().trim()
          : '내용 없음',
      'category': normalizedCategory,
      'tags': voc['tags']?.toString(),
      'customer': (voc['customer']?.toString().trim().isNotEmpty == true)
          ? voc['customer'].toString().trim()
          : '미입력',
      'project': (voc['project']?.toString().trim().isNotEmpty == true)
          ? voc['project'].toString().trim()
          : '미입력',
      'priority': (voc['priority']?.toString().trim().isNotEmpty == true)
          ? voc['priority'].toString().trim()
          : 'MEDIUM',
      'status': (voc['status']?.toString().trim().isNotEmpty == true)
          ? voc['status'].toString().trim()
          : 'OPEN',
      'urgency': voc['urgency']?.toString(),
      'business_type': voc['business_type']?.toString(),
      'source': 'peer-sync',
      'source_ref': sourceRef,
      'created_at': voc['created_at']?.toString() ?? now,
      'updated_at': voc['updated_at']?.toString() ?? now,
    });

    await _logEvent(
      eventType: 'voc.created',
      sourceApp: sourceApp,
      syncMode: 'upsert',
      status: 'created',
      endpoint: '/webhook/voc',
      message: 'VOC 단건 동기화 수신',
      counts: const {'vocs': 1, 'responses': 0, 'manuals': 0},
    );

    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'ok': true,
        'action': 'created',
        'id': id,
        'source_ref': sourceRef,
      },
    );
  }

  Future<void> _handleFullSync(
    HttpRequest request,
    Map<String, dynamic> payload,
  ) async {
    final event = payload['event']?.toString() ?? '';
    if (event != 'sync.full') {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'detail': 'unsupported event'},
      );
      return;
    }

    final sourceApp = payload['source_app']?.toString() ?? 'unknown-app';
    final syncMode = payload['sync_mode']?.toString() ?? 'upsert';
    final snapshot = (payload['snapshot'] is Map)
        ? Map<String, dynamic>.from(payload['snapshot'] as Map)
        : <String, dynamic>{};

    final vocs = (snapshot['vocs'] as List?) ?? const [];
    final responses = (snapshot['responses'] as List?) ?? const [];
    final manuals = (snapshot['manuals'] as List?) ?? const [];

    final db = await DatabaseHelper.instance.database;
    int vocCount = 0;
    int responseCount = 0;
    int manualCount = 0;

    await db.transaction((txn) async {
      for (final item in vocs) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final normalizedCategory = VocCategoryCatalog.normalize(
          row['category']?.toString(),
          title: row['title']?.toString(),
          content: row['content']?.toString(),
          aiCategory: row['ai_category']?.toString(),
          tags: row['tags']?.toString(),
        );
        await txn.insert(
          AppConstants.tableVocs,
          {
            'id': id,
            'title': row['title']?.toString() ?? '제목없음',
            'content': row['content']?.toString() ?? '내용 없음',
            'category': normalizedCategory,
            'tags': row['tags']?.toString(),
            'customer': row['customer']?.toString() ?? '미입력',
            'project': row['project']?.toString() ?? '미입력',
            'priority': row['priority']?.toString() ?? 'MEDIUM',
            'status': row['status']?.toString() ?? 'OPEN',
            'ai_category': row['ai_category']?.toString(),
            'is_business_related':
                int.tryParse('${row['is_business_related'] ?? 1}') ?? 1,
            'business_score': row['business_score'],
            'category_score': row['category_score'],
            'urgency': row['urgency']?.toString(),
            'urgency_score': row['urgency_score'],
            'business_type': row['business_type']?.toString(),
            'department': row['department']?.toString(),
            'department_score': row['department_score'],
            'assignee': row['assignee']?.toString(),
            'assignee_score': row['assignee_score'],
            'duplicate_of_voc_id': row['duplicate_of_voc_id']?.toString(),
            'duplicate_score': row['duplicate_score'],
            'jira_required': int.tryParse('${row['jira_required'] ?? 0}') ?? 0,
            'jira_score': row['jira_score'],
            'analysis_reason': row['analysis_reason']?.toString(),
            'embedding': row['embedding']?.toString(),
            'source': row['source']?.toString() ?? 'peer-sync-full',
            'source_ref': row['source_ref']?.toString(),
            'processing_minutes':
                int.tryParse('${row['processing_minutes'] ?? ''}'),
            'created_at': row['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'updated_at': row['updated_at']?.toString() ??
                DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        vocCount += 1;
      }

      for (final item in responses) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = row['id']?.toString();
        final vocId = row['voc_id']?.toString();
        if (id == null || id.isEmpty || vocId == null || vocId.isEmpty) {
          continue;
        }

        await txn.insert(
          AppConstants.tableResponses,
          {
            'id': id,
            'voc_id': vocId,
            'content': row['content']?.toString() ?? '',
            'status': row['status']?.toString() ?? 'DRAFT',
            'ai_generated': int.tryParse('${row['ai_generated'] ?? 0}') ?? 0,
            'confidence_score': row['confidence_score'],
            'referenced_voc_ids': row['referenced_voc_ids']?.toString(),
            'approved_by': row['approved_by']?.toString(),
            'approved_at': row['approved_at']?.toString(),
            'adoption_count':
                int.tryParse('${row['adoption_count'] ?? 0}') ?? 0,
            'usage_count': int.tryParse('${row['usage_count'] ?? 0}') ?? 0,
            'last_used_at': row['last_used_at']?.toString(),
            'created_at': row['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'updated_at': row['updated_at']?.toString() ??
                DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        responseCount += 1;
      }

      for (final item in manuals) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final question = row['question']?.toString() ?? '';
        final answer = row['answer']?.toString() ?? '';
        if (question.isEmpty || answer.isEmpty) continue;

        await txn.insert(
          AppConstants.tableKnowledgeBase,
          {
            'id': id,
            'question': question,
            'answer': answer,
            'category': row['category']?.toString() ?? '시스템매뉴얼',
            'customer': row['customer']?.toString(),
            'project': row['project']?.toString() ?? 'manual-upload',
            'voc_id': row['voc_id']?.toString(),
            'embedding': row['embedding']?.toString(),
            'resolved_at': row['resolved_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'created_at': row['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        manualCount += 1;
      }
    });

    await _logEvent(
      eventType: 'sync.full',
      sourceApp: sourceApp,
      syncMode: syncMode,
      status: 'applied',
      endpoint: '/webhook/sync/full',
      message: '전체 VOC/매뉴얼 동기화 수신',
      counts: {
        'vocs': vocCount,
        'responses': responseCount,
        'manuals': manualCount,
      },
    );

    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'ok': true,
        'action': 'sync.full.applied',
        'source_app': sourceApp,
        'sync_mode': syncMode,
        'counts': {
          'vocs': vocCount,
          'responses': responseCount,
          'manuals': manualCount,
        },
      },
    );
  }

  bool _checkAuthorization(HttpRequest request, String token) {
    final normalizedToken = _normalizeBearerToken(token);
    if (normalizedToken.isEmpty) {
      return true;
    }
    final auth = request.headers.value(HttpHeaders.authorizationHeader);
    if (auth == null || auth.trim().isEmpty) {
      return false;
    }
    final parts = auth.trim().split(' ');
    if (parts.length != 2 || parts[0].toLowerCase() != 'bearer') {
      return false;
    }
    return _constantTimeEquals(
      _normalizeBearerToken(parts[1]),
      normalizedToken,
    );
  }

  bool _constantTimeEquals(String actual, String expected) {
    final actualBytes = utf8.encode(actual);
    final expectedBytes = utf8.encode(expected);
    if (actualBytes.length != expectedBytes.length) return false;

    var difference = 0;
    for (var i = 0; i < actualBytes.length; i++) {
      difference |= actualBytes[i] ^ expectedBytes[i];
    }
    return difference == 0;
  }

  Future<String> _readRequestBody(HttpRequest request) async {
    final declaredLength = request.contentLength;
    if (declaredLength > maxRequestBodyBytes) {
      throw const _PayloadTooLargeException();
    }

    final buffer = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in request) {
      received += chunk.length;
      if (received > maxRequestBodyBytes) {
        throw const _PayloadTooLargeException();
      }
      buffer.add(chunk);
    }
    return utf8.decode(buffer.takeBytes());
  }

  String _normalizeBearerToken(String raw) {
    var value = raw.trim();
    if (value.toLowerCase().startsWith('bearer ')) {
      value = value.substring(7).trim();
    }
    return value;
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _logEvent({
    required String eventType,
    required String? sourceApp,
    required String? syncMode,
    required String status,
    required String? endpoint,
    required String? message,
    required Map<String, int> counts,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(AppConstants.tableSyncEvents, {
        'event_type': eventType,
        'source_app': sourceApp,
        'sync_mode': syncMode,
        'status': status,
        'endpoint': endpoint,
        'message': message,
        'counts_json': jsonEncode(counts),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // logging failure should not break sync
    }
  }
}

class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}
