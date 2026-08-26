import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/data/services/in_app_sync_receiver_service.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final receiver = InAppSyncReceiverService.instance;

  setUp(() async {
    await receiver.stop();
  });

  tearDown(() async {
    await receiver.stop();
  });

  test('sync receiver rejects request bodies larger than 10 MB', () async {
    await _startReceiver(receiver, token: 'sync-secret');

    final status = await _post(
      receiver,
      Uint8List(InAppSyncReceiverService.maxRequestBodyBytes + 1),
      bearerToken: 'sync-secret',
    );

    expect(status, HttpStatus.requestEntityTooLarge);
  });

  test('sync receiver accepts a normal body when token is not configured',
      () async {
    await _startReceiver(receiver);

    final status = await _post(receiver, _unsupportedEventBody());

    expect(status, HttpStatus.badRequest);
  });

  test('sync receiver accepts the exact configured Bearer token', () async {
    await _startReceiver(receiver, token: 'Bearer sync-secret');

    final status = await _post(
      receiver,
      _unsupportedEventBody(),
      bearerToken: 'sync-secret',
    );

    expect(status, HttpStatus.badRequest);
  });

  test('sync receiver rejects a same-length incorrect Bearer token', () async {
    await _startReceiver(receiver, token: 'sync-secret');

    final status = await _post(
      receiver,
      _unsupportedEventBody(),
      bearerToken: 'sync-secrex',
    );

    expect(status, HttpStatus.unauthorized);
  });
}

Future<void> _startReceiver(
  InAppSyncReceiverService receiver, {
  String token = '',
}) async {
  final settings = _MemorySettingsRepository({
    AppConstants.settingVocSyncBearerToken: token,
  });
  await receiver.start(
    settingsRepository: settings,
    port: 0,
    address: InternetAddress.loopbackIPv4,
  );
  expect(receiver.boundPort, isNotNull);
}

Future<int> _post(
  InAppSyncReceiverService receiver,
  List<int> body, {
  String? bearerToken,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${receiver.boundPort}/webhook/voc'),
    );
    request.headers.contentType = ContentType.json;
    if (bearerToken != null) {
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }
    request.contentLength = body.length;
    request.add(body);

    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

List<int> _unsupportedEventBody() {
  return utf8.encode(jsonEncode({'event': 'unsupported'}));
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(this._values);

  final Map<String, String> _values;

  @override
  Future<Map<String, String>> getAllSettings() async => Map.of(_values);

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<void> setMultiple(Map<String, String> settings) async {
    _values.addAll(settings);
  }

  @override
  Future<void> setValue(String key, String value) async {
    _values[key] = value;
  }
}
