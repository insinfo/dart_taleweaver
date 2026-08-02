/// Insert a new block as a child of a parent.
///
/// Port of `ops/insert-block.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_kinds.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class InsertBlockArgs {
  final String type;
  final ReadonlyAttrs? attrs;
  final InlineContent? inlineContent;

  const InsertBlockArgs({
    required this.type,
    this.attrs,
    this.inlineContent,
  });
}

class InsertBlockPlan {
  final BlockId parentId;
  final BlockId newId;
  final BlockId? prevSiblingId;
  final BlockId? nextSiblingId;
  final String type;
  final ReadonlyAttrs attrs;
  final InlineContent? inlineContent;

  const InsertBlockPlan({
    required this.parentId,
    required this.newId,
    this.prevSiblingId,
    this.nextSiblingId,
    required this.type,
    required this.attrs,
    this.inlineContent,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

OperationResult insertBlock(
  State state,
  BlockId parentId,
  BlockId? beforeSiblingId,
  InsertBlockArgs args,
  IdAllocator allocator, [
  BlockKindResolver? resolver,
]) {
  final plan = planInsertBlock(
      state, parentId, beforeSiblingId, args, allocator, resolver);
  return applyOperation(state, (doc) {
    insertBlockInTx(doc, plan);
  });
}

void insertBlockInTx(TwDoc doc, InsertBlockPlan plan) {
  // Add new block
  doc.setBlockMap(plan.newId.value, {
    BlockFields.type: plan.type,
    BlockFields.attrs: Map<String, dynamic>.of(plan.attrs),
    BlockFields.parentId: plan.parentId.value,
    BlockFields.prevSiblingId: plan.prevSiblingId?.value,
    BlockFields.nextSiblingId: plan.nextSiblingId?.value,
    BlockFields.firstChildId: null,
    BlockFields.lastChildId: null,
    BlockFields.inlineContent: plan.inlineContent,
  });
  doc.markDirty(plan.newId.value);

  // Rewire prev sibling
  if (plan.prevSiblingId != null) {
    final prevMap = doc.getBlockMap(plan.prevSiblingId!.value);
    if (prevMap != null) {
      prevMap[BlockFields.nextSiblingId] = plan.newId.value;
      doc.markDirty(plan.prevSiblingId!.value);
    }
  }

  // Rewire next sibling
  if (plan.nextSiblingId != null) {
    final nextMap = doc.getBlockMap(plan.nextSiblingId!.value);
    if (nextMap != null) {
      nextMap[BlockFields.prevSiblingId] = plan.newId.value;
      doc.markDirty(plan.nextSiblingId!.value);
    }
  }

  // Update parent if at boundary
  if (plan.prevSiblingId == null || plan.nextSiblingId == null) {
    final parentMap = doc.getBlockMap(plan.parentId.value);
    if (parentMap != null) {
      if (plan.prevSiblingId == null) {
        parentMap[BlockFields.firstChildId] = plan.newId.value;
      }
      if (plan.nextSiblingId == null) {
        parentMap[BlockFields.lastChildId] = plan.newId.value;
      }
      doc.markDirty(plan.parentId.value);
    }
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

InsertBlockPlan planInsertBlock(
  State state,
  BlockId parentId,
  BlockId? beforeSiblingId,
  InsertBlockArgs args,
  IdAllocator allocator, [
  BlockKindResolver? resolver,
]) {
  final parent = getBlock(state, parentId);
  if (parent == null) {
    throw StateError('insertBlock: parent "$parentId" not found');
  }

  if (resolver != null) {
    final parentKind = resolver.getBlockKind(parent.type);
    if (parentKind != Kind.container) {
      throw StateError(
        'insertBlock: parent "$parentId" is not a container, cannot insert child',
      );
    }
  }

  BlockId? prevSiblingId;
  BlockId? nextSiblingId;

  if (beforeSiblingId == null) {
    prevSiblingId = parent.lastChildId;
    nextSiblingId = null;
  } else {
    final beforeSibling = getBlock(state, beforeSiblingId);
    if (beforeSibling == null) {
      throw StateError(
          'insertBlock: beforeSibling "$beforeSiblingId" not found');
    }
    if (beforeSibling.parentId != parentId) {
      throw StateError(
          'insertBlock: beforeSibling is not a child of "$parentId"');
    }
    nextSiblingId = beforeSiblingId;
    prevSiblingId = beforeSibling.prevSiblingId;
  }

  final newId = allocator.allocate();

  return InsertBlockPlan(
    parentId: parentId,
    newId: newId,
    prevSiblingId: prevSiblingId,
    nextSiblingId: nextSiblingId,
    type: args.type,
    attrs: args.attrs ?? const {},
    inlineContent: args.inlineContent,
  );
}
