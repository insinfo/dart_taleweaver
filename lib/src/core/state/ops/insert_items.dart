/// Insert items in-place (generalization of text split/replace).
///
/// Port of `ops/insert-items.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

class InsertItemsPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const InsertItemsPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

InsertItemsPlan planInsertItemsSplitInPlace(
  BlockId blockId,
  ResolvedBlockKind kind,
  List<InlineItem> liveItems,
  int offset,
  List<InlineItem> itemsToInsert, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final split = splitInlineContentAtOffset(InlineContent(liveItems), offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems(
    [...left, ...itemsToInsert, ...right],
    customEquals: customEquals,
  );

  return InsertItemsPlan(
    blockId: blockId,
    kind: kind,
    items: items,
  );
}

InsertItemsPlan planReplaceBlockTailInPlace(
  BlockId blockId,
  ResolvedBlockKind kind,
  List<InlineItem> liveItems,
  int keepOffset,
  List<InlineItem> itemsToInsert, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final split = splitInlineContentAtOffset(InlineContent(liveItems), keepOffset);
  final left = split.$1;
  // We throw away `split.$2` (the tail).

  final items = mergeAdjacentTextItems(
    [...left, ...itemsToInsert],
    customEquals: customEquals,
  );

  return InsertItemsPlan(
    blockId: blockId,
    kind: kind,
    items: items,
  );
}

void insertItemsInTx(TwDoc doc, InsertItemsPlan plan) {
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
