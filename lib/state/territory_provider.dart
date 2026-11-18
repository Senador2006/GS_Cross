import 'package:material_ui/material_ui.dart';

import '../data/models/analysis.dart';
import '../data/models/indicator.dart';
import '../data/models/territory_snapshot.dart';
import '../data/repositories/territory_repository.dart';
import '../data/services/api_exception.dart';
import '../domain/analytics/prediction_engine.dart';
import 'view_status.dart';

/// Estado global dos dados do território e das análises preditivas.
/// Compartilhado por Visão geral, Dashboards, Detalhe do indicador e Alertas.
class TerritoryProvider extends ChangeNotifier {
  TerritoryProvider(this._repo, {PredictionEngine? engine})
    : _engine = engine ?? const PredictionEngine();

  final TerritoryRepository _repo;
  final PredictionEngine _engine;

  ViewStatus _status = ViewStatus.initial;
  TerritorySnapshot? _snapshot;
  Map<String, IndicatorAnalysis> _analyses = {};
  String? _error;
  bool _refreshing = false;

  ViewStatus get status => _status;
  TerritorySnapshot? get snapshot => _snapshot;
  Map<String, IndicatorAnalysis> get analyses => _analyses;
  String? get errorMessage => _error;
  bool get isOffline => _snapshot?.fromCache ?? false;

  /// `true` durante um "puxar para atualizar" com dados já na tela.
  bool get isRefreshing => _refreshing;

  List<IndicatorSeries> get series => _snapshot?.series ?? const [];

  IndicatorSeries? seriesById(String id) => _snapshot?.byId(id);
  IndicatorAnalysis? analysisById(String id) => _analyses[id];

  List<IndicatorSeries> seriesFor(TerritoryDomain domain) =>
      series.where((s) => s.definition.domain == domain).toList();

  Future<void> load({bool offline = false}) async {
    final hasData = _snapshot != null && !_snapshot!.isEmpty;
    if (hasData) {
      _refreshing = true;
    } else {
      _status = ViewStatus.loading;
    }
    _error = null;
    notifyListeners();

    try {
      final snap = await _repo.load(offline: offline);
      _snapshot = snap;
      _analyses = {for (final s in snap.series) s.id: _engine.analyze(s)};
      _status = snap.isEmpty ? ViewStatus.empty : ViewStatus.success;
    } on ApiException catch (e) {
      _error = e.isConnectivity
          ? '${e.message}\nNenhum dado salvo neste dispositivo ainda. '
                'Conecte-se à internet e tente novamente.'
          : e.message;
      if (!hasData) _status = ViewStatus.error;
    } catch (e) {
      _error = 'Erro inesperado ao processar os dados: $e';
      if (!hasData) _status = ViewStatus.error;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void clearInMemory() {
    _snapshot = null;
    _analyses = {};
    _status = ViewStatus.initial;
    notifyListeners();
  }
}
