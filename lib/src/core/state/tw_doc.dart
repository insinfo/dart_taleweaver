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
import 'inline_content.dart';

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

  Map<String, Map<String, dynamic>>? _beforeBlocks;
  Map<String, Map<String, dynamic>>? _beforeEmbedContents;
  Map<String, Map<String, dynamic>>? _beforeTemplateContents;

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
      _beforeBlocks = snapshotBlocks();
      _beforeEmbedContents = snapshotEmbedContents();
      _beforeTemplateContents = snapshotTemplateContents();
    }

    try {
      fn();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        _captureTreeChanges();
        _inTransaction = false;
        final dirtyIds = Set<String>.of(_transactionDirtyIds);
        final txOrigin = _transactionOrigin;
        _transactionDirtyIds.clear();
        _transactionOrigin = null;
        _beforeBlocks = null;
        _beforeEmbedContents = null;
        _beforeTemplateContents = null;

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

  void _captureTreeChanges() {
    final before = <String, Map<String, Map<String, dynamic>>?>{
      'blocks': _beforeBlocks,
      'embedContents': _beforeEmbedContents,
      'templateContents': _beforeTemplateContents,
    };
    final after = <String, Map<String, Map<String, dynamic>>>{
      'blocks': blocks,
      'embedContents': embedContents,
      'templateContents': templateContents,
    };
    for (final name in before.keys) {
      final oldTable = before[name];
      final newTable = after[name]!;
      if (oldTable == null) continue;
      for (final id in {...oldTable.keys, ...newTable.keys}) {
        if (!_deepEqual(oldTable[id], newTable[id])) {
          _transactionDirtyIds.add(id);
        }
      }
    }
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
    return _deepCopyTable(blocks);
  }

  /// Take a deep-copy snapshot of embed contents.
  Map<String, Map<String, dynamic>> snapshotEmbedContents() {
    return _deepCopyTable(embedContents);
  }

  /// Take a deep-copy snapshot of template contents.
  Map<String, Map<String, dynamic>> snapshotTemplateContents() {
    return _deepCopyTable(templateContents);
  }

  /// Take a deep-copy snapshot of list defs.
  Map<String, Map<String, dynamic>> snapshotListDefs() {
    return _deepCopyTable(listDefs);
  }

  /// Take a deep-copy snapshot of comments.
  Map<String, Map<String, dynamic>> snapshotComments() {
    return _deepCopyTable(comments);
  }

  /// Take a deep-copy snapshot of suggestions.
  Map<String, Map<String, dynamic>> snapshotSuggestions() {
    return _deepCopyTable(suggestions);
  }

  /// Restore blocks from a snapshot.
  void restoreBlocks(Map<String, Map<String, dynamic>> snapshot) {
    blocks.clear();
    for (final entry in snapshot.entries) {
      blocks[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
    }
  }

  /// Restore embed contents from a snapshot.
  void restoreEmbedContents(Map<String, Map<String, dynamic>> snapshot) {
    embedContents.clear();
    for (final entry in snapshot.entries) {
      embedContents[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
    }
  }

  /// Restore template contents from a snapshot.
  void restoreTemplateContents(Map<String, Map<String, dynamic>> snapshot) {
    templateContents.clear();
    for (final entry in snapshot.entries) {
      templateContents[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
    }
  }

  /// Restore list defs from a snapshot.
  void restoreListDefs(Map<String, Map<String, dynamic>> snapshot) {
    listDefs.clear();
    for (final entry in snapshot.entries) {
      listDefs[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
    }
  }

  /// Restore comments from a snapshot.
  void restoreComments(Map<String, Map<String, dynamic>> snapshot) {
    comments.clear();
    for (final entry in snapshot.entries) {
      comments[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
    }
  }

  /// Restore suggestions from a snapshot.
  void restoreSuggestions(Map<String, Map<String, dynamic>> snapshot) {
    suggestions.clear();
    for (final entry in snapshot.entries) {
      suggestions[entry.key] =
          Map<String, dynamic>.from(_deepClone(entry.value) as Map);
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
  Map<String, dynamic> toJson() {
    return {
      'meta': meta,
      'blocks': blocks,
      'embedContents': embedContents,
      'templateContents': templateContents,
      'listDefs': listDefs,
      'comments': comments,
      'suggestions': suggestions,
    };
  }

  factory TwDoc.fromJson(Map<String, dynamic> json) {
    final doc =
        TwDoc.create(rootId: BlockId(json['meta']?['rootId'] ?? 'unknown'));
    doc.meta.addAll(Map<String, dynamic>.from(json['meta'] ?? {}));
    doc.blocks.addAll(_decodeTable(json['blocks']));
    doc.embedContents.addAll(_decodeTable(json['embedContents']));
    doc.templateContents.addAll(_decodeTable(json['templateContents']));
    doc.listDefs.addAll(_decodeTable(json['listDefs']));
    doc.comments.addAll(_decodeTable(json['comments']));
    doc.suggestions.addAll(_decodeTable(json['suggestions']));
    return doc;
  }

  List<BlockId> getEmbedContentIds() {
    return embedContents.keys.map((k) => BlockId(k)).toList();
  }

  List<BlockId> getTemplateContentIds() {
    return templateContents.keys.map((k) => BlockId(k)).toList();
  }
}

Map<String, Map<String, dynamic>> _decodeTable(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) {
    final fields = value is Map ? value : const <String, dynamic>{};
    return MapEntry(
      key.toString(),
      _deepClone(Map<String, dynamic>.from(fields)) as Map<String, dynamic>,
    );
  });
}

Map<String, Map<String, dynamic>> _deepCopyTable(
  Map<String, Map<String, dynamic>> source,
) {
  return source.map(
    (key, value) => MapEntry(
      key,
      Map<String, dynamic>.from(_deepClone(value) as Map),
    ),
  );
}

dynamic _deepClone(dynamic value) {
  if (value is InlineContent) {
    return InlineContent(
        value.items.map(_deepCloneInlineItem).toList(growable: false));
  }
  if (value is Map) {
    return <dynamic, dynamic>{
      for (final entry in value.entries) entry.key: _deepClone(entry.value),
    };
  }
  if (value is List) return value.map(_deepClone).toList(growable: false);
  if (value is Set) return value.map(_deepClone).toSet();
  return value;
}

InlineItem _deepCloneInlineItem(InlineItem item) {
  return switch (item) {
    TextItem(:final text, :final attrs) => TextItem(
        text: text,
        attrs: Map<String, dynamic>.from(_deepClone(attrs) as Map),
      ),
    EmbedItem(:final embedType, :final attrs, :final properties) => EmbedItem(
        embedType: embedType,
        attrs: Map<String, dynamic>.from(_deepClone(attrs) as Map),
        properties: Map<String, dynamic>.from(_deepClone(properties) as Map),
      ),
  };
}

bool _deepEqual(dynamic a, dynamic b) {
  if (a is InlineContent && b is InlineContent) {
    return a.items.length == b.items.length &&
        a.items.asMap().entries.every(
            (entry) => _deepEqualInlineItem(entry.value, b.items[entry.key]));
  }
  if (a is Map && b is Map) {
    if (a.length != b.length || !a.keys.every(b.containsKey)) return false;
    return a.keys.every((key) => _deepEqual(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        a
            .asMap()
            .entries
            .every((entry) => _deepEqual(entry.value, b[entry.key]));
  }
  if (a is Set && b is Set) return a.length == b.length && a.containsAll(b);
  return a == b;
}

bool _deepEqualInlineItem(InlineItem a, InlineItem b) {
  if (a is TextItem && b is TextItem) {
    return a.text == b.text && _deepEqual(a.attrs, b.attrs);
  }
  if (a is EmbedItem && b is EmbedItem) {
    return a.embedType == b.embedType &&
        _deepEqual(a.attrs, b.attrs) &&
        _deepEqual(a.properties, b.properties);
  }
  return false;
}
