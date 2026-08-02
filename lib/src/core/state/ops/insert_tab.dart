/// Insert tab.
///
/// Port of `ops/insert-tab.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

const String tabEmbedType = 'tab';

class _TabInsertPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const _TabInsertPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

OperationResult insertTab(State state, Position position) {
  final plan = _planTabInsert(state, position);
  return applyOperation(state, (doc) {
    _insertTabInTx(doc, plan);
  });
}

_TabInsertPlan _planTabInsert(State state, Position position) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertTab: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  final kind = resolved.kind;
  if (block.inlineContent == null) {
    throw StateError('insertTab: block "${position.blockId}" is not a leaf');
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw RangeError('insertTab: offset out of range');
  }

  final tab = const EmbedItem(
    embedType: tabEmbedType,
    attrs: {},
    properties: {},
  );

  final split = splitInlineContentAtOffset(block.inlineContent!, position.offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems([...left, tab, ...right]);

  return _TabInsertPlan(
    blockId: position.blockId,
    kind: kind,
    items: items,
  );
}

void _insertTabInTx(TwDoc doc, _TabInsertPlan plan) {
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
