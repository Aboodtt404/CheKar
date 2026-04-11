import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _apiKeyKey = 'api_key';
  static const _historyKey = 'inspection_history';
  static const _obdHistoryKey = 'obd_history';
  late final SharedPreferences _prefs;

  Future<void> init() async { _prefs = await SharedPreferences.getInstance(); }
  String? get apiKey => _prefs.getString(_apiKeyKey);
  Future<void> saveApiKey(String key) => _prefs.setString(_apiKeyKey, key);
  Future<void> clearApiKey() => _prefs.remove(_apiKeyKey);
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;
  List<String> get inspectionHistory => _prefs.getStringList(_historyKey) ?? [];
  Future<void> addToHistory(String json) async {
    final h = inspectionHistory; h.insert(0, json);
    if (h.length > 50) h.removeLast();
    await _prefs.setStringList(_historyKey, h);
  }

  List<String> get obdHistory => _prefs.getStringList(_obdHistoryKey) ?? [];
  Future<void> addObdResult(String json) async {
    final h = obdHistory; h.insert(0, json);
    if (h.length > 20) h.removeLast();
    await _prefs.setStringList(_obdHistoryKey, h);
  }
}
