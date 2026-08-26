import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';

class SettingsLocalDatasource {
  final DatabaseHelper _dbHelper;
  static const String _spPrefix = 'app_setting_';

  SettingsLocalDatasource(this._dbHelper);

  Future<String?> getValue(String key) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_spPrefix$key');
  }

  Future<void> setValue(String key, String value) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      AppConstants.tableSettings,
      {'key': key, 'value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_spPrefix$key', value);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query(AppConstants.tableSettings);
    final dbSettings = {
      for (final row in maps) row['key'] as String: row['value'] as String,
    };

    final prefs = await SharedPreferences.getInstance();
    final spSettings = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_spPrefix)) continue;
      final originalKey = key.substring(_spPrefix.length);
      final value = prefs.getString(key);
      if (value != null) {
        spSettings[originalKey] = value;
      }
    }

    final merged = <String, String>{...spSettings, ...dbSettings};

    // DB가 비어 있는데 백업 복원된 설정이 있으면 DB도 동기화한다.
    if (dbSettings.isEmpty && merged.isNotEmpty) {
      await setMultiple(merged);
    }

    return merged;
  }

  Future<void> setMultiple(Map<String, String> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in settings.entries) {
      batch.insert(
        AppConstants.tableSettings,
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    final prefs = await SharedPreferences.getInstance();
    for (final entry in settings.entries) {
      await prefs.setString('$_spPrefix${entry.key}', entry.value);
    }
  }
}

