import 'package:material_ui/material_ui.dart';

import '../core/constants/territory.dart';
import '../core/utils/privacy.dart';
import '../data/models/app_preferences.dart';
import '../data/models/threshold.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/local_storage_service.dart';

/// Estado global de configuração: preferências de acessibilidade,
/// consentimento LGPD, perfil de uso e limiares de alerta.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo, this._storage) {
    _prefs = _repo.readPreferences();
    _consent = _repo.readConsent();
    _thresholds = _repo.readThresholds();
    _salt = _storage.readString(LocalStorageService.keyInstallSalt) ?? '';
  }

  final SettingsRepository _repo;
  final LocalStorageService _storage;

  late AppPreferences _prefs;
  ConsentRecord? _consent;
  late Map<String, AlertThreshold> _thresholds;
  late String _salt;

  AppPreferences get prefs => _prefs;
  ConsentRecord? get consent => _consent;
  bool get hasValidConsent => _consent?.isValid ?? false;
  bool get isManager => _prefs.role == UserRole.manager;
  Map<String, AlertThreshold> get thresholds => Map.unmodifiable(_thresholds);
  AlertThreshold thresholdFor(String id) => _thresholds[id]!;

  /// Pseudônimo do dispositivo (não identifica a pessoa).
  String get reporterPseudonym => Privacy.pseudonym(_salt);

  Future<void> updatePreferences(AppPreferences prefs) async {
    _prefs = prefs;
    notifyListeners();
    await _repo.savePreferences(prefs);
  }

  Future<void> acceptConsent({
    required bool approximateLocation,
    required UserRole role,
  }) async {
    if (_salt.isEmpty) {
      _salt = Privacy.newSalt();
      await _storage.writeString(LocalStorageService.keyInstallSalt, _salt);
    }
    _consent = ConsentRecord(
      version: ConsentRecord.currentVersion,
      acceptedAt: DateTime.now(),
      dataProcessing: true,
      approximateLocation: approximateLocation,
    );
    _prefs = _prefs.copyWith(role: role);
    notifyListeners();
    await _repo.saveConsent(_consent!);
    await _repo.savePreferences(_prefs);
  }

  Future<void> setLocationConsent(bool allowed) async {
    final c = _consent;
    if (c == null) return;
    _consent = ConsentRecord(
      version: c.version,
      acceptedAt: DateTime.now(),
      dataProcessing: c.dataProcessing,
      approximateLocation: allowed,
    );
    notifyListeners();
    await _repo.saveConsent(_consent!);
  }

  Future<void> revokeConsent() async {
    _consent = null;
    notifyListeners();
    await _repo.revokeConsent();
  }

  Future<void> saveThreshold(AlertThreshold t) async {
    _thresholds = {..._thresholds, t.indicatorId: t};
    notifyListeners();
    await _repo.saveThresholds(_thresholds);
  }

  Future<void> resetThresholds() async {
    _thresholds = {
      for (final d in IndicatorCatalog.all) d.id: AlertThreshold.defaultFor(d),
    };
    notifyListeners();
    await _repo.saveThresholds(_thresholds);
  }

  /// Apaga TODOS os dados locais e volta ao estado de primeira execução.
  Future<void> eraseAllData() async {
    await _repo.clearAll();
    _prefs = const AppPreferences();
    _consent = null;
    _salt = '';
    _thresholds = _repo.readThresholds();
    notifyListeners();
  }
}
