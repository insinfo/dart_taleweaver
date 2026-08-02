/// Insert cross reference field.
///
/// Port of `ops/insert-cross-reference.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

const String crossReferenceEmbedType = 'cross-reference';

class _CrossReferenceInsertPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const _CrossReferenceInsertPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

OperationResult insertCrossReference(
  State state,
  Position position,
  BlockId targetId,
  String refMode, [
  String numberStyle = 'decimal',
]) {
  final plan = _planCrossReferenceInsert(state, position, targetId, refMode, numberStyle);
  return applyOperation(state, (doc) {
    _insertCrossReferenceInTx(doc, plan);
  });
}

_CrossReferenceInsertPlan _planCrossReferenceInsert(
  State state,
  Position position,
  BlockId targetId,
  String refMode,
  String numberStyle,
) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertCrossReference: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  final kind = resolved.kind;
  if (block.inlineContent == null) {
    throw StateError('insertCrossReference: block "${position.blockId}" is not a leaf');
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw RangeError('insertCrossReference: offset out of range');
  }

  final properties = refMode == 'page'
      ? { 'targetId': targetId.value, 'refMode': refMode, 'numberStyle': numberStyle }
      : { 'targetId': targetId.value, 'refMode': refMode };

  final reference = EmbedItem(
    embedType: crossReferenceEmbedType,
    attrs: const {},
    properties: properties,
  );

  final split = splitInlineContentAtOffset(block.inlineContent!, position.offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems([...left, reference, ...right]);

  return _CrossReferenceInsertPlan(
    blockId: position.blockId,
    kind: kind,
    items: items,
  );
}

void _insertCrossReferenceInTx(TwDoc doc, _CrossReferenceInsertPlan plan) {
  final yBlock = plan.kind == ResolvedBlockKind.embed
      ? doc.getEmbedContentMap(plan.blockId.value)
      : (plan.kind == ResolvedBlockKind.template
          ? doc.getTemplateContentMap(plan.blockId.value)
          : doc.getBlockMap(plan.blockId.value));

  if (yBlock != null) {
    yBlock['inlineContent'] = InlineContent(plan.items);
    doc.markDirty(plan.blockId.value);
  }
}
