/// Split a block into two adjacent siblings.
///
/// Port of `ops/split-block.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';
import '../suggestions.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class SplitBlockPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final BlockId parentId;
  final BlockId? originalNextId;
  final BlockId newBlockId;
  final String newType;
  final ReadonlyAttrs newAttrs;
  final int offset;

  const SplitBlockPlan({
    required this.blockId,
    required this.kind,
    required this.parentId,
    this.originalNextId,
    required this.newBlockId,
    required this.newType,
    required this.newAttrs,
    required this.offset,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Split a leaf block at [position] into two adjacent siblings under the same parent.
OperationResult splitBlockAtPosition(
  State state,
  Position position,
  IdAllocator allocator, {
  String? newType,
  ReadonlyAttrs? newAttrs,
}) {
  final plan = planSplitBlockAtPosition(
    state,
    position,
    allocator,
    newType: newType,
    newAttrs: newAttrs,
  );
  return applyOperation(state, (doc) {
    splitBlockAtPositionInTx(doc, plan);
  });
}

void splitBlockAtPositionInTx(TwDoc doc, SplitBlockPlan plan) {
  final yOriginal = _getMap(doc, plan.blockId, plan.kind);
  if (yOriginal == null) {
    throw StateError('splitBlockAtPositionInTx: original block not found');
  }

  final inlineContent = yOriginal[BlockFields.inlineContent] as InlineContent?;
  if (inlineContent == null) {
    throw StateError(
        'splitBlockAtPositionInTx: original block has no inlineContent');
  }

  final (prefix, suffix) =
      splitInlineContentAtOffset(inlineContent, plan.offset);

  // Update original block (prefix)
  yOriginal[BlockFields.inlineContent] = InlineContent(prefix);
  yOriginal[BlockFields.nextSiblingId] = plan.newBlockId.value;
  doc.markDirty(plan.blockId.value);

  // Create new block (suffix)
  final newBlockMap = {
    BlockFields.type: plan.newType,
    BlockFields.attrs: Map<String, dynamic>.of(plan.newAttrs),
    BlockFields.parentId: plan.parentId.value,
    BlockFields.prevSiblingId: plan.blockId.value,
    if (plan.originalNextId != null)
      BlockFields.nextSiblingId: plan.originalNextId!.value,
    BlockFields.inlineContent: InlineContent(suffix),
  };
  _setMap(doc, plan.newBlockId, plan.kind, newBlockMap);
  doc.markDirty(plan.newBlockId.value);

  // Rewire original next sibling
  if (plan.originalNextId != null) {
    final nextMap = _getMap(doc, plan.originalNextId!, plan.kind);
    if (nextMap != null) {
      nextMap[BlockFields.prevSiblingId] = plan.newBlockId.value;
      doc.markDirty(plan.originalNextId!.value);
    }
  }

  // Rewire parent if original was last child
  final parentMap = _getMap(doc, plan.parentId, plan.kind);
  if (parentMap != null &&
      parentMap[BlockFields.lastChildId] == plan.blockId.value) {
    parentMap[BlockFields.lastChildId] = plan.newBlockId.value;
    doc.markDirty(plan.parentId.value);
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

SplitBlockPlan planSplitBlockAtPosition(
  State state,
  Position position,
  IdAllocator allocator, {
  String? newType,
  ReadonlyAttrs? newAttrs,
}) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError(
        'splitBlockAtPosition: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  if (block.inlineContent == null || block.firstChildId != null) {
    throw StateError(
        'splitBlockAtPosition: block "${position.blockId}" is a container, not a leaf');
  }
  if (block.parentId == null) {
    throw StateError('splitBlockAtPosition: root block cannot be split');
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw StateError('splitBlockAtPosition: offset out of range');
  }

  final newBlockId = allocator.allocate();

  return SplitBlockPlan(
    blockId: position.blockId,
    kind: resolved.kind,
    parentId: block.parentId!,
    originalNextId: block.nextSiblingId,
    newBlockId: newBlockId,
    newType: newType ?? block.type,
    newAttrs: newAttrs ?? block.attrs,
    offset: position.offset,
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

void _setMap(
    TwDoc doc, BlockId id, ResolvedBlockKind kind, Map<String, dynamic> data) {
  switch (kind) {
    case ResolvedBlockKind.main:
      doc.setBlockMap(id.value, data);
    case ResolvedBlockKind.embed:
      doc.setEmbedContentMap(id.value, data);
    case ResolvedBlockKind.template:
      doc.setTemplateContentMap(id.value, data);
  }
}

// ---------------------------------------------------------------------------
// splitWithSuggestion
// ---------------------------------------------------------------------------

OperationResult splitWithSuggestion(State state, Position position,
    IdAllocator allocator, SuggestionMintInput input,
    [Map<String, dynamic>? newBlockInit]) {
  final plan = planSplitBlockAtPosition(state, position, allocator,
      newType: newBlockInit?['type'] as String?,
      newAttrs: newBlockInit?['attrs'] as ReadonlyAttrs?);

  final embed = EmbedItem(
    embedType: blockSplitSuggestionEmbedType,
    attrs: emptyAttrs,
    properties: {'suggestionId': input.id.value},
  );

  return applyOperation(state, (doc) {
    splitBlockAtPositionInTx(doc, plan);

    final targetMap = plan.kind == ResolvedBlockKind.embed
        ? doc.getEmbedContentMap(plan.blockId.value)
        : (plan.kind == ResolvedBlockKind.template
            ? doc.getTemplateContentMap(plan.blockId.value)
            : doc.getBlockMap(plan.blockId.value));

    if (targetMap != null) {
      final yItems = targetMap[BlockFields.inlineContent];
      if (yItems is InlineContent) {
        final newItems = List<InlineItem>.from(yItems.items)..add(embed);
        targetMap[BlockFields.inlineContent] = InlineContent(newItems);
        doc.markDirty(plan.blockId.value);
      }
    }

    writeSuggestionRecordInTx(
        doc,
        SuggestionRecord(
          id: input.id,
          kind: 'insertion',
          author: input.author,
          createdAt: input.createdAt,
        ));
  });
}
