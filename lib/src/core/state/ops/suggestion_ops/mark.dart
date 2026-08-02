/// Suggestion mark operations.
library;

import '../../attrs.dart';

import '../../block_id.dart';
import '../../block_position.dart';
import '../../inline_content.dart';
import '../../state.dart';
import '../../suggestions.dart';
import '../../tw_doc.dart';
// yMapAsObject etc if needed? Wait, I will need some y-utils in dart.

import '../apply_attrs.dart';
import 'utils.dart';

OperationResult markFormatting(
  State state,
  Span span,
  ReadonlyAttrs proposedAttrs,
  SuggestionMintInput input,
) {
  if (proposedAttrs.isEmpty) {
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

  final decision = resolveCoalesce(
    state,
    span,
    input.id,
    formattingSuggestionAttr,
    (record) =>
        record.kind == 'formatting' &&
        record.author == input.author &&
        attrsEqual(record.proposedAttrs ?? {}, proposedAttrs),
  );

  return applyOperation(state, (doc) {
    applyAttrsToRangeInTx(
        doc, plan, {formattingSuggestionAttr: decision.id.value},
        customEquals: null);
    if (!decision.reusing) {
      writeSuggestionRecordInTx(
          doc,
          SuggestionRecord(
            id: decision.id,
            kind: 'formatting',
            author: input.author,
            createdAt: input.createdAt,
            proposedAttrs: proposedAttrs,
          ));
    }
  });
}

class DeletionRebuild {
  final List<InlineItem> items;
  final bool tagged;

  const DeletionRebuild({required this.items, required this.tagged});
}

class MarkDeletionPlan {
  final List<ResolveWrite> writes;
  final bool taggedAny;
  final SuggestionId id;
  final bool reusing;
  final ResolvedBlockKind kind;

  const MarkDeletionPlan({
    required this.writes,
    required this.taggedAny,
    required this.id,
    required this.reusing,
    required this.kind,
  });
}

class ResolveWrite {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;
  final int rangeStart;
  final int rangeEnd;
  final SuggestionId? deletionId;
  final bool appendJoinEmbed;

  const ResolveWrite({
    required this.blockId,
    required this.kind,
    required this.items,
    required this.rangeStart,
    required this.rangeEnd,
    required this.deletionId,
    required this.appendJoinEmbed,
  });
}

OperationResult markDeletion(State state, Span span, SuggestionMintInput input,
    [Map<String, AttrEqualsFn>? customEquals]) {
  final plan = planMarkDeletion(state, span, input);
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }

  return applyOperation(state, (d) {
    for (final write in plan.writes) {
      applyDeletionStrikeInTx(
        d,
        write.blockId,
        plan.kind,
        write.rangeStart,
        write.rangeEnd,
        plan.id,
        input.author,
        customEquals,
        'markDeletion',
      );
    }

    if (plan.taggedAny && !plan.reusing) {
      writeSuggestionRecordInTx(
          d,
          SuggestionRecord(
            id: plan.id,
            kind: 'deletion',
            author: input.author,
            createdAt: input.createdAt,
          ));
    }
  });
}

MarkDeletionPlan? planMarkDeletion(
  State state,
  Span span,
  SuggestionMintInput input,
) {
  if (span.anchor.blockId == span.focus.blockId &&
      span.anchor.offset == span.focus.offset) {
    return null;
  }

  final plan = planApplyAttrsToRange(state, span);
  if (plan == null) {
    return null;
  }

  final decision = resolveCoalesce(
    state,
    span,
    input.id,
    deletionSuggestionAttr,
    (record) => record.kind == 'deletion' && record.author == input.author,
  );

  final doc = state.doc;
  final writes = <ResolveWrite>[];
  var taggedAny = false;

  for (final seg in plan.segments) {
    if (seg.rangeStart >= seg.rangeEnd) continue;
    final content = seg.block.inlineContent;
    if (content == null) continue;

    final result = rebuildBlockForDeletion(
      content.items,
      seg.rangeStart,
      seg.rangeEnd,
      decision.id,
      input.author,
      doc,
    );
    if (result.tagged) taggedAny = true;
    writes.add(ResolveWrite(
      blockId: seg.block.id,
      kind: plan.kind,
      items: mergeAdjacentTextItems(result.items),
      rangeStart: seg.rangeStart,
      rangeEnd: seg.rangeEnd,
      deletionId: decision.id,
      appendJoinEmbed: false, // only used in fragment-replace
    ));
  }

  return MarkDeletionPlan(
    writes: writes,
    taggedAny: taggedAny,
    id: decision.id,
    reusing: decision.reusing,
    kind: plan.kind,
  );
}

DeletionRebuild rebuildBlockForDeletion(
  List<InlineItem> items,
  int rangeStart,
  int rangeEnd,
  SuggestionId id,
  String author,
  TwDoc doc,
) {
  final out = <InlineItem>[];
  var tagged = false;
  var cursor = 0;

  for (final item in items) {
    final len = item is TextItem ? item.text.length : 1;
    final itemStart = cursor;
    final itemEnd = cursor + len;
    cursor = itemEnd;

    if (itemEnd <= rangeStart || itemStart >= rangeEnd) {
      out.add(item);
      continue;
    }

    if (item is! TextItem) {
      out.add(item);
      continue;
    }

    final localStart = (rangeStart - itemStart).clamp(0, len);
    final localEnd = (rangeEnd - itemStart).clamp(0, len);
    final before = item.text.substring(0, localStart);
    final middle = item.text.substring(localStart, localEnd);
    final after = item.text.substring(localEnd);

    if (before.isNotEmpty) {
      out.add(TextItem(text: before, attrs: item.attrs));
    }

    if (isOwnInsertion(item, author, doc)) {
      // omit
    } else {
      out.add(TextItem(
        text: middle,
        attrs: {...item.attrs, deletionSuggestionAttr: id.value},
      ));
      tagged = true;
    }

    if (after.isNotEmpty) {
      out.add(TextItem(text: after, attrs: item.attrs));
    }
  }
  return DeletionRebuild(items: out, tagged: tagged);
}

