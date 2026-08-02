/// TwUndoManager — snapshot-based undo/redo replacing Yjs Y.UndoManager.
///
/// Each undo/redo StackItem stores complete snapshots of the data maps
/// before and after the transaction, enabling full state reversal.
library;

import 'block_id.dart';
import 'block_position.dart';
import 'tw_doc.dart';

// ---------------------------------------------------------------------------
// SelectionEntry
// ---------------------------------------------------------------------------

/// One entry on the undo / redo stacks: the pre-action and post-action
/// selections captured at commit time.
class SelectionEntry {
  final Selection? before;
  final Selection? after;

  const SelectionEntry({this.before, this.after});
}

// ---------------------------------------------------------------------------
// StackItem
// ---------------------------------------------------------------------------

/// A single undo/redo stack entry.
///
/// Stores complete snapshots of the document state (blocks, embedContents,
/// templateContents, listDefs, comments, suggestions) before and after the
/// mutation, plus a [SelectionEntry] and the transaction origin.
class StackItem {
  /// Snapshot of blocks BEFORE the mutation.
  final Map<String, Map<String, dynamic>> blocksBefore;

  /// Snapshot of blocks AFTER the mutation.
  final Map<String, Map<String, dynamic>> blocksAfter;

  /// Snapshot of embed contents BEFORE the mutation.
  final Map<String, Map<String, dynamic>> embedContentsBefore;

  /// Snapshot of embed contents AFTER the mutation.
  final Map<String, Map<String, dynamic>> embedContentsAfter;

  /// Snapshot of template contents BEFORE the mutation.
  final Map<String, Map<String, dynamic>> templateContentsBefore;

  /// Snapshot of template contents AFTER the mutation.
  final Map<String, Map<String, dynamic>> templateContentsAfter;

  /// Snapshot of list defs BEFORE the mutation.
  final Map<String, Map<String, dynamic>> listDefsBefore;

  /// Snapshot of list defs AFTER the mutation.
  final Map<String, Map<String, dynamic>> listDefsAfter;

  /// Snapshot of comments BEFORE the mutation.
  final Map<String, Map<String, dynamic>> commentsBefore;

  /// Snapshot of comments AFTER the mutation.
  final Map<String, Map<String, dynamic>> commentsAfter;

  /// Snapshot of suggestions BEFORE the mutation.
  final Map<String, Map<String, dynamic>> suggestionsBefore;

  /// Snapshot of suggestions AFTER the mutation.
  final Map<String, Map<String, dynamic>> suggestionsAfter;

  /// Metadata map (analogous to Yjs StackItem.meta).
  final Map<Symbol, dynamic> meta = {};

  /// The transaction origin string, if any.
  final String? origin;

  StackItem({
    required this.blocksBefore,
    required this.blocksAfter,
    required this.embedContentsBefore,
    required this.embedContentsAfter,
    required this.templateContentsBefore,
    required this.templateContentsAfter,
    required this.listDefsBefore,
    required this.listDefsAfter,
    required this.commentsBefore,
    required this.commentsAfter,
    required this.suggestionsBefore,
    required this.suggestionsAfter,
    this.origin,
  });
}

// ---------------------------------------------------------------------------
// TwUndoManager
// ---------------------------------------------------------------------------

/// Module-private key for SelectionEntry on StackItem.meta.
const _selKey = Symbol('taleweaver.history.selectionEntry');

/// Undo/Redo manager backed by full-state snapshots.
///
/// Replaces Yjs Y.UndoManager. Each tracked operation captures the full
/// state of all data maps before and after, enabling complete reversal.
class TwUndoManager {
  final TwDoc _doc;

  /// The undo stack.
  final List<StackItem> _undoStack = [];

  /// The redo stack.
  final List<StackItem> _redoStack = [];

  /// Maximum depth for each stack (0 = unlimited).
  final int maxStackDepth;

  /// Snapshot taken at beginCapture (before the mutation).
  Map<String, Map<String, dynamic>>? _capturedBlocks;
  Map<String, Map<String, dynamic>>? _capturedEmbedContents;
  Map<String, Map<String, dynamic>>? _capturedTemplateContents;
  Map<String, Map<String, dynamic>>? _capturedListDefs;
  Map<String, Map<String, dynamic>>? _capturedComments;
  Map<String, Map<String, dynamic>>? _capturedSuggestions;

  /// Transaction origins to exclude from undo tracking.
  final Set<String> _excludedOrigins;

  /// Whether we're currently capturing.
  bool _capturing = false;

  TwUndoManager(
    this._doc, {
    this.maxStackDepth = 500,
    Set<String>? excludedOrigins,
  }) : _excludedOrigins = excludedOrigins ?? {};

