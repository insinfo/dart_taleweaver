/// Remove a block (and its entire subtree) from the document tree.
///
/// Port of `ops/remove-block.ts`.
library;

import '../block_id.dart';
import '../block_schema.dart';
import '../embed_content_cascade.dart';
import '../state.dart';
import '../tw_doc.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class RemoveBlockPlan {
  final BlockId blockId;
  final BlockId parentId;
  final BlockId? prevSiblingId;
  final BlockId? nextSiblingId;
  final bool removingFirstChild;
  final bool removingLastChild;
  final Set<BlockId> subtreeIds;
  final Set<BlockId> embedContentIds;

  const RemoveBlockPlan({
    required this.blockId,
    required this.parentId,
    this.prevSiblingId,
    this.nextSiblingId,
    required this.removingFirstChild,
    required this.removingLastChild,
    required this.subtreeIds,
    required this.embedContentIds,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

OperationResult removeBlock(State state, BlockId blockId) {
  final plan = planRemoveBlock(state, blockId);
  return applyOperation(state, (doc) {
    removeBlockInTx(doc, plan);
  });
}

void removeBlockInTx(TwDoc doc, RemoveBlockPlan plan) {
  // Cascade delete embed contents
  for (final id in plan.embedContentIds) {
    doc.deleteEmbedContent(id.value);
  }

  // Rewire prev sibling
  if (plan.prevSiblingId != null) {
    final prevMap = doc.getBlockMap(plan.prevSiblingId!.value);
    if (prevMap != null) {
      prevMap[BlockFields.nextSiblingId] = plan.nextSiblingId?.value;
      doc.markDirty(plan.prevSiblingId!.value);
    }
  }

  // Rewire next sibling
  if (plan.nextSiblingId != null) {
    final nextMap = doc.getBlockMap(plan.nextSiblingId!.value);
    if (nextMap != null) {
      nextMap[BlockFields.prevSiblingId] = plan.prevSiblingId?.value;
      doc.markDirty(plan.nextSiblingId!.value);
    }
  }

  // Update parent if at boundary
  if (plan.removingFirstChild || plan.removingLastChild) {
    final parentMap = doc.getBlockMap(plan.parentId.value);
    if (parentMap != null) {
      if (plan.removingFirstChild) {
        parentMap[BlockFields.firstChildId] = plan.nextSiblingId?.value;
      }
      if (plan.removingLastChild) {
        parentMap[BlockFields.lastChildId] = plan.prevSiblingId?.value;
      }
      doc.markDirty(plan.parentId.value);
    }
  }

  // Delete from main tree
  for (final id in plan.subtreeIds) {
    doc.deleteBlock(id.value);
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

RemoveBlockPlan planRemoveBlock(State state, BlockId blockId) {
  final block = getBlock(state, blockId);
  if (block == null) {
    throw StateError('removeBlock: block "$blockId" not found');
  }
  if (blockId == state.rootId) {
    throw StateError('removeBlock: cannot remove root "$blockId"');
  }
  final parentId = block.parentId;
  if (parentId == null) {
    throw StateError('removeBlock: block "$blockId" is an orphan (no parent)');
  }
  final parent = getBlock(state, parentId);
  if (parent == null) {
    throw StateError('removeBlock: parent "$parentId" not found');
  }

  final subtreeIds = <BlockId>{};
  _collectSubtreeIds(state, blockId, subtreeIds);

  final embedContentIds = <BlockId>{};
  for (final id in subtreeIds) {
    final subBlock = getBlock(state, id);
    if (subBlock?.inlineContent != null) {
      collectEmbedContentSubtreeFromInlineContent(
        state,
        subBlock!.inlineContent!,
        embedContentIds,
      );
    }
  }

  return RemoveBlockPlan(
    blockId: blockId,
    parentId: parentId,
    prevSiblingId: block.prevSiblingId,
    nextSiblingId: block.nextSiblingId,
    removingFirstChild: parent.firstChildId == blockId,
    removingLastChild: parent.lastChildId == blockId,
    subtreeIds: subtreeIds,
    embedContentIds: embedContentIds,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _collectSubtreeIds(State state, BlockId rootId, Set<BlockId> out) {
  if (out.contains(rootId)) return;
  final block = getBlock(state, rootId);
  if (block == null) return;
  out.add(rootId);
  var current = block.firstChildId;
  while (current != null) {
    if (out.contains(current)) break;
    _collectSubtreeIds(state, current, out);
    final c = getBlock(state, current);
    current = c?.nextSiblingId;
  }
}
