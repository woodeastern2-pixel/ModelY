import 'dart:io';
import 'dart:convert';
import 'package:ai_voc_assistant/data/services/in_app_sync_receiver_service.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';

import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent opens share one database and reopening preserves admin password', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('voc-startup-');
    await databaseFactory.setDatabasesPath(dir.path);
    final helper = DatabaseHelper.instance;
    addTearDown(() async {
      await helper.close();
      await dir.delete(recursive: true);
    });
    final connections = await Future.wait(List.generate(5, (_) => helper.database));
    expect(connections.every((db) => identical(db, connections.first)), isTrue);
    await connections.first.update(AppConstants.tableSettings,
        {'value': 'custom-password'}, where: 'key = ?',
        whereArgs: [AppConstants.settingAdminPassword]);
    // Exercise the real HTTP receiver and real schema, not only the SQL helper.
    final receiver = InAppSyncReceiverService.instance;
    await receiver.start(settingsRepository: _Settings(), port: 0,
        address: InternetAddress.loopbackIPv4);
    try {
      final voc = {
        'id': 'network-original', 'title': '메일 등록', 'content': '메일 등록 방법',
        'customer': '고객', 'project': '메일', 'category': '기타',
        'created_at': '2026-09-29T09:00:00Z', 'updated_at': '2026-09-29T09:00:00Z',
      };
      final event = {'event': 'voc.created', 'source_app': 'origin', 'voc': voc};
      final created = await post(receiver, '/webhook/voc', event);
      expect(created['action'], 'created');
      final duplicates = await Future.wait(List.generate(8,
          (_) => post(receiver, '/webhook/voc', event)));
      expect(duplicates.every((r) => r['action'] == 'duplicate'), isTrue);
      final full = {
        'event': 'sync.full', 'source_app': 'origin',
        'snapshot': {
          'vocs': [{...voc, 'id': 'legacy-copy', 'source': 'peer-pull',
            'source_ref': 'origin:network-original'}],
          'responses': [{
            'id': 'answer', 'voc_id': 'legacy-copy', 'content': '보존할 답변',
            'created_at': voc['created_at'], 'updated_at': voc['updated_at'],
          }],
        },
      };
      await post(receiver, '/webhook/sync/full', full);
      await post(receiver, '/webhook/sync/full', full);
      expect(await connections.first.query('vocs'), hasLength(1));
      final response = (await connections.first.query('responses')).single;
      expect(response['voc_id'], 'network-original');
      expect(response['content'], '보존할 답변');
    } finally {
      await receiver.stop();
    }
    await helper.close();
    final reopened = await helper.database;
    final row = (await reopened.query(AppConstants.tableSettings,
        where: 'key = ?', whereArgs: [AppConstants.settingAdminPassword])).single;
    expect(row['value'], 'custom-password');
  });
}

Future<Map<String, dynamic>> post(InAppSyncReceiverService receiver,
    String path, Map<String, dynamic> body) async {
  final client = _LoopbackHttpOverrides().createHttpClient(null);
  try {
    final request = await client.postUrl(Uri.parse(
        'http://127.0.0.1:${receiver.boundPort}$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    expect(response.statusCode, 200, reason: text);
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

class _Settings implements SettingsRepository {
  @override
  Future<String?> getValue(String key) async => null;
  @override
  Future<void> setValue(String key, String value) async {}
  @override
  Future<Map<String, String>> getAllSettings() async => {};
  @override
  Future<void> setMultiple(Map<String, String> settings) async {}
}

// Use the real loopback transport instead of the widget test HTTP stub.
class _LoopbackHttpOverrides extends HttpOverrides {}
