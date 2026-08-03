/// State — the opaque document-state container.
///
/// Port of `state.ts`. Replaces the Yjs-backed State with a TwDoc-backed
/// implementation.
library;

import 'block.dart';
import 'block_id.dart';
import 'block_schema.dart';
import 'inline_content.dart';
import 'snapshot.dart';
import 'tw_doc.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Opaque document-state container.
///
/// Consumers read via [getBlock], [getEmbedContent], [getTemplateContent]
/// (or [resolveBlock] when the owning tree is unknown). [rootId] is a
/// stable BlockId — the entry point to the main document tree.
class State {
  /// The root block ID of the main document tree.
  final BlockId rootId;

  /// Internal: the underlying document data store.
  final TwDoc doc;

  /// Internal: per-State snapshot cache.
  final SnapshotCache _snapshotCache;

  State._({required this.rootId, required this.doc, SnapshotCache? cache})
      : _snapshotCache = cache ?? SnapshotCache();

  /// Access the snapshot cache (for internal use by state-layer code).
  SnapshotCache get snapshotCache => _snapshotCache;
}

// ---------------------------------------------------------------------------
// Creation
// ---------------------------------------------------------------------------

/// Create a new [State] with the given [rootId] and optional [doc].
State createState({required BlockId rootId, TwDoc? doc}) {
  final d = doc ?? TwDoc.create(rootId: rootId);
  // Ensure meta.rootId is set.
  if (d.meta['rootId'] == null) {
    d.meta['rootId'] = rootId.value;
  }
  return State._(rootId: rootId, doc: d);
}

// ---------------------------------------------------------------------------
// Snapshot accessors
// ---------------------------------------------------------------------------

/// Read a frozen [Block] snapshot from the main tree by id.
///
/// Returns null for unknown ids. Subsequent reads with no intervening
/// mutation return the same reference (cache hit).
Block? getBlock(State state, BlockId id) {
  return getBlockSnapshot(state.doc, id, state.snapshotCache);
}

/// Read a frozen [Block] snapshot from the embed-contents tree.
Block? getEmbedContent(State state, BlockId id) {
  return getEmbedContentSnapshot(state.doc, id, state.snapshotCache);
}

/// Read a frozen [Block] snapshot from the template-contents tree.
Block? getTemplateContent(State state, BlockId id) {
  return getTemplateContentSnapshot(state.doc, id, state.snapshotCache);
}

/// Resolve a block by searching all three trees (main, embed, template).
///
/// Returns a [ResolvedBlock] with the block and its owning tree kind,
/// or null if not found in any tree.
ResolvedBlock? resolveBlock(State state, BlockId id) {
  final main = getBlock(state, id);
  if (main != null) return ResolvedBlock(main, ResolvedBlockKind.main);
  final embed = getEmbedContent(state, id);
  if (embed != null) return ResolvedBlock(embed, ResolvedBlockKind.embed);
  final template = getTemplateContent(state, id);
  if (template != null) {
    return ResolvedBlock(template, ResolvedBlockKind.template);
  }
  return null;
}

/// Get the set of embed content root IDs.
Set<BlockId> getEmbedContentIds(State state) {
  return state.doc.embedContents.keys.map(BlockId.new).toSet();
}

/// Get the set of template content root IDs.
Set<BlockId> getTemplateContentIds(State state) {
  return state.doc.templateContents.keys.map(BlockId.new).toSet();
}

/// Total count of blocks across all trees (for cycle detection bounds).
int blockCount(State state) {
  return state.doc.blocks.length +
      state.doc.embedContents.length +
      state.doc.templateContents.length;
}

// ---------------------------------------------------------------------------
// ResolvedBlock
// ---------------------------------------------------------------------------

/// Which tree a resolved block was found in.
enum ResolvedBlockKind { main, embed, template }

/// A block resolved from one of the three trees.
class ResolvedBlock {
  final Block block;
  final ResolvedBlockKind kind;

  const ResolvedBlock(this.block, this.kind);
}

