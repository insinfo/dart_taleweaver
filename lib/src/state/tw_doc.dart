/// Document-model container that replaces Yjs (Y.Doc).
///
/// This is the core data store for the Taleweaver document model.
/// It maintains named maps for blocks, embed contents, template contents,
/// list definitions, comments, suggestions, and metadata.
///
/// Unlike the original TypeScript which uses Yjs CRDTs for real-time
/// collaboration, this implementation uses simple Dart maps with a
/// transaction system for batched mutations and dirty tracking.
library;

import 'block_id.dart';

// ---------------------------------------------------------------------------
// TwDoc — Document container
// ---------------------------------------------------------------------------

/// Callback invoked after a transaction completes.
typedef AfterTransactionCallback = void Function(
  Set<String> dirtyBlockIds,
  String? origin,
);

/// The core document data container, replacing Y.Doc from Yjs.
///
/// Maintains named maps for the document's various data stores and supports
/// transactions that batch mutations with dirty tracking.
class TwDoc {
  /// Block tree: blockId → block field map.
  final Map<String, Map<String, dynamic>> blocks = {};

  /// Embed content trees (footnote bodies, etc.): blockId → block field map.
  final Map<String, Map<String, dynamic>> embedContents = {};

  /// Template content trees (headers/footers): blockId → block field map.
  final Map<String, Map<String, dynamic>> templateContents = {};

  /// List definitions: listId → list config map.
  final Map<String, Map<String, dynamic>> listDefs = {};

  /// Comments side-table: commentId → comment record map.
  final Map<String, Map<String, dynamic>> comments = {};

  /// Suggestions side-table: suggestionId → suggestion record map.
  final Map<String, Map<String, dynamic>> suggestions = {};

  /// Metadata: immutable document-level fields (e.g. rootId).
  final Map<String, dynamic> meta = {};

  /// After-transaction listeners.
  final List<AfterTransactionCallback> _afterTransactionListeners = [];

  /// Whether we're currently inside a transaction.
  bool _inTransaction = false;

  /// The current transaction's origin (if any).
  String? _transactionOrigin;

  /// Dirty block IDs accumulated during the current transaction.
  final Set<String> _transactionDirtyIds = {};

  /// Nesting depth for transactions (supports nested transact calls).
  int _transactionDepth = 0;

  TwDoc();

  /// Register a listener called after each top-level transaction.
  void onAfterTransaction(AfterTransactionCallback callback) {
    _afterTransactionListeners.add(callback);
  }

  /// Remove an after-transaction listener.
  void offAfterTransaction(AfterTransactionCallback callback) {
    _afterTransactionListeners.remove(callback);
  }

  /// Whether a transaction is currently in progress.
  bool get inTransaction => _inTransaction;

  /// The current transaction's origin, if any.
  String? get transactionOrigin => _transactionOrigin;

