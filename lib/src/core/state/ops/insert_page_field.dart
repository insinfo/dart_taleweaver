/// Insert page field.
///
/// Port of `ops/insert-page-field.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../inline_content.dart';
import '../page_field.dart';
import '../state.dart';
import '../tw_doc.dart';

class _PageFieldInsertPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const _PageFieldInsertPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

OperationResult insertPageField(
  State state,
  Position position,
  String fieldKind, [
  String numberStyle = 'decimal',
]) {
  final plan = _planPageFieldInsert(state, position, fieldKind, numberStyle);
  return applyOperation(state, (doc) {
    _insertPageFieldInTx(doc, plan);
  });
}

_PageFieldInsertPlan _planPageFieldInsert(
  State state,
  Position position,
  String fieldKind,
  String numberStyle,
) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertPageField: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  final kind = resolved.kind;
  if (block.inlineContent == null) {
    throw StateError(
        'insertPageField: block "${position.blockId}" is not a leaf');
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw RangeError('insertPageField: offset out of range');
  }

  final field = EmbedItem(
    embedType: pageFieldEmbedType,
    attrs: const {},
    properties: {'fieldKind': fieldKind, 'numberStyle': numberStyle},
  );

  final split =
      splitInlineContentAtOffset(block.inlineContent!, position.offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems([...left, field, ...right]);

  return _PageFieldInsertPlan(
    blockId: position.blockId,
    kind: kind,
    items: items,
  );
}

void _insertPageFieldInTx(TwDoc doc, _PageFieldInsertPlan plan) {
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
