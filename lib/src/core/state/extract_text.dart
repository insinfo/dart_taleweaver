/// Extract text.
///
/// Port of `state/extract-text.ts`.
library;

import 'dart:math';

import 'block_position.dart';
import 'comments.dart';
import 'inline_content.dart';
import 'page_field.dart';
import 'span_iteration.dart';
import 'state.dart';
import 'suggestions.dart';

const String _embedChar = '￼';

typedef EmbedSerializer = String Function(EmbedItem item);

String defaultEmbedSerializer(EmbedItem item) => _embedChar;

String builtinEmbedSerializer(EmbedItem item) {
  switch (item.embedType) {
    case hardBreakEmbedType:
      return '\n';
    case 'tab':
      return '\t';
    case commentStartEmbedType:
    case commentEndEmbedType:
    case blockJoinSuggestionEmbedType:
    case blockSplitSuggestionEmbedType:
      return '';
    case pageFieldEmbedType:
      return '';
    default:
      return _embedChar;
  }
}

String captionEmbedSerializer(EmbedItem item) {
  switch (item.embedType) {
    case hardBreakEmbedType:
    case 'tab':
      return ' ';
    default:
      return '';
  }
}

String extractText(
  State state,
  Span span, [
  EmbedSerializer embedSerializer = defaultEmbedSerializer,
  SuggestionView view = SuggestionView.suggesting,
]) {
  final parts = <String>[];
  List<InlineItem>? prevItems;

  for (final iteration in iterateSpan(state, span)) {
    final block = iteration.block;
    final rangeStart = iteration.rangeStart;
    final rangeEnd = iteration.rangeEnd;

    if (prevItems != null) {
      parts.add(blockBoundaryMergesInView(prevItems, view) ? '' : '\n');
    }

    final items = block.inlineContent?.items ?? const [];
    if (block.inlineContent != null) {
      parts.add(_extractTextFromBlock(items, rangeStart, rangeEnd, embedSerializer, view));
    }
    prevItems = items;
  }

  return parts.join('');
}

String _extractTextFromBlock(
  List<InlineItem> items,
  int rangeStart,
  int rangeEnd,
  EmbedSerializer embedSerializer,
  SuggestionView view,
) {
  if (rangeStart >= rangeEnd) return '';
  final out = <String>[];
  int cursor = 0;

  for (final item in items) {
    if (cursor >= rangeEnd) break;
    
    final itemLen = item is TextItem ? item.text.length : 1;
    final itemStart = cursor;
    final itemEnd = cursor + itemLen;
    cursor = itemEnd;
    
    if (itemEnd <= rangeStart) continue;
    if (!itemVisibleInView(item, view)) continue;
    
    final subStart = max(itemStart, rangeStart) - itemStart;
    final subEnd = min(itemEnd, rangeEnd) - itemStart;
    
    if (item is TextItem) {
      out.add(item.text.substring(subStart, subEnd));
    } else if (item is EmbedItem) {
      if (subStart < 1 && subEnd > 0) {
        out.add(embedSerializer(item));
      }
    }
  }
  
  return out.join('');
}
