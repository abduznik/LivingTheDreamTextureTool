import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keySelectedPath = 'selected_resource_path';
  static const String _keyAutoLoad = 'auto_load_resource_path';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  String? get selectedPath => _prefs.getString(_keySelectedPath);

  Future<void> setSelectedPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_keySelectedPath);
    } else {
      await _prefs.setString(_keySelectedPath, path);
    }
  }

  bool get autoLoad => _prefs.getBool(_keyAutoLoad) ?? false;

  Future<void> setAutoLoad(bool value) async {
    await _prefs.setBool(_keyAutoLoad, value);
  }
}
