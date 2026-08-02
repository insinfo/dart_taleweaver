/// Section break operations.
///
/// Port of `ops/section-break.ts`.
library;

import '../block.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../block_traversal.dart';
import '../state.dart';
import '../tw_doc.dart';
import 'reparent_children.dart';

class SectionBreakResult {
  final OperationResult result;
  final BlockId newCursorBlockId;

  const SectionBreakResult(this.result, this.newCursorBlockId);
}

class SectionBreakPlan {
  final String kind;
  final BlockId boundary;
  final BlockId rootId;
  final List<BlockId> sectionIds;
  final List<ReparentPlan> reparentPlans;
  final List<BlockFieldWrite> pointerWrites;

  const SectionBreakPlan({
    required this.kind,
    required this.boundary,
    required this.rootId,
    required this.sectionIds,
    required this.reparentPlans,
    required this.pointerWrites,
  });
}

SectionBreakResult applySectionBreak(
    State state, Position cursor, IdAllocator allocator) {
  final plan = buildSectionBreakPlan(state, cursor, allocator);

  if (plan == null) {
    return SectionBreakResult(
        OperationResult(state: state, dirtyIds: const {}), cursor.blockId);
  }

  final result = applyOperation(state, (doc) {
    applySectionBreakInTx(doc, plan);
  });

  final boundaryBlock = getBlock(result.state, plan.boundary);
  final newCursorBlockId = boundaryBlock != null
      ? firstLeafBlock(result.state, boundaryBlock).id
      : plan.boundary;

  return SectionBreakResult(result, newCursorBlockId);
}

SectionBreakPlan? buildSectionBreakPlan(
    State state, Position cursor, IdAllocator allocator) {
  final chain = ancestorChain(state, getBlock(state, cursor.blockId)!);
  if (!chain.map((b) => b.id).contains(state.rootId)) {
    throw StateError('applySectionBreak: cursor block not under root');
  }

  Block? s;
  for (final b in chain) {
    if (b.type == 'section' && b.parentId == state.rootId) {
      s = b;
      break;
    }
  }

  final containerId = s?.id ?? state.rootId;
  final isExplicit = s != null;

  Block? boundaryBlock;
  for (final b in chain) {
    if (b.parentId == containerId) {
      boundaryBlock = b;
      break;
    }
  }

  if (boundaryBlock == null) {
    throw StateError('applySectionBreak: boundary not found');
  }
  final boundary = boundaryBlock.id;
  final container = getBlock(state, containerId)!;

  if (container.firstChildId == boundary) {
    return null;
  }

  final before = <BlockId>[];
  final atAfter = <BlockId>[];

  var cur = container.firstChildId;
  bool reachedBoundary = false;
  int guard = 0;
  final maxSteps = blockCount(state) + 1;

  while (cur != null) {
    if (++guard > maxSteps) throw StateError('cycle');
    if (cur == boundary) reachedBoundary = true;
    if (reachedBoundary)
      atAfter.add(cur);
    else
      before.add(cur);

    final b = getBlock(state, cur)!;
    cur = b.nextSiblingId;
  }

  final containerFirstChildId = container.firstChildId;
  final containerLastChildId = container.lastChildId;
  final beforeLast = before.last;
  final beforeBoundarySibling = beforeLast;

  if (!isExplicit) {
    final aId = allocator.allocate();
    final bId = allocator.allocate();

    final beforePlan =
        ReparentPlan(computeReparentWrites(ComputeReparentWritesOpts(
      moved: before,
      sourceParentId: state.rootId,
      sourceFirstChildId: containerFirstChildId,
      sourceLastChildId: containerLastChildId,
      movedPrevSiblingId: null,
      movedNextSiblingId: boundary,
      newParentId: aId,
      newParentLastChildId: null,
      beforeSiblingId: null,
      beforeSiblingPrevId: null,
    )));

    final atAfterPlan =
        ReparentPlan(computeReparentWrites(ComputeReparentWritesOpts(
      moved: atAfter,
      sourceParentId: state.rootId,
      sourceFirstChildId: containerFirstChildId,
      sourceLastChildId: containerLastChildId,
      movedPrevSiblingId: beforeBoundarySibling,
      movedNextSiblingId: null,
      newParentId: bId,
      newParentLastChildId: null,
      beforeSiblingId: null,
      beforeSiblingPrevId: null,
    )));

    final pointerWrites = [
      BlockFieldWrite(state.rootId, BlockFields.firstChildId, aId),
      BlockFieldWrite(state.rootId, BlockFields.lastChildId, bId),
      BlockFieldWrite(aId, BlockFields.prevSiblingId, null),
      BlockFieldWrite(aId, BlockFields.nextSiblingId, bId),
      BlockFieldWrite(bId, BlockFields.prevSiblingId, aId),
      BlockFieldWrite(bId, BlockFields.nextSiblingId, null),
    ];

    return SectionBreakPlan(
      kind: 'implicit',
      boundary: boundary,
      rootId: state.rootId,
      sectionIds: [aId, bId],
      reparentPlans: [beforePlan, atAfterPlan],
      pointerWrites: pointerWrites,
    );
  }

  final sPrimeId = allocator.allocate();
  final sOldNext = s.nextSiblingId;

  final atAfterPlan =
      ReparentPlan(computeReparentWrites(ComputeReparentWritesOpts(
    moved: atAfter,
    sourceParentId: containerId,
    sourceFirstChildId: containerFirstChildId,
    sourceLastChildId: containerLastChildId,
    movedPrevSiblingId: beforeBoundarySibling,
    movedNextSiblingId: null,
    newParentId: sPrimeId,
    newParentLastChildId: null,
    beforeSiblingId: null,
    beforeSiblingPrevId: null,
  )));

  final pointerWrites = [
    BlockFieldWrite(sPrimeId, BlockFields.prevSiblingId, containerId),
    BlockFieldWrite(sPrimeId, BlockFields.nextSiblingId, sOldNext),
    BlockFieldWrite(containerId, BlockFields.nextSiblingId, sPrimeId),
  ];

  if (sOldNext != null) {
    pointerWrites
        .add(BlockFieldWrite(sOldNext, BlockFields.prevSiblingId, sPrimeId));
  } else {
    pointerWrites
        .add(BlockFieldWrite(state.rootId, BlockFields.lastChildId, sPrimeId));
  }

  return SectionBreakPlan(
    kind: 'explicit',
    boundary: boundary,
    rootId: state.rootId,
    sectionIds: [sPrimeId],
    reparentPlans: [atAfterPlan],
    pointerWrites: pointerWrites,
  );
}

void applySectionBreakInTx(TwDoc doc, SectionBreakPlan plan) {
  for (final sectionId in plan.sectionIds) {
    doc.setBlockMap(sectionId.value, {
      BlockFields.type: 'section',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: plan.rootId.value,
    });
  }

  for (final reparentPlan in plan.reparentPlans) {
    reparentChildrenInTx(doc, reparentPlan);
  }

  for (final w in plan.pointerWrites) {
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
