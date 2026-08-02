/// Suggestion utils.
library;

import '../../block_compare.dart';
import '../../block_id.dart';
import '../../block_position.dart';
import '../../inline_content.dart';
import '../../state.dart';
import '../../suggestions.dart';

 // if needed later

class CoalesceDecision {
  final SuggestionId id;
  final bool reusing;

  const CoalesceDecision({
    required this.id,
    required this.reusing,
  });
}

typedef CoalescePredicate = bool Function(SuggestionRecord record);

CoalesceDecision resolveCoalesce(
  State state,
  Span span,
  SuggestionId mintId,
  String attrKey,
  CoalescePredicate matches,
) {
  final start = spanStart(state, span);
  final end = spanEnd(state, span);

  final beforeId =
      _neighborSuggestionId(state, start.blockId, start.offset - 1, attrKey);
  final afterId =
      _neighborSuggestionAfter(state, end.blockId, end.offset, attrKey);

  for (final candidate in [beforeId, afterId]) {
    if (candidate != null && _coalesces(state, candidate, matches)) {
      return CoalesceDecision(id: candidate, reusing: true);
    }
  }
  return CoalesceDecision(id: mintId, reusing: false);
}

SuggestionId? _neighborSuggestionId(
  State state,
  BlockId blockId,
  int containedOffset,
  String attrKey,
) {
  if (containedOffset < 0) return null;
  final content = resolveBlock(state, blockId)?.block.inlineContent;
  if (content == null) return null;

  var cursor = 0;
  for (final item in content.items) {
    final len = item is TextItem ? item.text.length : 1;
    final itemStart = cursor;
    final itemEnd = cursor + len;

    if (containedOffset >= itemStart && containedOffset < itemEnd) {
      return _textItemSuggestionId(item, attrKey);
    }
    cursor = itemEnd;
  }
  return null;
}

SuggestionId? _neighborSuggestionAfter(
  State state,
  BlockId blockId,
  int startOffset,
  String attrKey,
) {
  final content = resolveBlock(state, blockId)?.block.inlineContent;
  if (content == null) return null;

  var cursor = 0;
  for (final item in content.items) {
    if (cursor == startOffset) {
      return _textItemSuggestionId(item, attrKey);
    }
    cursor += item is TextItem ? item.text.length : 1;
    if (cursor > startOffset) break;
  }
  return null;
}

SuggestionId? _textItemSuggestionId(InlineItem item, String attrKey) {
  if (item is! TextItem) return null;
  final raw = item.attrs[attrKey];
  return raw is String ? SuggestionId(raw) : null;
}

bool _coalesces(State state, SuggestionId id, CoalescePredicate matches) {
  final record = readSuggestionRecord(state.doc, id);
  return record != null && matches(record);
}

List<SuggestionId> suggestionIdsOnItem(InlineItem item) {
  final out = <SuggestionId>[];
  if (item is TextItem) {
    for (final key in [
      insertionSuggestionAttr,
      deletionSuggestionAttr,
      formattingSuggestionAttr,
    ]) {
      final v = item.attrs[key];
      if (v is String) out.add(SuggestionId(v));
    }
    return out;
  }

  if (item is EmbedItem) {
    if (item.embedType == blockSplitSuggestionEmbedType ||
        item.embedType == blockJoinSuggestionEmbedType) {
      final sid = item.properties['suggestionId'];
      if (sid is String) out.add(SuggestionId(sid));
    } else {
      final v = item.attrs[formattingSuggestionAttr];
      if (v is String) out.add(SuggestionId(v));
    }
  }
  return out;
}
