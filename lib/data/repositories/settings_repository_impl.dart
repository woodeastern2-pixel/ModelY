import '../datasources/local/settings_local_datasource.dart';
import '../../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _localDatasource;

  SettingsRepositoryImpl(this._localDatasource);

  @override
  Future<String?> getValue(String key) => _localDatasource.getValue(key);

  @override
  Future<void> setValue(String key, String value) =>
      _localDatasource.setValue(key, value);

  @override
  Future<Map<String, String>> getAllSettings() =>
      _localDatasource.getAllSettings();

  @override
  Future<void> setMultiple(Map<String, String> settings) =>
      _localDatasource.setMultiple(settings);
}
