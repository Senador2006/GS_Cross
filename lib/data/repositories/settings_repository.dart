import '../../core/constants/territory.dart';
import '../models/app_preferences.dart';
import '../models/threshold.dart';
import '../services/local_storage_service.dart';

/// Persistência de preferências, consentimento e limiares de alerta.
class SettingsRepository {
  SettingsRepository(this._storage);

  final LocalStorageService _storage;

  AppPreferences readPreferences() {
    final json = _storage.readMap(LocalStorageService.keyPreferences);
    if (json == null) return const AppPreferences();
    try {
      return AppPreferences.fromJson(json);
    } catch (_) {
      return const AppPreferences();
    }
  }

  Future<void> savePreferences(AppPreferences prefs) =>
      _storage.writeJson(LocalStorageService.keyPreferences, prefs.toJson());

  ConsentRecord? readConsent() {
    final json = _storage.readMap(LocalStorageService.keyConsent);
    if (json == null) return null;
    try {
      return ConsentRecord.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConsent(ConsentRecord consent) =>
      _storage.writeJson(LocalStorageService.keyConsent, consent.toJson());

  Future<void> revokeConsent() =>
      _storage.remove(LocalStorageService.keyConsent);

  /// Limiares salvos, completados com os padrões do catálogo.
  Map<String, AlertThreshold> readThresholds() {
    final saved = <String, AlertThreshold>{};
    for (final json in _storage.readList(LocalStorageService.keyThresholds)) {
      try {
        final t = AlertThreshold.fromJson(json);
        saved[t.indicatorId] = t;
      } catch (_) {
        /* ignora entrada inválida */
      }
    }
    return {
      for (final def in IndicatorCatalog.all)
        def.id: saved[def.id] ?? AlertThreshold.defaultFor(def),
    };
  }

  Future<void> saveThresholds(Map<String, AlertThreshold> thresholds) =>
      _storage.writeJson(
        LocalStorageService.keyThresholds,
        thresholds.values.map((t) => t.toJson()).toList(),
      );

  Future<void> clearAll() => _storage.clearAll();
}
