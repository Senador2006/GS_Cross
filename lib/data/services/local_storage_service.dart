import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local chave-valor em JSON, sobre `shared_preferences`.
///
/// Escolhido por funcionar igualmente em Android, iOS e Web sem código
/// nativo extra; o volume de dados do app (cache de ~60 dias × 13 séries,
/// ocorrências e decisões) é pequeno o suficiente para esse armazenamento.
class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStorageService> create() async =>
      LocalStorageService(await SharedPreferences.getInstance());

  static const keyPreferences = 'prefs.v1';
  static const keyConsent = 'consent.v1';
  static const keyThresholds = 'thresholds.v1';
  static const keySnapshotCache = 'cache.snapshot.v1';
  static const keyOccurrences = 'occurrences.v1';
  static const keyDecisions = 'decisions.v1';
  static const keyInstallSalt = 'install.salt.v1';

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null; // Dado corrompido: trata como ausente.
    }
  }

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } on FormatException {
      return [];
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Remove todos os dados do app (direito de eliminação — LGPD art. 18).
  Future<void> clearAll() => _prefs.clear();
}
