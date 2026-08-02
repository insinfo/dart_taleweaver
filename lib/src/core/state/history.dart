/// History — undo/redo facade for the editor.
///
/// Port of `history.ts`.
library;

import 'block_position.dart';
import 'state.dart';
import 'tw_undo_manager.dart';

// Re-export the types consumers need.
export 'tw_undo_manager.dart' show SelectionEntry, UndoRedoResult;

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

/// Undo/Redo history for the editor.
///
/// Wraps [TwUndoManager] with editor-friendly semantics: `beginCapture` →
/// mutation → `commit` → produces an undo-item with selection metadata.
class History {
  final TwUndoManager _manager;
  Selection? _selectionBefore;
  String? _pendingOrigin;

  History._(this._manager);

  /// Whether there are undoable items.
  bool get canUndo => _manager.canUndo;

  /// Whether there are redoable items.
  bool get canRedo => _manager.canRedo;

  /// Begin capturing a mutation. Call before the doc transaction.
  ///
  /// [selectionBefore] is the selection state prior to the edit.
  /// [origin] is the optional transaction origin for filtering.
  void beginCapture({Selection? selectionBefore, String? origin}) {
    _selectionBefore = selectionBefore;
    _pendingOrigin = origin;
    _manager.beginCapture();
  }

  /// Commit the captured mutation. Call after the doc transaction.
  ///
  /// [selectionAfter] is the selection state after the edit.
  void commit({Selection? selectionAfter}) {
    _manager.endCapture(
      selectionBefore: _selectionBefore,
      selectionAfter: selectionAfter,
      origin: _pendingOrigin,
    );
    _selectionBefore = null;
    _pendingOrigin = null;
  }

  /// Undo the last operation.
  ///
  /// Returns the [UndoRedoResult] with the selection to restore and
  /// the set of dirty block IDs, or null if nothing to undo.
  UndoRedoResult? undo() => _manager.undo();

  /// Redo the last undone operation.
  UndoRedoResult? redo() => _manager.redo();

  /// Clear all undo/redo stacks.
  void clear() => _manager.clear();
}

/// Create a [History] for the given [state].
///
/// [excludedOrigins] are transaction origins that should not be tracked
/// (e.g., 'suggestion-resolve' for non-undoable suggestion accept/reject).
History createHistory(
  State state, {
  Set<String>? excludedOrigins,
}) {
  final manager = TwUndoManager(
    state.doc,
    excludedOrigins: excludedOrigins,
  );
  return History._(manager);
}
