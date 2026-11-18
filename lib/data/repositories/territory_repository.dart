import '../../core/constants/territory.dart';
import '../models/indicator.dart';
import '../models/territory_snapshot.dart';
import '../services/api_exception.dart';
import '../services/ibge_api_service.dart';
import '../services/inmet_scraper_service.dart';
import '../services/local_storage_service.dart';
import '../services/simulated_territory_api.dart';

/// Orquestra as fontes de dados do território e o cache offline.
///
/// Estratégia *network-first com fallback para cache*:
/// 1. tenta buscar dados novos (API simulada + página do INMET + IBGE);
/// 2. se der certo, salva o snapshot localmente;
/// 3. se a rede falhar, devolve o último snapshot salvo, marcado como cache;
/// 4. sem cache disponível, propaga o erro para a UI exibir o estado de erro.
class TerritoryRepository {
  TerritoryRepository({
    required this._territoryApi,
    required this._inmet,
    required this._ibge,
    required this._storage,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SimulatedTerritoryApi _territoryApi;
  final InmetScraperService _inmet;
  final IbgeApiService _ibge;
  final LocalStorageService _storage;
  final DateTime Function() _clock;

  Future<TerritorySnapshot> load({bool offline = false}) async {
    try {
      final snapshot = await _fetchRemote(offline: offline);
      await _storage.writeJson(
        LocalStorageService.keySnapshotCache,
        snapshot.toJson(),
      );
      return snapshot;
    } on ApiException {
      final cached = readCache();
      if (cached != null) return cached.asCached();
      rethrow;
    }
  }

  TerritorySnapshot? readCache() {
    final json = _storage.readMap(LocalStorageService.keySnapshotCache);
    if (json == null) return null;
    try {
      return TerritorySnapshot.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<TerritorySnapshot> _fetchRemote({required bool offline}) async {
    if (offline) {
      // Mantém o comportamento coerente: sem rede, nenhuma fonte responde.
      await _territoryApi.fetchIndicators(offline: true);
    }

    final warnings = <String>[];
    final notes = <String>[];
    // O erro é capturado na hora. Sem isso, uma fonte que falha enquanto a
    // outra ainda responde vaza como exceção não tratada.
    final indicatorsFuture = _capture(_territoryApi.fetchIndicators());
    final climateFuture = _capture(_inmet.fetchClimate());
    final censusFuture = _capture(_ibge.fetchDistrict());

    final indicatorsValue = await indicatorsFuture;
    if (indicatorsValue is ApiException) throw indicatorsValue;
    if (indicatorsValue is! List<IndicatorSeries>) throw indicatorsValue;

    List<IndicatorSeries> climate;
    final climateValue = await climateFuture;
    if (climateValue is InmetClimate) {
      climate = climateValue.series;
      notes.add(climateValue.note);
    } else if (climateValue is ApiException) {
      climate = _territoryApi.syntheticClimate();
      warnings.add('${climateValue.message} Clima exibido com dados sintéticos.');
    } else {
      throw climateValue;
    }

    var population = Territory.population;
    final censusValue = await censusFuture;
    if (censusValue is DistrictCensus) {
      population = censusValue.population;
      notes.add(censusValue.note);
    } else if (censusValue is ApiException) {
      warnings.add(
        '${censusValue.message} População do distrito mantida no valor de referência.',
      );
    } else {
      throw censusValue;
    }

    return TerritorySnapshot(
      series: [...indicatorsValue, ...climate],
      fetchedAt: _clock(),
      warnings: warnings,
      notes: notes,
      population: population,
    );
  }
}

Future<Object> _capture(Future<Object> future) => future.onError<Object>(
  (error, _) => error,
);
