/// Delete the inline content within a Span.
///
/// Port of `ops/delete-range.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../document_order.dart';
import '../embed_content_cascade.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

/// Pre-computed mutation plan for `deleteRangeInTx`.
sealed class DeleteRangePlan {
  const DeleteRangePlan();
}

class SameBlockDeletePlan extends DeleteRangePlan {
  final ResolvedBlockKind kind;
  final BlockId blockId;
  final List<InlineItem> mergedItems;
  final Set<BlockId> embedContentIds;

  const SameBlockDeletePlan({
    required this.kind,
    required this.blockId,
    required this.mergedItems,
    required this.embedContentIds,
  });
}

class CrossBlockDeletePlan extends DeleteRangePlan {
  final ResolvedBlockKind kind;
  final BlockId anchorId;
  final BlockId focusId;
  final List<BlockId> interveningIds;
  final BlockId? focusNextId;
  final BlockId parentId;
  final List<InlineItem> mergedItems;
  final Set<BlockId> embedContentIds;

  const CrossBlockDeletePlan({
    required this.kind,
    required this.anchorId,
    required this.focusId,
    required this.interveningIds,
    required this.focusNextId,
    required this.parentId,
    required this.mergedItems,
    required this.embedContentIds,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Delete the inline content within a Span.
OperationResult deleteRange(
  State state,
  Span span, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  if (span.anchor.blockId == span.focus.blockId &&
      span.anchor.offset == span.focus.offset) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final plan = planDeleteRange(state, span, customEquals: customEquals);
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }

  return applyOperation(state, (doc) {
    deleteRangeInTx(doc, plan);
  });
}

void deleteRangeInTx(TwDoc doc, DeleteRangePlan plan) {
  if (plan is SameBlockDeletePlan) {
    final map = _getMap(doc, plan.blockId, plan.kind);
    if (map != null) {
      map[BlockFields.inlineContent] = InlineContent(plan.mergedItems);
      doc.markDirty(plan.blockId.value);
    }
    for (final id in plan.embedContentIds) {
      doc.deleteEmbedContent(id.value);
    }
  } else if (plan is CrossBlockDeletePlan) {
    // 1. Update anchor
    final anchorMap = _getMap(doc, plan.anchorId, plan.kind);
    if (anchorMap != null) {
      anchorMap[BlockFields.inlineContent] = InlineContent(plan.mergedItems);
      anchorMap[BlockFields.nextSiblingId] = plan.focusNextId?.value;
      doc.markDirty(plan.anchorId.value);
    }

    // 2. Rewire sibling/parent
    if (plan.focusNextId != null) {
      final nextMap = _getMap(doc, plan.focusNextId!, plan.kind);
      if (nextMap != null) {
        nextMap[BlockFields.prevSiblingId] = plan.anchorId.value;
        doc.markDirty(plan.focusNextId!.value);
      }
    } else {
      final parentMap = _getMap(doc, plan.parentId, plan.kind);
      if (parentMap != null) {
        parentMap[BlockFields.lastChildId] = plan.anchorId.value;
        doc.markDirty(plan.parentId.value);
      }
    }

    // 3. Delete focus + intervening
    _deleteFromTree(doc, plan.focusId, plan.kind);
    for (final id in plan.interveningIds) {
      _deleteFromTree(doc, id, plan.kind);
    }

    // 4. Cascade delete embed contents
    for (final id in plan.embedContentIds) {
      doc.deleteEmbedContent(id.value);
    }
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

void assertDeleteRangeEndpoints(State state, Span span) {
  final sameBlock = span.anchor.blockId == span.focus.blockId;
  final rawAnchor = resolveBlock(state, span.anchor.blockId)?.block;
  if (rawAnchor == null) {
    throw StateError(
      sameBlock
          ? 'deleteRange: block "${span.anchor.blockId}" not found'
          : 'deleteRange: anchor block "${span.anchor.blockId}" not found',
    );
  }
  if (rawAnchor.inlineContent == null || rawAnchor.firstChildId != null) {
    throw StateError(
      sameBlock
          ? 'deleteRange: block "${span.anchor.blockId}" is a container, not a leaf'
          : 'deleteRange: anchor block "${span.anchor.blockId}" is a container, not a leaf',
    );
  }
  if (!sameBlock) {
    final rawFocus = resolveBlock(state, span.focus.blockId)?.block;
    if (rawFocus == null) {
      throw StateError('deleteRange: focus block "${span.focus.blockId}" not found');
    }
    if (rawFocus.inlineContent == null || rawFocus.firstChildId != null) {
      throw StateError(
        'deleteRange: focus block "${span.focus.blockId}" is a container, not a leaf',
      );
    }
  }
}

DeleteRangePlan? planDeleteRange(
  State state,
  Span span, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  assertDeleteRangeEndpoints(state, span);
  final normalized = normalizeSpan(state, span);

  if (normalized.anchor.blockId == normalized.focus.blockId) {
    final resolved = resolveBlock(state, normalized.anchor.blockId)!;
    final block = resolved.block;

    if (normalized.anchor.offset == normalized.focus.offset) return null;

    final (prefix, afterPrefix) = splitInlineContentAtOffset(
      block.inlineContent!,
      normalized.anchor.offset,
    );
    final (_, suffix) = splitInlineContentAtOffset(
      block.inlineContent!,
      normalized.focus.offset,
    );
    final merged = mergeAdjacentTextItems([...prefix, ...suffix], customEquals: customEquals);

    final deletedLength = normalized.focus.offset - normalized.anchor.offset;
    final (deletedItems, _) = splitInlineContentAtOffset(
      InlineContent(afterPrefix),
      deletedLength,
    );
    final embedContentIds = <BlockId>{};
    collectEmbedContentSubtreeFromInlineContent(
      state,
      InlineContent(deletedItems),
      embedContentIds,
    );

    return SameBlockDeletePlan(
      kind: resolved.kind,
      blockId: block.id,
      mergedItems: merged,
      embedContentIds: embedContentIds,
    );
  }

  final anchorResolved = resolveBlock(state, normalized.anchor.blockId)!;
  final anchorBlock = anchorResolved.block;
  final focusBlock = resolveBlock(state, normalized.focus.blockId)!.block;

  if (anchorBlock.parentId != focusBlock.parentId) {
    throw StateError('deleteRange: cross-parent spans are not supported.');
  }

  final parentId = anchorBlock.parentId;
  if (parentId == null) throw StateError('deleteRange: null parent (corrupt)');

  final interveningIds = <BlockId>[];
  var cur = anchorBlock.nextSiblingId;
  while (cur != null && cur != focusBlock.id) {
    final node = resolveBlock(state, cur)?.block;
    if (node == null) throw StateError('deleteRange: intervening sibling "$cur" not found');
    if (node.firstChildId != null || node.inlineContent == null) {
      throw StateError('deleteRange: intervening sibling "$cur" is a container');
    }
    interveningIds.add(cur);
    cur = node.nextSiblingId;
  }

  if (cur != focusBlock.id) {
    throw StateError('deleteRange: focus not reachable from anchor');
  }

  final focusNextId = focusBlock.nextSiblingId;

  final (anchorPrefix, anchorDeletedSuffix) = splitInlineContentAtOffset(
    anchorBlock.inlineContent!,
    normalized.anchor.offset,
  );
  final (focusDeletedPrefix, focusSuffix) = splitInlineContentAtOffset(
    focusBlock.inlineContent!,
    normalized.focus.offset,
  );
  final mergedItems = mergeAdjacentTextItems([...anchorPrefix, ...focusSuffix], customEquals: customEquals);

  final embedContentIds = <BlockId>{};
  collectEmbedContentSubtreeFromInlineContent(
    state,
    InlineContent(anchorDeletedSuffix),
    embedContentIds,
  );
  for (final id in interveningIds) {
    final block = resolveBlock(state, id)?.block;
    if (block?.inlineContent != null) {
      collectEmbedContentSubtreeFromInlineContent(state, block!.inlineContent!, embedContentIds);
    }
  }
  collectEmbedContentSubtreeFromInlineContent(
    state,
    InlineContent(focusDeletedPrefix),
    embedContentIds,
  );

  return CrossBlockDeletePlan(
    kind: anchorResolved.kind,
    anchorId: anchorBlock.id,
    focusId: focusBlock.id,
    interveningIds: interveningIds,
    focusNextId: focusNextId,
    parentId: parentId,
    mergedItems: mergedItems,
    embedContentIds: embedContentIds,
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