// ---------------------------------------------------------------------------
// OperationResult
// ---------------------------------------------------------------------------

/// Result of [applyOperation]: the new state + the set of dirty block IDs.
class OperationResult {
  final State state;
  final Set<BlockId> dirtyIds;

  const OperationResult({required this.state, required this.dirtyIds});
}

/// Apply a mutation function within a transaction on [state].
///
/// Returns a new [OperationResult] with a fresh state (invalidated cache)
/// and the set of block IDs that were dirtied by the mutation.
OperationResult applyOperation(
  State state,
  void Function(TwDoc doc) mutationFn, {
  String? origin,
}) {
  final dirtyIds = <BlockId>{};
  late final AfterTransactionCallback listener;
  listener = (ids, _) {
    dirtyIds.addAll(ids.map(BlockId.new));
  };
  state.doc.onAfterTransaction(listener);
  try {
    state.doc.transact(() {
      mutationFn(state.doc);
    }, origin: origin);
  } finally {
    state.doc.offAfterTransaction(listener);
  }

  if (dirtyIds.isEmpty) {
    return OperationResult(state: state, dirtyIds: dirtyIds);
  }

  state.snapshotCache.invalidate(dirtyIds.map((id) => id.value).toSet());
  return OperationResult(state: freshState(state), dirtyIds: dirtyIds);
}

/// Create a fresh [State] from the same doc but with a new snapshot cache.
///
/// Used after mutations to ensure reads go through fresh snapshots.
State freshState(State state) {
  return State._(rootId: state.rootId, doc: state.doc);
}

// ---------------------------------------------------------------------------
// Block writing helpers (used by Layer 3 ops)
// ---------------------------------------------------------------------------

/// Write a complete block to the main tree.
void writeBlock(
  TwDoc doc,
  BlockId id, {
  required String type,
  Map<String, dynamic> attrs = const {},
  BlockId? parentId,
  BlockId? prevSiblingId,
  BlockId? nextSiblingId,
  BlockId? firstChildId,
  BlockId? lastChildId,
  InlineContent? inlineContent,
}) {
  doc.setBlockMap(id.value, {
    BlockFields.type: type,
    BlockFields.attrs: Map<String, dynamic>.of(attrs),
    if (parentId != null) BlockFields.parentId: parentId.value,
    if (prevSiblingId != null) BlockFields.prevSiblingId: prevSiblingId.value,
    if (nextSiblingId != null) BlockFields.nextSiblingId: nextSiblingId.value,
    if (firstChildId != null) BlockFields.firstChildId: firstChildId.value,
    if (lastChildId != null) BlockFields.lastChildId: lastChildId.value,
    if (inlineContent != null) BlockFields.inlineContent: inlineContent,
  });
}

/// Update a single field of a block in the main tree.
void updateBlockField(TwDoc doc, BlockId id, String field, dynamic value) {
  final map = doc.getBlockMap(id.value);
  if (map == null) {
    throw StateError('updateBlockField: block $id not found');
  }
  if (value == null) {
    map.remove(field);
  } else {
    map[field] = value;
  }
  doc.markDirty(id.value);
}

/// Create an empty document with a root block and one empty paragraph.
State createEmptyDocument({IdAllocator? allocator}) {
  final alloc = allocator ?? productionAllocator;
  final rootId = alloc.allocate();
  final paraId = alloc.allocate();

  final doc = TwDoc.create(rootId: rootId);

  // Create root document block.
  doc.setBlockMap(rootId.value, {
    BlockFields.type: 'document',
    BlockFields.attrs: <String, dynamic>{},
    BlockFields.firstChildId: paraId.value,
    BlockFields.lastChildId: paraId.value,
  });

  // Create empty paragraph.
  doc.setBlockMap(paraId.value, {
    BlockFields.type: 'paragraph',
    BlockFields.attrs: <String, dynamic>{},
    BlockFields.parentId: rootId.value,
    BlockFields.inlineContent: const InlineContent([]),
  });

  return State._(rootId: rootId, doc: doc);
}
