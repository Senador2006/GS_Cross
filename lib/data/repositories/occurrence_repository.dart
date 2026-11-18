import '../models/occurrence.dart';
import '../services/api_exception.dart';
import '../services/local_storage_service.dart';
import '../services/simulated_territory_api.dart';

/// Ocorrências cidadãs: salvas localmente primeiro (offline-first) e
/// enviadas ao servidor quando houver conexão.
class OccurrenceRepository {
  OccurrenceRepository({required this._storage, required this._api});

  final LocalStorageService _storage;
  final SimulatedTerritoryApi _api;

  List<Occurrence> readAll() {
    final list = <Occurrence>[];
    for (final json in _storage.readList(LocalStorageService.keyOccurrences)) {
      try {
        list.add(Occurrence.fromJson(json));
      } catch (_) {
        /* ignora registro corrompido */
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveAll(List<Occurrence> items) => _storage.writeJson(
    LocalStorageService.keyOccurrences,
    items.map((o) => o.toJson()).toList(),
  );

  /// Tenta enviar; devolve a ocorrência com o status de sincronização final.
  Future<Occurrence> trySync(Occurrence o, {required bool offline}) async {
    try {
      await _api.submitOccurrence(o, offline: offline);
      return o.copyWith(syncStatus: SyncStatus.synced);
    } on ApiException {
      return o.copyWith(syncStatus: SyncStatus.pending);
    }
  }
}
