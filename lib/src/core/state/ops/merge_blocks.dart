/// Merge two adjacent leaf siblings into one block.
///
/// Port of `ops/merge-blocks.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class MergeBlocksPlan {
  final BlockId leftId;
  final BlockId rightId;
  final ResolvedBlockKind kind;
  final BlockId parentId;
  final BlockId? rightNextId;

  const MergeBlocksPlan({
    required this.leftId,
    required this.rightId,
    required this.kind,
    required this.parentId,
    this.rightNextId,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Merge two adjacent leaf siblings into one block. Left wins.
OperationResult mergeAdjacentBlocks(
  State state,
  BlockId leftId,
  BlockId rightId, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final plan = planMergeAdjacentBlocks(state, leftId, rightId);
  return applyOperation(state, (doc) {
    mergeAdjacentBlocksInTx(doc, plan, customEquals: customEquals);
  });
}

void mergeAdjacentBlocksInTx(
  TwDoc doc,
  MergeBlocksPlan plan, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final leftMap = _getMap(doc, plan.leftId, plan.kind);
  final rightMap = _getMap(doc, plan.rightId, plan.kind);
  if (leftMap == null || rightMap == null) return;

  final leftItems = (leftMap[BlockFields.inlineContent] as InlineContent).items;
  final rightItems = (rightMap[BlockFields.inlineContent] as InlineContent).items;

  final merged = mergeAdjacentTextItems(
    [...leftItems, ...rightItems],
    customEquals: customEquals,
  );

  leftMap[BlockFields.inlineContent] = InlineContent(merged);
  leftMap[BlockFields.nextSiblingId] = plan.rightNextId?.value;
  doc.markDirty(plan.leftId.value);

  if (plan.rightNextId != null) {
    final nextMap = _getMap(doc, plan.rightNextId!, plan.kind);
    if (nextMap != null) {
      nextMap[BlockFields.prevSiblingId] = plan.leftId.value;
      doc.markDirty(plan.rightNextId!.value);
    }
  } else {
    final parentMap = _getMap(doc, plan.parentId, plan.kind);
    if (parentMap != null) {
      parentMap[BlockFields.lastChildId] = plan.leftId.value;
      doc.markDirty(plan.parentId.value);
    }
  }

  _deleteFromTree(doc, plan.rightId, plan.kind);
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

MergeBlocksPlan planMergeAdjacentBlocks(
  State state,
  BlockId leftId,
  BlockId rightId,
) {
  if (leftId == rightId) {
    throw StateError('mergeAdjacentBlocks: left and right are the same block "$leftId"');
  }

  final leftResolved = resolveBlock(state, leftId);
  if (leftResolved == null) {
    throw StateError('mergeAdjacentBlocks: left block "$leftId" not found');
  }
  final left = leftResolved.block;
  final kind = leftResolved.kind;

  final right = resolveBlock(state, rightId)?.block;
  if (right == null) {
    throw StateError('mergeAdjacentBlocks: right block "$rightId" not found');
  }

  if (left.inlineContent == null || left.firstChildId != null) {
    throw StateError('mergeAdjacentBlocks: left block "$leftId" is a container, not a leaf');
  }
  if (right.inlineContent == null || right.firstChildId != null) {
    throw StateError('mergeAdjacentBlocks: right block "$rightId" is a container, not a leaf');
  }

  if (left.parentId != right.parentId) {
    throw StateError('mergeAdjacentBlocks: blocks have different parents');
  }

  if (left.nextSiblingId != rightId || right.prevSiblingId != leftId) {
    throw StateError('mergeAdjacentBlocks: blocks are not adjacent siblings');
  }

  if (left.parentId == null) {
    throw StateError('mergeAdjacentBlocks: blocks have null parent');
  }

  return MergeBlocksPlan(
    leftId: leftId,
    rightId: rightId,
    kind: kind,
    parentId: left.parentId!,
    rightNextId: right.nextSiblingId,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic>? _getMap(TwDoc doc, BlockId id, ResolvedBlockKind kind) {
  switch (kind) {
    case ResolvedBlockKind.main:
      return doc.getBlockMap(id.value);
    case ResolvedBlockKind.embed:
      return doc.getEmbedContentMap(id.value);
    case ResolvedBlockKind.template:
      return doc.getTemplateContentMap(id.value);
  }
}

void _deleteFromTree(TwDoc doc, BlockId id, ResolvedBlockKind kind) {
  switch (kind) {
    case ResolvedBlockKind.main:
      doc.deleteBlock(id.value);
    case ResolvedBlockKind.embed:
      doc.deleteEmbedContent(id.value);
    case ResolvedBlockKind.template:
      doc.deleteTemplateContent(id.value);
  }
}