  /// Execute [fn] within a transaction.
  ///
  /// Mutations within [fn] are batched. Dirty block IDs are accumulated
  /// and emitted to listeners when the outermost transaction completes.
  ///
  /// [origin] is an optional transaction origin string for filtering
  /// (e.g., 'suggestion-resolve' transactions are excluded from undo).
  void transact(void Function() fn, {String? origin}) {
    _transactionDepth++;
    final wasInTransaction = _inTransaction;
    _inTransaction = true;
    if (_transactionDepth == 1) {
      _transactionOrigin = origin;
      _transactionDirtyIds.clear();
    }

    try {
      fn();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        _inTransaction = false;
        final dirtyIds = Set<String>.of(_transactionDirtyIds);
        final txOrigin = _transactionOrigin;
        _transactionDirtyIds.clear();
        _transactionOrigin = null;

        // Notify listeners.
        if (!wasInTransaction) {
          for (final listener in _afterTransactionListeners) {
            listener(dirtyIds, txOrigin);
          }
        }
      }
    }
  }

  /// Mark a block ID as dirty within the current transaction.
  ///
  /// Called by state-layer mutation code whenever a block is created,
  /// modified, or deleted.
  void markDirty(String blockId) {
    _transactionDirtyIds.add(blockId);
  }

  // -------------------------------------------------------------------------
  // Block operations — convenience wrappers
  // -------------------------------------------------------------------------

  /// Get a block's field map, or null if not found.
  Map<String, dynamic>? getBlockMap(String blockId) => blocks[blockId];

  /// Set a block's complete field map.
  void setBlockMap(String blockId, Map<String, dynamic> fields) {
    blocks[blockId] = fields;
    markDirty(blockId);
  }

  /// Delete a block.
  void deleteBlock(String blockId) {
    blocks.remove(blockId);
    markDirty(blockId);
  }

  /// Update a single field of a block.
  void setBlockField(String blockId, String field, dynamic value) {
    final map = blocks[blockId];
    if (map != null) {
      map[field] = value;
      markDirty(blockId);
    }
  }

  /// Get a single field from a block, or null.
  dynamic getBlockField(String blockId, String field) {
    return blocks[blockId]?[field];
  }

  // -------------------------------------------------------------------------
  // Embed content operations
  // -------------------------------------------------------------------------

  Map<String, dynamic>? getEmbedContentMap(String blockId) =>
      embedContents[blockId];

  void setEmbedContentMap(String blockId, Map<String, dynamic> fields) {
    embedContents[blockId] = fields;
    markDirty(blockId);
  }

  void deleteEmbedContent(String blockId) {
    embedContents.remove(blockId);
    markDirty(blockId);
  }

  // -------------------------------------------------------------------------
  // Template content operations
  // -------------------------------------------------------------------------

  Map<String, dynamic>? getTemplateContentMap(String blockId) =>
      templateContents[blockId];

  void setTemplateContentMap(String blockId, Map<String, dynamic> fields) {
    templateContents[blockId] = fields;
    markDirty(blockId);
  }

  void deleteTemplateContent(String blockId) {
    templateContents.remove(blockId);
    markDirty(blockId);
  }

  // -------------------------------------------------------------------------
  // Snapshot: take a deep copy of all maps (for undo)
  // -------------------------------------------------------------------------

  /// Take a deep-copy snapshot of all block data (for undo).
  Map<String, Map<String, dynamic>> snapshotBlocks() {
    return blocks.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Take a deep-copy snapshot of embed contents.
  Map<String, Map<String, dynamic>> snapshotEmbedContents() {
    return embedContents.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Take a deep-copy snapshot of template contents.
  Map<String, Map<String, dynamic>> snapshotTemplateContents() {
    return templateContents
        .map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Take a deep-copy snapshot of list defs.
  Map<String, Map<String, dynamic>> snapshotListDefs() {
    return listDefs.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Take a deep-copy snapshot of comments.
  Map<String, Map<String, dynamic>> snapshotComments() {
    return comments.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Take a deep-copy snapshot of suggestions.
  Map<String, Map<String, dynamic>> snapshotSuggestions() {
    return suggestions.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v)));
  }

  /// Restore blocks from a snapshot.
  void restoreBlocks(Map<String, Map<String, dynamic>> snapshot) {
    blocks.clear();
    for (final entry in snapshot.entries) {
      blocks[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Restore embed contents from a snapshot.
  void restoreEmbedContents(Map<String, Map<String, dynamic>> snapshot) {
    embedContents.clear();
    for (final entry in snapshot.entries) {
      embedContents[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Restore template contents from a snapshot.
  void restoreTemplateContents(Map<String, Map<String, dynamic>> snapshot) {
    templateContents.clear();
    for (final entry in snapshot.entries) {
      templateContents[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Restore list defs from a snapshot.
  void restoreListDefs(Map<String, Map<String, dynamic>> snapshot) {
    listDefs.clear();
    for (final entry in snapshot.entries) {
      listDefs[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Restore comments from a snapshot.
  void restoreComments(Map<String, Map<String, dynamic>> snapshot) {
    comments.clear();
    for (final entry in snapshot.entries) {
      comments[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Restore suggestions from a snapshot.
  void restoreSuggestions(Map<String, Map<String, dynamic>> snapshot) {
    suggestions.clear();
    for (final entry in snapshot.entries) {
      suggestions[entry.key] = Map<String, dynamic>.of(entry.value);
    }
  }

  /// Create a new empty TwDoc with the given rootId.
  factory TwDoc.create({BlockId? rootId}) {
    final doc = TwDoc();
    if (rootId != null) {
      doc.meta['rootId'] = rootId.value;
    }
    return doc;
  }
}
