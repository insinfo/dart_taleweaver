/// Insert inline image.
///
/// Port of `ops/insert-inline-image.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

const String inlineImageEmbedType = 'inline-image';

class InlineImageProperties {
  final String src;
  final num width;
  final num height;
  final String alt;

  const InlineImageProperties({
    required this.src,
    required this.width,
    required this.height,
    required this.alt,
  });
}

class _InlineImageInsertPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const _InlineImageInsertPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

OperationResult insertInlineImage(
  State state,
  Position position,
  InlineImageProperties properties,
) {
  final plan = _planInlineImageInsert(state, position, properties);
  return applyOperation(state, (doc) {
    _insertInlineImageInTx(doc, plan);
  });
}

_InlineImageInsertPlan _planInlineImageInsert(
  State state,
  Position position,
  InlineImageProperties properties,
) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertInlineImage: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  final kind = resolved.kind;
  if (block.inlineContent == null) {
    throw StateError('insertInlineImage: block "${position.blockId}" is not a leaf');
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw RangeError('insertInlineImage: offset out of range');
  }

  final image = EmbedItem(
    embedType: inlineImageEmbedType,
    attrs: const {},
    properties: {
      'src': properties.src,
      'width': properties.width,
      'height': properties.height,
      'alt': properties.alt,
    },
  );

  final split = splitInlineContentAtOffset(block.inlineContent!, position.offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems([...left, image, ...right]);

  return _InlineImageInsertPlan(
    blockId: position.blockId,
    kind: kind,
    items: items,
  );
}

void _insertInlineImageInTx(TwDoc doc, _InlineImageInsertPlan plan) {
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
