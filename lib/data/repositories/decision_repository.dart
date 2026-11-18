import '../models/alert.dart';
import '../services/local_storage_service.dart';

/// Histórico de decisões humanas sobre alertas (trilha de auditoria local).
class DecisionRepository {
  DecisionRepository(this._storage);

  final LocalStorageService _storage;

  Map<String, AlertDecision> readAll() {
    final map = <String, AlertDecision>{};
    for (final json in _storage.readList(LocalStorageService.keyDecisions)) {
      try {
        final d = AlertDecision.fromJson(json);
        map[d.alertId] = d;
      } catch (_) {
        /* ignora registro corrompido */
      }
    }
    return map;
  }

  Future<void> saveAll(Map<String, AlertDecision> decisions) =>
      _storage.writeJson(
        LocalStorageService.keyDecisions,
        decisions.values.map((d) => d.toJson()).toList(),
      );
}
