/// Reparent a run of blocks.
///
/// Port of `ops/reparent-children.ts`.
library;

import '../block_id.dart';
import '../block_schema.dart';
import '../block_traversal.dart';
import '../state.dart';
import '../tw_doc.dart';

class BlockFieldWrite {
  final BlockId blockId;
  final String field;
  final BlockId? value;

  const BlockFieldWrite(this.blockId, this.field, this.value);
}

class ReparentPlan {
  final List<BlockFieldWrite> writes;
  const ReparentPlan(this.writes);
}

class ComputeReparentWritesOpts {
  final List<BlockId> moved;
  final BlockId sourceParentId;
  final BlockId? sourceFirstChildId;
  final BlockId? sourceLastChildId;
  final BlockId? movedPrevSiblingId;
  final BlockId? movedNextSiblingId;
  final BlockId newParentId;
  final BlockId? newParentLastChildId;
  final BlockId? beforeSiblingId;
  final BlockId? beforeSiblingPrevId;

  const ComputeReparentWritesOpts({
    required this.moved,
    required this.sourceParentId,
    this.sourceFirstChildId,
    this.sourceLastChildId,
    this.movedPrevSiblingId,
    this.movedNextSiblingId,
    required this.newParentId,
    this.newParentLastChildId,
    this.beforeSiblingId,
    this.beforeSiblingPrevId,
  });
}

List<BlockFieldWrite> computeReparentWrites(ComputeReparentWritesOpts opts) {
  if (opts.moved.isEmpty) return const [];

  final m0 = opts.moved.first;
  final mk = opts.moved.last;

  if (opts.newParentId == opts.sourceParentId) {
    final alreadyInPlace = opts.beforeSiblingId == null
        ? opts.movedNextSiblingId == null
        : opts.beforeSiblingId == opts.movedNextSiblingId;
    if (alreadyInPlace) return const [];
  }

  final writeMap = <String, BlockFieldWrite>{};
  void put(BlockId blockId, String field, BlockId? value) {
    writeMap['$blockId $field'] = BlockFieldWrite(blockId, field, value);
  }

  if (opts.sourceFirstChildId == m0) {
    put(opts.sourceParentId, BlockFields.firstChildId, opts.movedNextSiblingId);
  }
  if (opts.sourceLastChildId == mk) {
    put(opts.sourceParentId, BlockFields.lastChildId, opts.movedPrevSiblingId);
  }
  if (opts.movedPrevSiblingId != null) {
    put(opts.movedPrevSiblingId!, BlockFields.nextSiblingId,
        opts.movedNextSiblingId);
  }
  if (opts.movedNextSiblingId != null) {
    put(opts.movedNextSiblingId!, BlockFields.prevSiblingId,
        opts.movedPrevSiblingId);
  }

  for (final id in opts.moved) {
    put(id, BlockFields.parentId, opts.newParentId);
  }

  if (opts.beforeSiblingId == null) {
    put(m0, BlockFields.prevSiblingId, opts.newParentLastChildId);
    put(mk, BlockFields.nextSiblingId, null);
    if (opts.newParentLastChildId != null) {
      put(opts.newParentLastChildId!, BlockFields.nextSiblingId, m0);
    } else {
      put(opts.newParentId, BlockFields.firstChildId, m0);
    }
    put(opts.newParentId, BlockFields.lastChildId, mk);
  } else {
    put(m0, BlockFields.prevSiblingId, opts.beforeSiblingPrevId);
    put(mk, BlockFields.nextSiblingId, opts.beforeSiblingId);
    put(opts.beforeSiblingId!, BlockFields.prevSiblingId, mk);
    if (opts.beforeSiblingPrevId != null) {
      put(opts.beforeSiblingPrevId!, BlockFields.nextSiblingId, m0);
    } else {
      put(opts.newParentId, BlockFields.firstChildId, m0);
    }
  }

  return writeMap.values.toList();
}

ReparentPlan planReparentChildren(
  State state,
  List<BlockId> blockIds,
  BlockId newParentId, [
  BlockId? beforeSiblingId,
]) {
  if (blockIds.isEmpty) return const ReparentPlan([]);

  for (final id in blockIds) {
    if (getBlock(state, id) == null) {
      throw StateError('reparentChildren: block "$id" not found');
    }
  }

  final newParent = getBlock(state, newParentId);
  if (newParent == null) {
    throw StateError('reparentChildren: newParent "$newParentId" not found');
  }
  if (newParent.inlineContent != null) {
    throw StateError('reparentChildren: newParent is a leaf, not container');
  }

  final first = blockIds.first;
  final firstBlock = getBlock(state, first)!;
  final sourceParentId = firstBlock.parentId;
  if (sourceParentId == null) {
    throw StateError('reparentChildren: root has no parent');
  }

  for (int i = 0; i < blockIds.length - 1; i++) {
    final cur = blockIds[i];
    final nxt = blockIds[i + 1];
    final curBlock = getBlock(state, cur)!;
    if (curBlock.nextSiblingId != nxt) {
      throw StateError('reparentChildren: blockIds must be contiguous');
    }
  }

  final newParentChain = ancestorChain(state, newParent);
  final movedSet = blockIds.toSet();
  for (final ancestorId in newParentChain.map((b) => b.id)) {
    if (movedSet.contains(ancestorId)) {
      throw StateError('reparentChildren: cycle');
    }
  }

  if (beforeSiblingId != null) {
    if (movedSet.contains(beforeSiblingId)) {
      throw StateError('reparentChildren: beforeSiblingId is in moved');
    }
    final beforeSibling = getBlock(state, beforeSiblingId);
    if (beforeSibling == null) {
      throw StateError('beforeSiblingId not found');
    }
    if (beforeSibling.parentId != newParentId) {
      throw StateError('beforeSiblingId not child of newParent');
    }
  }

  final lastBlock = getBlock(state, blockIds.last)!;
  final sourceParent = getBlock(state, sourceParentId)!;
  final beforeSibling =
      beforeSiblingId != null ? getBlock(state, beforeSiblingId) : null;

  final writes = computeReparentWrites(ComputeReparentWritesOpts(
    moved: blockIds,
    sourceParentId: sourceParentId,
    sourceFirstChildId: sourceParent.firstChildId,
    sourceLastChildId: sourceParent.lastChildId,
    movedPrevSiblingId: firstBlock.prevSiblingId,
    movedNextSiblingId: lastBlock.nextSiblingId,
    newParentId: newParentId,
    newParentLastChildId: newParent.lastChildId,
    beforeSiblingId: beforeSiblingId,
    beforeSiblingPrevId: beforeSibling?.prevSiblingId,
  ));

  return ReparentPlan(writes);
}

void reparentChildrenInTx(TwDoc doc, ReparentPlan plan) {
  for (final w in plan.writes) {
    final map = doc.getBlockMap(w.blockId.value);
    if (map != null) {
      if (w.value == null) {
        map.remove(w.field);
      } else {
        map[w.field] = w.value!.value;
      }
      doc.markDirty(w.blockId.value);
    }
  }
}

OperationResult reparentChildren(
  State state,
  List<BlockId> blockIds,
  BlockId newParentId, [
  BlockId? beforeSiblingId,
]) {
  final plan =
      planReparentChildren(state, blockIds, newParentId, beforeSiblingId);
  if (plan.writes.isEmpty) {
    return OperationResult(state: state, dirtyIds: const {});
  }
  return applyOperation(state, (doc) {
    reparentChildrenInTx(doc, plan);
  });
}
