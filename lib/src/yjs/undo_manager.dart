library;

import 'doc.dart';
import 'ids.dart';
import 'structs.dart';

class _StoreSnapshot {
  final List<YStruct> structs;
  final YIdSet pendingDeletes;
  final YIdSet skips;
  final Map<String, dynamic> shared;
  _StoreSnapshot(YStructStore store)
      : structs = [
          for (final values in store.clients.values)
            ...values.map(
                (value) => value.copyWith(id: value.id, length: value.length))
        ],
        pendingDeletes = store.pendingDeletes.copy(),
        skips = store.skips.copy(),
        shared = {};

  _StoreSnapshot.capture(YDoc doc)
      : structs = [
          for (final values in doc.store.clients.values)
            ...values.map(
                (value) => value.copyWith(id: value.id, length: value.length))
        ],
        pendingDeletes = doc.store.pendingDeletes.copy(),
        skips = doc.store.skips.copy(),
        shared = _cloneJson(doc.snapshotShared());
}

class YUndoManager {
  final YDoc doc;
  final int maxStackDepth;
  final int captureTimeout;
  final Set<Object?> trackedOrigins;
  final List<({_StoreSnapshot before, _StoreSnapshot after})> _undo = [];
  final List<({_StoreSnapshot before, _StoreSnapshot after})> _redo = [];
  _StoreSnapshot? _capture;
  int _captureDepth = 0;
  int? _captureStartedAt;
  int? _lastCaptureAt;

  YUndoManager(this.doc,
      {this.maxStackDepth = 100,
      this.captureTimeout = 500,
      Set<Object?>? trackedOrigins})
      : trackedOrigins = trackedOrigins ?? {null} {
    doc.onBeforeTransaction(_onBeforeTransaction);
    doc.onAfterTransaction(_onAfterTransaction);
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Detaches transaction observers and releases captured history.
  /// Subsequent document mutations are intentionally not tracked by this
  /// manager, matching Yjs' destroy lifecycle.
  void dispose() {
    doc.offBeforeTransaction(_onBeforeTransaction);
    doc.offAfterTransaction(_onAfterTransaction);
    clear();
  }

  List<({_StoreSnapshot before, _StoreSnapshot after})> get undoStack =>
      List.unmodifiable(_undo);
  List<({_StoreSnapshot before, _StoreSnapshot after})> get redoStack =>
      List.unmodifiable(_redo);

  /// Starts a capture. Consecutive captures can be merged by passing timestamps
  /// within [captureTimeout], matching Yjs' temporal capture window.
  void beginCapture({int? timestampMs}) {
    if (_capture != null) {
      _captureDepth++;
      return;
    }
    _capture = _StoreSnapshot.capture(doc);
    _captureDepth = 1;
    _captureStartedAt = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  }

  void endCapture({Object? origin, int? timestampMs}) {
    if (_captureDepth > 1) {
      _captureDepth--;
      return;
    }
    final before = _capture;
    final startedAt = _captureStartedAt;
    _capture = null;
    _captureDepth = 0;
    _captureStartedAt = null;
    if (before == null || !trackedOrigins.contains(origin)) return;
    final entry = (before: before, after: _StoreSnapshot.capture(doc));
    if (entry.before.structs.length == entry.after.structs.length &&
        _same(entry.before, entry.after)) return;
    final endedAt = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final canMerge = _undo.isNotEmpty &&
        _lastCaptureAt != null &&
        startedAt != null &&
        (startedAt - _lastCaptureAt!).abs() <= captureTimeout;
    if (canMerge) {
      final previous = _undo.removeLast();
      _undo.add((before: previous.before, after: entry.after));
    } else {
      _undo.add(entry);
    }
    _lastCaptureAt = endedAt;
    _redo.clear();
    while (maxStackDepth > 0 && _undo.length > maxStackDepth) _undo.removeAt(0);
  }

  /// Executes [operation] inside one undo capture, including nested calls.
  /// The capture is closed even when the operation throws.
  void transact(void Function() operation, {Object? origin, int? timestampMs}) {
    beginCapture(timestampMs: timestampMs);
    try {
      operation();
    } finally {
      endCapture(origin: origin, timestampMs: timestampMs);
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    final entry = _undo.removeLast();
    _restore(entry.before);
    _redo.add(entry);
    _lastCaptureAt = null;
  }

  void redo() {
    if (_redo.isEmpty) return;
    final entry = _redo.removeLast();
    _restore(entry.after);
    _undo.add(entry);
    _lastCaptureAt = null;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _capture = null;
    _captureDepth = 0;
    _captureStartedAt = null;
    _lastCaptureAt = null;
  }

  /// Breaks the temporal capture chain without changing document state.
  void stopCapturing() => _lastCaptureAt = null;

  void _onBeforeTransaction(Object? origin) {
    beginCapture();
  }

  void _onAfterTransaction(YTransaction transaction) {
    endCapture(origin: transaction.origin);
  }

  void _restore(_StoreSnapshot snapshot) {
    doc.store.clients.clear();
    doc.store.skips.clients.clear();
    doc.store.pendingDeletes.clients.clear();
    for (final struct in snapshot.structs)
      doc.store.add(struct.copyWith(id: struct.id, length: struct.length));
    for (final entry in snapshot.pendingDeletes.clients.entries) {
      for (final range in entry.value) {
        doc.store.pendingDeletes.add(entry.key, range.clock, range.length);
      }
    }
    for (final entry in snapshot.skips.clients.entries) {
      for (final range in entry.value) {
        doc.store.skips.add(entry.key, range.clock, range.length);
      }
    }
    doc.restoreSharedSnapshot(snapshot.shared);
  }

  bool _same(_StoreSnapshot a, _StoreSnapshot b) {
    if (a.pendingDeletes != b.pendingDeletes || a.skips != b.skips) {
      return false;
    }
    if (a.structs.length != b.structs.length) return false;
    for (var i = 0; i < a.structs.length; i++) {
      final left = a.structs[i];
      final right = b.structs[i];
      if (left.id != right.id ||
          left.length != right.length ||
          left.runtimeType != right.runtimeType ||
          left.deleted != right.deleted) return false;
    }
    return _jsonEqual(a.shared, b.shared);
  }
}

dynamic _cloneJson(dynamic value) {
  if (value is Map) {
    return {
      for (final entry in value.entries) '${entry.key}': _cloneJson(entry.value)
    };
  }
  if (value is List) return value.map(_cloneJson).toList(growable: false);
  return value;
}

bool _jsonEqual(dynamic left, dynamic right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    return left.entries.every((entry) =>
        right.containsKey(entry.key) &&
        _jsonEqual(entry.value, right[entry.key]));
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(left.length, (i) => _jsonEqual(left[i], right[i]))
            .every((value) => value);
  }
  return left == right;
}