bool isOwnInsertionAttrs(
  ReadonlyAttrs attrs,
  String author,
  TwDoc doc,
) {
  final raw = attrs[insertionSuggestionAttr];
  if (raw is! String) return false;
  final record = readSuggestionRecord(doc, SuggestionId(raw));
  return record != null &&
      record.kind == 'insertion' &&
      record.author == author;
}

bool isOwnInsertion(InlineItem item, String author, TwDoc doc) {
  if (item is! TextItem) return false;
  return isOwnInsertionAttrs(item.attrs, author, doc);
}

bool applyDeletionStrikeInTx(
  TwDoc doc,
  BlockId blockId,
  ResolvedBlockKind kind,
  int rangeStart,
  int rangeEnd,
  SuggestionId id,
  String author,
  Map<String, AttrEqualsFn>? customEquals,
  String opName,
) {
  final yBlock = kind == ResolvedBlockKind.embed
      ? doc.getEmbedContentMap(blockId.value)
      : (kind == ResolvedBlockKind.template
          ? doc.getTemplateContentMap(blockId.value)
          : doc.getBlockMap(blockId.value));
  if (yBlock == null) return false;
  final content = yBlock['inlineContent'];
  if (content is! InlineContent) return false;

  final yItems = List<InlineItem>.from(content.items);
  final tagged =
      _strikeBlockRange(yItems, rangeStart, rangeEnd, id, author, doc);

  yBlock['inlineContent'] =
      InlineContent(mergeAdjacentSameAttrsTextItems(yItems, customEquals));
  doc.markDirty(blockId.value);
  return tagged;
}

bool _strikeBlockRange(
  List<InlineItem> yItems,
  int start,
  int end,
  SuggestionId id,
  String author,
  TwDoc doc,
) {
  if (start == end) return false;
  var tagged = false;
  var cursor = 0;
  var i = 0;

  while (i < yItems.length) {
    final yItem = yItems[i];
    final itemLen = yItem is TextItem ? yItem.text.length : 1;
    final itemEnd = cursor + itemLen;

    if (itemEnd <= start) {
      cursor = itemEnd;
      i++;
      continue;
    }
    if (cursor >= end) break;
    if (yItem is! TextItem) {
      cursor = itemEnd;
      i++;
      continue;
    }

    final existing = yItem.attrs;
    final ownIns = isOwnInsertionAttrs(existing, author, doc);
    final localStart = (start - cursor).clamp(0, itemLen);
    final localEnd = (end - cursor).clamp(0, itemLen);

    if (localStart == 0 && localEnd == itemLen) {
      if (ownIns) {
        yItems.removeAt(i);
        cursor = itemEnd;
      } else {
        if (existing[deletionSuggestionAttr] != id.value) {
          yItems[i] = TextItem(
              text: yItem.text,
              attrs: {...existing, deletionSuggestionAttr: id.value});
        }
        tagged = true;
        cursor = itemEnd;
        i++;
      }
      continue;
    }

    final text = yItem.text;
    final before = text.substring(0, localStart);
    final middle = text.substring(localStart, localEnd);
    final after = text.substring(localEnd);
    final repl = <InlineItem>[];

    if (before.isNotEmpty) {
      repl.add(TextItem(text: before, attrs: existing));
    }
    if (!ownIns) {
      repl.add(TextItem(
          text: middle,
          attrs: {...existing, deletionSuggestionAttr: id.value}));
      tagged = true;
    }
    if (after.isNotEmpty) {
      repl.add(TextItem(text: after, attrs: existing));
    }

    yItems.removeAt(i);
    yItems.insertAll(i, repl);
    i += repl.length;
    cursor = itemEnd;
  }
  return tagged;
}

List<InlineItem> mergeAdjacentSameAttrsTextItems(List<InlineItem> items,
    [Map<String, AttrEqualsFn>? customEquals]) {
  // simple version since dart doesn't have Yjs CRDT in-place mutation needs
  final out = <InlineItem>[];
  for (final item in items) {
    if (out.isNotEmpty && out.last is TextItem && item is TextItem) {
      final prev = out.last as TextItem;
      if (attrsEqual(prev.attrs, item.attrs, customEquals: customEquals)) {
        out.removeLast();
        out.add(TextItem(text: prev.text + item.text, attrs: prev.attrs));
        continue;
      }
    }
    out.add(item);
  }
  return out;
}

bool attrsEqualWithRegistry(
    ReadonlyAttrs a, ReadonlyAttrs b, Map<String, AttrEqualsFn>? customEquals) {
  if (customEquals != null) {
    // Ideally use registry.equals, but fallback to attrsEqual
  }
  return attrsEqual(a, b);
}