  /// Whether there are undoable items.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are redoable items.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Begin capturing a mutation. Call before the doc transaction.
  void beginCapture() {
    _capturing = true;
    _capturedBlocks = _doc.snapshotBlocks();
    _capturedEmbedContents = _doc.snapshotEmbedContents();
    _capturedTemplateContents = _doc.snapshotTemplateContents();
    _capturedListDefs = _doc.snapshotListDefs();
    _capturedComments = _doc.snapshotComments();
    _capturedSuggestions = _doc.snapshotSuggestions();
  }

  /// End capturing and push the undo item.
  ///
  /// Call after the doc transaction completes. [selectionBefore] and
  /// [selectionAfter] are welded onto the StackItem for undo/redo selection
  /// restoration. [origin] is the transaction origin.
  void endCapture({
    Selection? selectionBefore,
    Selection? selectionAfter,
    String? origin,
  }) {
    if (!_capturing) return;
    _capturing = false;

    // Check if origin is excluded.
    if (origin != null && _excludedOrigins.contains(origin)) {
      _clearCapture();
      return;
    }

    final item = StackItem(
      blocksBefore: _capturedBlocks!,
      blocksAfter: _doc.snapshotBlocks(),
      embedContentsBefore: _capturedEmbedContents!,
      embedContentsAfter: _doc.snapshotEmbedContents(),
      templateContentsBefore: _capturedTemplateContents!,
      templateContentsAfter: _doc.snapshotTemplateContents(),
      listDefsBefore: _capturedListDefs!,
      listDefsAfter: _doc.snapshotListDefs(),
      commentsBefore: _capturedComments!,
      commentsAfter: _doc.snapshotComments(),
      suggestionsBefore: _capturedSuggestions!,
      suggestionsAfter: _doc.snapshotSuggestions(),
      origin: origin,
    );

    // Weld selection entry.
    item.meta[_selKey] = SelectionEntry(
      before: selectionBefore,
      after: selectionAfter,
    );

    _undoStack.add(item);
    _redoStack.clear(); // New edit clears redo.

    // Trim if over limit.
    if (maxStackDepth > 0 && _undoStack.length > maxStackDepth) {
      _undoStack.removeAt(0);
    }

    _clearCapture();
  }

  /// Undo the last operation. Returns null if nothing to undo.
  UndoRedoResult? undo() {
    if (_undoStack.isEmpty) return null;
    final item = _undoStack.removeLast();

    // Restore before-state.
    _doc.transact(() {
      _doc.restoreBlocks(item.blocksBefore);
      _doc.restoreEmbedContents(item.embedContentsBefore);
      _doc.restoreTemplateContents(item.templateContentsBefore);
      _doc.restoreListDefs(item.listDefsBefore);
      _doc.restoreComments(item.commentsBefore);
      _doc.restoreSuggestions(item.suggestionsBefore);
    });

    // Push to redo stack.
    _redoStack.add(item);

    // Compute dirty IDs (union of all changed block keys).
    final dirtyIds = <BlockId>{};
    for (final k in {...item.blocksBefore.keys, ...item.blocksAfter.keys}) {
      dirtyIds.add(BlockId(k));
    }

    final selEntry = item.meta[_selKey] as SelectionEntry?;

    return UndoRedoResult(
      selection: selEntry?.before,
      dirtyIds: dirtyIds,
    );
  }

  /// Redo the last undone operation. Returns null if nothing to redo.
  UndoRedoResult? redo() {
    if (_redoStack.isEmpty) return null;
    final item = _redoStack.removeLast();

    // Restore after-state.
    _doc.transact(() {
      _doc.restoreBlocks(item.blocksAfter);
      _doc.restoreEmbedContents(item.embedContentsAfter);
      _doc.restoreTemplateContents(item.templateContentsAfter);
      _doc.restoreListDefs(item.listDefsAfter);
      _doc.restoreComments(item.commentsAfter);
      _doc.restoreSuggestions(item.suggestionsAfter);
    });

    // Push back to undo stack.
    _undoStack.add(item);

    // Compute dirty IDs.
    final dirtyIds = <BlockId>{};
    for (final k in {...item.blocksBefore.keys, ...item.blocksAfter.keys}) {
      dirtyIds.add(BlockId(k));
    }

    final selEntry = item.meta[_selKey] as SelectionEntry?;

    return UndoRedoResult(
      selection: selEntry?.after,
      dirtyIds: dirtyIds,
    );
  }

  /// Clear all undo/redo stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void _clearCapture() {
    _capturedBlocks = null;
    _capturedEmbedContents = null;
    _capturedTemplateContents = null;
    _capturedListDefs = null;
    _capturedComments = null;
    _capturedSuggestions = null;
  }
}

// ---------------------------------------------------------------------------
// UndoRedoResult
// ---------------------------------------------------------------------------

/// Result of an undo or redo operation.
class UndoRedoResult {
  /// The selection to restore after undo/redo.
  final Selection? selection;

  /// BlockIds whose subtrees were mutated by the reversal.
  final Set<BlockId> dirtyIds;

  const UndoRedoResult({this.selection, required this.dirtyIds});
}
