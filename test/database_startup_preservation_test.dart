import 'dart:io';

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
    await helper.close();
    final reopened = await helper.database;
    final row = (await reopened.query(AppConstants.tableSettings,
        where: 'key = ?', whereArgs: [AppConstants.settingAdminPassword])).single;
    expect(row['value'], 'custom-password');
  });
}
