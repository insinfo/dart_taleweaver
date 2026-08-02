library;

import 'doc.dart';
import 'structs.dart';

class _StoreSnapshot {
  final List<YStruct> structs;
  _StoreSnapshot(YStructStore store)
      : structs = [
          for (final values in store.clients.values)
            ...values.map(
                (value) => value.copyWith(id: value.id, length: value.length))
        ];
}

class YUndoManager {
  final YDoc doc;
  final int maxStackDepth;
  final Set<Object> trackedOrigins;
  final List<({_StoreSnapshot before, _StoreSnapshot after})> _undo = [];
  final List<({_StoreSnapshot before, _StoreSnapshot after})> _redo = [];
  _StoreSnapshot? _capture;

  YUndoManager(this.doc,
      {this.maxStackDepth = 100, Set<Object>? trackedOrigins})
      : trackedOrigins = trackedOrigins ?? {};

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void beginCapture() => _capture = _StoreSnapshot(doc.store);

  void endCapture({Object? origin}) {
    final before = _capture;
    _capture = null;
    if (before == null ||
        (trackedOrigins.isNotEmpty && !trackedOrigins.contains(origin))) return;
    final entry = (before: before, after: _StoreSnapshot(doc.store));
    if (entry.before.structs.length == entry.after.structs.length &&
        _same(entry.before, entry.after)) return;
    _undo.add(entry);
    _redo.clear();
    while (maxStackDepth > 0 && _undo.length > maxStackDepth) _undo.removeAt(0);
  }

  void undo() {
    if (_undo.isEmpty) return;
    final entry = _undo.removeLast();
    _restore(entry.before);
    _redo.add(entry);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final entry = _redo.removeLast();
    _restore(entry.after);
    _undo.add(entry);
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }

  void _restore(_StoreSnapshot snapshot) {
    doc.store.clients.clear();
    doc.store.skips.clients.clear();
    for (final struct in snapshot.structs)
      doc.store.add(struct.copyWith(id: struct.id, length: struct.length));
  }

  bool _same(_StoreSnapshot a, _StoreSnapshot b) {
    if (a.structs.length != b.structs.length) return false;
    for (var i = 0; i < a.structs.length; i++) {
      final left = a.structs[i];
      final right = b.structs[i];
      if (left.id != right.id ||
          left.length != right.length ||
          left.runtimeType != right.runtimeType ||
          left.deleted != right.deleted) return false;
    }
    return true;
  }
}
