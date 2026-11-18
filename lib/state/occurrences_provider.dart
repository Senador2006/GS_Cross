import 'package:material_ui/material_ui.dart';

import '../data/models/occurrence.dart';
import '../data/repositories/occurrence_repository.dart';
import 'view_status.dart';

/// Estado global das ocorrências registradas por cidadãos.
class OccurrencesProvider extends ChangeNotifier {
  OccurrencesProvider(this._repo) {
    _items = _repo.readAll();
  }

  final OccurrenceRepository _repo;
  late List<Occurrence> _items;
  bool _syncing = false;

  List<Occurrence> get items => List.unmodifiable(_items);
  bool get isSyncing => _syncing;
  int get pendingCount =>
      _items.where((o) => o.syncStatus == SyncStatus.pending).length;

  ViewStatus get status =>
      _items.isEmpty ? ViewStatus.empty : ViewStatus.success;

  Occurrence? byId(String id) {
    for (final o in _items) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Salva localmente primeiro e tenta enviar. Devolve `true` se enviou.
  Future<bool> submit(Occurrence occurrence, {required bool offline}) async {
    _items = [occurrence, ..._items];
    notifyListeners();
    await _repo.saveAll(_items);

    final synced = await _repo.trySync(occurrence, offline: offline);
    _replace(synced);
    await _repo.saveAll(_items);
    return synced.syncStatus == SyncStatus.synced;
  }

  /// Reenvia as ocorrências da fila. Devolve quantas foram enviadas.
  Future<int> syncPending({required bool offline}) async {
    if (_syncing) return 0;
    _syncing = true;
    notifyListeners();
    var sent = 0;
    try {
      for (final o
          in _items.where((o) => o.syncStatus == SyncStatus.pending).toList()) {
        final result = await _repo.trySync(o, offline: offline);
        if (result.syncStatus == SyncStatus.synced) sent++;
        _replace(result);
      }
      await _repo.saveAll(_items);
    } finally {
      _syncing = false;
      notifyListeners();
    }
    return sent;
  }

  Future<void> delete(String id) async {
    _items = _items.where((o) => o.id != id).toList();
    notifyListeners();
    await _repo.saveAll(_items);
  }

  void clearInMemory() {
    _items = [];
    notifyListeners();
  }

  void _replace(Occurrence o) {
    _items = [for (final i in _items) i.id == o.id ? o : i];
    notifyListeners();
  }
}
