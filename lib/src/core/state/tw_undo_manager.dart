/// TwUndoManager — snapshot-based undo/redo replacing Yjs Y.UndoManager.
///
/// Each undo/redo StackItem stores complete snapshots of the data maps
/// before and after the transaction, enabling full state reversal.
library;

import 'dart:convert';

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
/// templateContents, listDefs, comments, suggestions and document metadata)
/// before and after the mutation, plus a [SelectionEntry] and the transaction
/// origin.
class StackItem {
  /// Snapshot of blocks BEFORE the mutation.
  final Map<String, Map<String, dynamic>> blocksBefore;

  /// Snapshot of blocks AFTER the mutation.
  Map<String, Map<String, dynamic>> blocksAfter;

  /// Snapshot of embed contents BEFORE the mutation.
  final Map<String, Map<String, dynamic>> embedContentsBefore;

  /// Snapshot of embed contents AFTER the mutation.
  Map<String, Map<String, dynamic>> embedContentsAfter;

  /// Snapshot of template contents BEFORE the mutation.
  final Map<String, Map<String, dynamic>> templateContentsBefore;

  /// Snapshot of template contents AFTER the mutation.
  Map<String, Map<String, dynamic>> templateContentsAfter;

  /// Snapshot of list defs BEFORE the mutation.
  final Map<String, Map<String, dynamic>> listDefsBefore;

  /// Snapshot of list defs AFTER the mutation.
  Map<String, Map<String, dynamic>> listDefsAfter;

  /// Snapshot of comments BEFORE the mutation.
  final Map<String, Map<String, dynamic>> commentsBefore;

  /// Snapshot of comments AFTER the mutation.
  Map<String, Map<String, dynamic>> commentsAfter;

  /// Snapshot of suggestions BEFORE the mutation.
  final Map<String, Map<String, dynamic>> suggestionsBefore;

  /// Snapshot of suggestions AFTER the mutation.
  Map<String, Map<String, dynamic>> suggestionsAfter;

  /// Document metadata BEFORE the mutation.
  final Map<String, dynamic> documentMetaBefore;

  /// Document metadata AFTER the mutation.
  Map<String, dynamic> documentMetaAfter;

  /// Metadata map (analogous to Yjs StackItem.meta).
  final Map<Symbol, dynamic> meta = {};

  /// The transaction origin string, if any.
  final String? origin;
  String? coalesceKey;
  int? timestampMs;

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
    required this.documentMetaBefore,
    required this.documentMetaAfter,
    this.origin,
    this.coalesceKey,
    this.timestampMs,
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
  static const int defaultCoalesceTimeoutMs = 500;
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
  Map<String, dynamic>? _capturedDocumentMeta;

  /// Transaction origins to exclude from undo tracking.
  final Set<String> _excludedOrigins;

  /// Whether we're currently capturing.
  bool _capturing = false;
  String? _captureCoalesceKey;
  int? _captureTimestampMs;
  bool _captureBreak = false;

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
  void beginCapture({String? coalesceKey, int? timestampMs}) {
    _capturing = true;
    _captureCoalesceKey = coalesceKey;
    _captureTimestampMs = timestampMs;
    _capturedBlocks = _doc.snapshotBlocks();
    _capturedEmbedContents = _doc.snapshotEmbedContents();
    _capturedTemplateContents = _doc.snapshotTemplateContents();
    _capturedListDefs = _doc.snapshotListDefs();
    _capturedComments = _doc.snapshotComments();
    _capturedSuggestions = _doc.snapshotSuggestions();
    _capturedDocumentMeta = _doc.snapshotMeta();
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
    // ignore: avoid_print
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
      documentMetaBefore: _capturedDocumentMeta!,
      documentMetaAfter: _doc.snapshotMeta(),
      origin: origin,
      coalesceKey: _captureCoalesceKey,
      timestampMs: _captureTimestampMs,
    );

