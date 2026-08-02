/// Apply attrs to all inline content within a span.
///
/// Port of `ops/apply-attrs.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../span_iteration.dart';
import '../state.dart';
import '../tw_doc.dart';
import 'dart:math';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class ApplyAttrsToRangePlan {
  final List<BlockRange> segments;
  final ResolvedBlockKind kind;

  const ApplyAttrsToRangePlan({
    required this.segments,
    required this.kind,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Apply [attrs] to all inline content within [span].
OperationResult applyAttrsToRange(
  State state,
  Span span,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  if (attrs.isEmpty) {
    return OperationResult(state: state, dirtyIds: {});
  }
  if (span.anchor.blockId == span.focus.blockId &&
      span.anchor.offset == span.focus.offset) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final plan = planApplyAttrsToRange(state, span);
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }

  return applyOperation(state, (doc) {
    applyAttrsToRangeInTx(doc, plan, attrs, customEquals: customEquals);
  });
}

void applyAttrsToRangeInTx(
  TwDoc doc,
  ApplyAttrsToRangePlan plan,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  for (final seg in plan.segments) {
    if (seg.rangeStart >= seg.rangeEnd) continue;

    final map = _getMap(doc, seg.block.id, plan.kind);
    if (map == null) continue;

    final content = map[BlockFields.inlineContent] as InlineContent?;
    if (content == null) continue;

    final newItems = _applyAttrsToBlockRange(
      content.items,
      seg.rangeStart,
      seg.rangeEnd,
      attrs,
      customEquals,
    );
    final merged = mergeAdjacentTextItems(newItems, customEquals: customEquals);

    map[BlockFields.inlineContent] = InlineContent(merged);
    doc.markDirty(seg.block.id.value);
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

ApplyAttrsToRangePlan? planApplyAttrsToRange(State state, Span span) {
  final segments = iterateSpan(state, span).toList();
  if (segments.isEmpty) return null;

  final firstBlockId = segments.first.block.id;
  final kind =
      resolveBlock(state, firstBlockId)?.kind ?? ResolvedBlockKind.main;

  return ApplyAttrsToRangePlan(segments: segments, kind: kind);
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

List<InlineItem> _applyAttrsToBlockRange(
  List<InlineItem> items,
  int start,
  int end,
  ReadonlyAttrs newAttrs,
  Map<String, AttrEqualsFn>? customEquals,
) {
  if (start == end) return items;

  int cursor = 0;
  final result = <InlineItem>[];

  for (final item in items) {
    final itemLen = item is TextItem ? item.text.length : 1;
    final itemEnd = cursor + itemLen;

    if (itemEnd <= start) {
      result.add(item);
      cursor = itemEnd;
      continue;
    }
    if (cursor >= end) {
      result.add(item);
      cursor = itemEnd;
      continue;
    }

    final merged = mergeAttrs(item.attrs, newAttrs);

    if (item is EmbedItem) {
      final embedType = item.properties['embedType'];
      // Structural markers don't receive inline formatting.
      if (embedType == 'comment-start' ||
          embedType == 'comment-end' ||
          embedType == 'block-join-suggestion' ||
          embedType == 'split-suggestion') {
        result.add(item);
      } else {
        if (!attrsEqual(item.attrs, merged, customEquals: customEquals)) {
          result.add(EmbedItem(
            embedType: item.embedType,
            properties: item.properties,
            attrs: merged,
          ));
        } else {
          result.add(item);
        }
      }
      cursor = itemEnd;
      continue;
    }

    if (item is TextItem) {
      final localStart = max(0, start - cursor);
      final localEnd = min(itemLen, end - cursor);

      if (localStart == 0 && localEnd == itemLen) {
        if (!attrsEqual(item.attrs, merged, customEquals: customEquals)) {
          result.add(TextItem(text: item.text, attrs: merged));
        } else {
          result.add(item);
        }
        cursor = itemEnd;
        continue;
      }

      final text = item.text;
      final before = text.substring(0, localStart);
      final middle = text.substring(localStart, localEnd);
      final after = text.substring(localEnd);

      if (before.isNotEmpty) {
        result.add(TextItem(text: before, attrs: item.attrs));
      }
      result.add(TextItem(text: middle, attrs: merged));
      if (after.isNotEmpty) {
        result.add(TextItem(text: after, attrs: item.attrs));
      }
      cursor = itemEnd;
    }
  }

  return result;
}
