import 'package:material_ui/material_ui.dart';

import '../data/models/alert.dart';
import '../data/models/threshold.dart';
import '../data/repositories/decision_repository.dart';
import '../domain/analytics/alert_engine.dart';
import '../domain/analytics/social_impact.dart';
import 'occurrences_provider.dart';
import 'settings_provider.dart';
import 'territory_provider.dart';
import 'view_status.dart';

/// Estado global derivado: alertas, decisões humanas e impacto social.
///
/// Recalculado sempre que os dados do território, os limiares ou as
/// ocorrências mudam (via `ChangeNotifierProxyProvider3`).
class AlertsProvider extends ChangeNotifier {
  AlertsProvider(this._decisionRepo, {AlertEngine? engine})
    : _engine = engine ?? const AlertEngine() {
    _decisions = _decisionRepo.readAll();
  }

  final DecisionRepository _decisionRepo;
  final AlertEngine _engine;
  final _impactCalculator = const SocialImpactCalculator();

  late Map<String, AlertDecision> _decisions;
  List<TerritoryAlert> _alerts = const [];
  ViewStatus _status = ViewStatus.initial;
  String? _error;
  SocialImpactReport? _impact;

  TerritoryProvider? _territory;
  OccurrencesProvider? _occurrences;

  List<TerritoryAlert> get alerts => _alerts;
  ViewStatus get status => _status;
  String? get errorMessage => _error;
  SocialImpactReport? get impact => _impact;

  int get pendingCount =>
      _alerts.where((a) => decisionFor(a.id) == null).length;

  AlertDecision? decisionFor(String alertId) => _decisions[alertId];

  DecisionStatus statusFor(String alertId) =>
      _decisions[alertId]?.status ?? DecisionStatus.pending;

  TerritoryAlert? byId(String id) {
    for (final a in _alerts) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<TerritoryAlert> forIndicator(String indicatorId) =>
      _alerts.where((a) => a.indicatorId == indicatorId).toList();

  /// Chamado pelo ProxyProvider quando qualquer dependência notifica.
  /// O recálculo é barato (13 indicadores), então é feito sempre.
  void updateDependencies(
    TerritoryProvider territory,
    SettingsProvider settings,
    OccurrencesProvider occurrences,
  ) {
    _territory = territory;
    _occurrences = occurrences;
    _recompute(settings.thresholds);
  }

  void _recompute(Map<String, AlertThreshold> thresholds) {
    final territory = _territory;
    if (territory == null) return;
    _error = territory.errorMessage;
    if (territory.status != ViewStatus.success) {
      _status = territory.status;
      _alerts = const [];
      _impact = null;
      // Notifica após o frame atual: estamos dentro de um update de provider.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    try {
      _alerts = _engine.generate(
        series: territory.series,
        analyses: territory.analyses,
        thresholds: thresholds,
        occurrences: _occurrences?.items ?? const [],
        now: territory.snapshot!.fetchedAt,
      );
      _status = _alerts.isEmpty ? ViewStatus.empty : ViewStatus.success;
      _computeImpact();
    } catch (e) {
      _status = ViewStatus.error;
      _error = 'Falha ao gerar alertas: $e';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void _computeImpact() {
    final territory = _territory;
    if (territory == null) return;
    _impact = _impactCalculator.compute(
      alerts: _alerts,
      decisions: _decisions,
      analyses: territory.analyses,
      occurrences: _occurrences?.items ?? const [],
    );
  }

  /// Registra a decisão HUMANA sobre um alerta.
  Future<void> decide(
    TerritoryAlert alert,
    DecisionStatus status,
    String note,
  ) async {
    _decisions = {
      ..._decisions,
      alert.id: AlertDecision(
        alertId: alert.id,
        status: status,
        note: note.trim(),
        decidedAt: DateTime.now(),
        alertGeneratedAt: alert.generatedAt,
      ),
    };
    _computeImpact();
    notifyListeners();
    await _decisionRepo.saveAll(_decisions);
  }

  Future<void> reopen(String alertId) async {
    _decisions = Map.of(_decisions)..remove(alertId);
    _computeImpact();
    notifyListeners();
    await _decisionRepo.saveAll(_decisions);
  }

  void clearInMemory() {
    _decisions = {};
    _computeImpact();
    notifyListeners();
  }
}
