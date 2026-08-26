abstract class SettingsRepository {
  Future<String?> getValue(String key);
  Future<void> setValue(String key, String value);
  Future<Map<String, String>> getAllSettings();
  Future<void> setMultiple(Map<String, String> settings);
}