    if (_same(item.blocksBefore, item.blocksAfter) &&
        _same(item.embedContentsBefore, item.embedContentsAfter) &&
        _same(item.templateContentsBefore, item.templateContentsAfter) &&
        _same(item.listDefsBefore, item.listDefsAfter) &&
        _same(item.commentsBefore, item.commentsAfter) &&
        _same(item.suggestionsBefore, item.suggestionsAfter) &&
        _same(item.documentMetaBefore, item.documentMetaAfter)) {
      _clearCapture();
      return;
    }

    // Weld selection entry.
    item.meta[_selKey] = SelectionEntry(
      before: selectionBefore,
      after: selectionAfter,
    );

    final previous = _undoStack.isNotEmpty ? _undoStack.last : null;
    final canMerge = previous != null &&
        !_captureBreak &&
        item.coalesceKey != null &&
        item.coalesceKey != 'command' &&
        previous.coalesceKey == item.coalesceKey &&
        item.timestampMs != null &&
        previous.timestampMs != null &&
        item.timestampMs! - previous.timestampMs! < defaultCoalesceTimeoutMs;
    if (canMerge) {
      previous
        ..blocksAfter = item.blocksAfter
        ..embedContentsAfter = item.embedContentsAfter
        ..templateContentsAfter = item.templateContentsAfter
        ..listDefsAfter = item.listDefsAfter
        ..commentsAfter = item.commentsAfter
        ..suggestionsAfter = item.suggestionsAfter
        ..documentMetaAfter = item.documentMetaAfter;
      final before = (previous.meta[_selKey] as SelectionEntry?)?.before;
      final after = (item.meta[_selKey] as SelectionEntry?)?.after;
      previous.meta[_selKey] = SelectionEntry(before: before, after: after);
    } else {
      _undoStack.add(item);
    }
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
      _doc.restoreMeta(item.documentMetaBefore);
    });

    // Push to redo stack.
    _redoStack.add(item);

    final dirtyIds = _dirtyIdsFor(item);

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
      _doc.restoreMeta(item.documentMetaAfter);
    });

    // Push back to undo stack.
    _undoStack.add(item);

    final dirtyIds = _dirtyIdsFor(item);

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

  void breakCoalescing() {
    _captureBreak = true;
  }

  void _clearCapture() {
    _capturedBlocks = null;
    _capturedEmbedContents = null;
    _capturedTemplateContents = null;
    _capturedListDefs = null;
    _capturedComments = null;
    _capturedSuggestions = null;
    _capturedDocumentMeta = null;
    _captureCoalesceKey = null;
    _captureTimestampMs = null;
    _captureBreak = false;
  }

  Set<BlockId> _dirtyIdsFor(StackItem item) {
    final dirtyIds = <BlockId>{};
    for (final ids in <Set<String>>[
      {...item.blocksBefore.keys, ...item.blocksAfter.keys},
      {...item.embedContentsBefore.keys, ...item.embedContentsAfter.keys},
      {...item.templateContentsBefore.keys, ...item.templateContentsAfter.keys},
    ]) {
      dirtyIds.addAll(ids.map(BlockId.new));
    }
    final sideTablesChanged = !_same(item.listDefsBefore, item.listDefsAfter) ||
        !_same(item.commentsBefore, item.commentsAfter) ||
        !_same(item.suggestionsBefore, item.suggestionsAfter) ||
        !_same(item.documentMetaBefore, item.documentMetaAfter);
    if (sideTablesChanged) {
      final root = _doc.meta['rootId'];
      dirtyIds.add(
          BlockId(root is String && root.isNotEmpty ? root : '__document__'));
    }
    return dirtyIds;
  }

  bool _same(Object a, Object b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

  Object? _canonical(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonical(entry.value),
      };
    }
    if (value is Iterable) return value.map(_canonical).toList();
    try {
      final dynamic json = (value as dynamic).toJson();
      return _canonical(json);
    } catch (_) {
      return value.toString();
    }
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
