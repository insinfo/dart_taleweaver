/// Replace all matches.
///
/// Port of `ops/replace-matches.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../embed_content_cascade.dart';
import '../find_matches.dart';
import '../inline_content.dart';
import '../state.dart';

class BlockWrite {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const BlockWrite({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

class ReplaceAllPlan {
  final List<BlockWrite> blockWrites;
  final Set<BlockId> embedContentIdsToDelete;

  const ReplaceAllPlan({
    required this.blockWrites,
    required this.embedContentIdsToDelete,
  });
}

List<InlineItem> _spliceRun(
  List<InlineItem> items,
  int start,
  int end,
  String text,
  ReadonlyAttrs attrs, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final content = InlineContent(items);
  final split1 = splitInlineContentAtOffset(content, start);
  final left = split1.$1;
  final split2 = splitInlineContentAtOffset(content, end);
  final right = split2.$2;

  final mid = text.isEmpty
      ? <InlineItem>[]
      : <InlineItem>[TextItem(text: text, attrs: attrs)];

  return mergeAdjacentTextItems([...left, ...mid, ...right],
      customEquals: customEquals);
}

ReplaceAllPlan planReplaceMatches(
  State state,
  List<TextMatch> matches,
  String replacement, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final groups = <BlockId, List<TextMatch>>{};
  for (final m in matches) {
    groups.putIfAbsent(m.blockId, () => []).add(m);
  }

  final blockWrites = <BlockWrite>[];
  final embedContentIdsToDelete = <BlockId>{};

  for (final entry in groups.entries) {
    final blockId = entry.key;
    final blockMatches = entry.value;

    final resolved = resolveBlock(state, blockId);
    if (resolved == null) {
      throw StateError('planReplaceMatches: block "$blockId" not found');
    }
    final block = resolved.block;
    final kind = resolved.kind;
    if (block.inlineContent == null) {
      throw StateError(
          'planReplaceMatches: block "$blockId" is not a leaf (no inlineContent)');
    }

    for (var i = 1; i < blockMatches.length; i++) {
      final prev = blockMatches[i - 1];
      final curr = blockMatches[i];
      if (curr.start < prev.end) {
        throw StateError(
          'planReplaceMatches: matches in block "$blockId" must be ascending and '
          'non-overlapping (got [${prev.start},${prev.end}) then [${curr.start},${curr.end}))',
        );
      }
    }

    var items = block.inlineContent!.items;

    for (var i = blockMatches.length - 1; i >= 0; i--) {
      final m = blockMatches[i];

      final content = InlineContent(items);
      final afterStart = splitInlineContentAtOffset(content, m.start).$2;
      final removedSlice =
          splitInlineContentAtOffset(InlineContent(afterStart), m.end - m.start)
              .$1;

      collectEmbedContentSubtreeFromInlineContent(
        state,
        InlineContent(removedSlice),
        embedContentIdsToDelete,
      );

      final attrs = attrsAtOffset(content, m.start);
      items =
          _spliceRun(items, m.start, m.end, replacement, attrs, customEquals);
    }

    blockWrites.add(BlockWrite(blockId: blockId, kind: kind, items: items));
  }

  return ReplaceAllPlan(
    blockWrites: blockWrites,
    embedContentIdsToDelete: embedContentIdsToDelete,
  );
}

OperationResult replaceAllMatches(
  State state,
  List<TextMatch> matches,
  String replacement, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final plan = planReplaceMatches(state, matches, replacement, customEquals);
  if (plan.blockWrites.isEmpty && plan.embedContentIdsToDelete.isEmpty) {
    return OperationResult(state: state, dirtyIds: {});
  }
  return applyReplaceAllPlan(state, plan);
}

OperationResult applyReplaceAllPlan(
  State state,
  ReplaceAllPlan plan,
) {
  return applyOperation(state, (doc) {
    for (final w in plan.blockWrites) {
      final yBlock = w.kind == ResolvedBlockKind.embed
          ? doc.getEmbedContentMap(w.blockId.value)
          : (w.kind == ResolvedBlockKind.template
              ? doc.getTemplateContentMap(w.blockId.value)
              : doc.getBlockMap(w.blockId.value));

      if (yBlock != null) {
        yBlock['inlineContent'] = InlineContent(w.items);
        doc.markDirty(w.blockId.value);
      }
    }

    if (plan.embedContentIdsToDelete.isNotEmpty) {
      for (final id in plan.embedContentIdsToDelete) {
        doc.deleteEmbedContent(id.value);
      }
    }
  });
}
