import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voc_assistant/core/database/database_helper.dart';
import 'package:ai_voc_assistant/data/datasources/local/settings_local_datasource.dart';
import 'package:ai_voc_assistant/data/repositories/settings_repository_impl.dart';
import 'package:ai_voc_assistant/data/services/in_app_sync_receiver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('isolated real application sync receiver for recording', () async {
    final root = Directory('${Directory.current.path}/artifacts/peer-data');
    root.createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => root.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(root.path);
    await DatabaseHelper.instance.database;
    final settings = SettingsRepositoryImpl(SettingsLocalDatasource(DatabaseHelper.instance));
    final receiver = InAppSyncReceiverService.instance;
    await receiver.start(settingsRepository: settings, port: 8789,
        address: InternetAddress.loopbackIPv4);
    expect(receiver.isRunning, isTrue);
    File('artifacts/peer-ready').writeAsStringSync('real production receiver on 8789');
    final clock = Stopwatch()..start();
    while (!File('artifacts/peer-stop').existsSync() && clock.elapsed.inMinutes < 22) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await receiver.stop();
  }, timeout: const Timeout(Duration(minutes: 24)));
}
