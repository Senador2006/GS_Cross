import '../models/indicator.dart';
import '../models/territory_snapshot.dart';
import '../services/api_exception.dart';
import '../services/climate_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/simulated_territory_api.dart';

/// Orquestra as fontes de dados do território e o cache offline.
///
/// Estratégia *network-first com fallback para cache*:
/// 1. tenta buscar dados novos (API simulada + Open-Meteo);
/// 2. se der certo, salva o snapshot localmente;
/// 3. se a rede falhar, devolve o último snapshot salvo, marcado como cache;
/// 4. sem cache disponível, propaga o erro para a UI exibir o estado de erro.
class TerritoryRepository {
  TerritoryRepository({
    required this._territoryApi,
    required this._climateApi,
    required this._storage,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SimulatedTerritoryApi _territoryApi;
  final ClimateApiService _climateApi;
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
    final warnings = <String>[];
    final indicatorsFuture = _territoryApi.fetchIndicators(offline: offline);

    List<IndicatorSeries> climate;
    if (offline) {
      // Mantém o comportamento coerente: sem rede, nenhuma fonte responde.
      await indicatorsFuture; // lança ApiException
      climate = const [];
    } else {
      try {
        climate = await _climateApi.fetchClimate();
      } on ApiException catch (e) {
        climate = _territoryApi.syntheticClimate();
        warnings.add('${e.message} Clima exibido com dados sintéticos.');
      }
    }

    final indicators = await indicatorsFuture;
    return TerritorySnapshot(
      series: [...indicators, ...climate],
      fetchedAt: _clock(),
      warnings: warnings,
    );
  }
}
