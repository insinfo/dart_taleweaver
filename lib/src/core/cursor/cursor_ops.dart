library;

import '../state/block_position.dart';
import '../state/block_id.dart';
import '../state/inline_content.dart';
import '../state/state.dart';
import '../state/block_traversal.dart';
import 'grapheme_utils.dart';

BlockId? _nextContentBlock(State state, BlockId id) {
  var next = getBlock(state, id);
  while (next != null) {
    next = nextBlockInDocOrder(state, next);
    if (next?.inlineContent != null) return next?.id;
  }
  return null;
}

BlockId? _prevContentBlock(State state, BlockId id) {
  var previous = getBlock(state, id);
  while (previous != null) {
    previous = prevBlockInDocOrder(state, previous);
    if (previous?.inlineContent != null) return previous?.id;
  }
  return null;
}

int _advanceForward(InlineContent content, int offset, {required bool word}) {
  final located = findItemAtOffset(content, offset);
  if (located.itemIndex >= content.items.length) return offset;
  final item = content.items[located.itemIndex];
  if (item is! TextItem) return offset + 1;
  final boundary = word
      ? nextWordBoundary(item.text, located.withinItem)
      : nextGraphemeBoundary(item.text, located.withinItem);
  return offset +
      (boundary > located.withinItem ? boundary - located.withinItem : 1);
}

int _advanceBackward(InlineContent content, int offset, {required bool word}) {
  final located = findItemAtOffset(content, offset);
  if (located.withinItem > 0 && located.itemIndex < content.items.length) {
    final item = content.items[located.itemIndex];
    if (item is TextItem) {
      final boundary = word
          ? prevWordBoundary(item.text, located.withinItem)
          : prevGraphemeBoundary(item.text, located.withinItem);
      return offset - (located.withinItem - boundary);
    }
    return offset - 1;
  }
  if (located.itemIndex == 0) return offset;
  final previous = content.items[located.itemIndex - 1];
  if (previous is! TextItem) return offset - 1;
  final boundary = word
      ? prevWordBoundary(previous.text, previous.text.length)
      : prevGraphemeBoundary(previous.text, previous.text.length);
  return offset - (previous.text.length - boundary);
}

Position moveByCharacter(State state, Position position, String direction) {
  final block = resolveBlock(state, position.blockId)?.block;
  if (block == null) return position;
  final content = block.inlineContent ?? InlineContent.empty;
  final total = inlineContentLength(content);
  if (direction == 'forward') {
    if (position.offset >= total) {
      final next = _nextContentBlock(state, position.blockId);
      return next == null ? position : Position(blockId: next, offset: 0);
    }
    return Position(
      blockId: position.blockId,
      offset: _advanceForward(content, position.offset, word: false),
    );
  }
  if (position.offset <= 0) {
    final previous = _prevContentBlock(state, position.blockId);
    if (previous == null) return position;
    final previousBlock = getBlock(state, previous)!;
    return Position(
      blockId: previous,
      offset: inlineContentLength(
          previousBlock.inlineContent ?? InlineContent.empty),
    );
  }
  return Position(
    blockId: position.blockId,
    offset: _advanceBackward(content, position.offset, word: false),
  );
}

Position moveByWord(State state, Position position, String direction) {
  final block = resolveBlock(state, position.blockId)?.block;
  if (block == null) return position;
  final content = block.inlineContent ?? InlineContent.empty;
  final total = inlineContentLength(content);
  if (direction == 'forward') {
    if (position.offset >= total) {
      final next = _nextContentBlock(state, position.blockId);
      return next == null ? position : Position(blockId: next, offset: 0);
    }
    return Position(
      blockId: position.blockId,
      offset: _advanceForward(content, position.offset, word: true),
    );
  }
  if (position.offset <= 0) {
    final previous = _prevContentBlock(state, position.blockId);
    if (previous == null) return position;
    final previousBlock = getBlock(state, previous)!;
    final previousContent = previousBlock.inlineContent ?? InlineContent.empty;
    var start = 0;
    for (final item in previousContent.items) {
      if (item is TextItem)
        start = start + prevWordBoundary(item.text, item.text.length);
    }
    return Position(blockId: previous, offset: start);
  }
  return Position(
    blockId: position.blockId,
    offset: _advanceBackward(content, position.offset, word: true),
  );
}

Span selectWord(State state, Position position) {
  final block = resolveBlock(state, position.blockId)?.block;
  if (block == null || block.inlineContent == null)
    return Span(anchor: position, focus: position);
  final content = block.inlineContent!;
  final located = findItemAtOffset(content, position.offset);
  if (located.itemIndex >= content.items.length ||
      content.items[located.itemIndex] is! TextItem) {
    return Span(anchor: position, focus: position);
  }
  final item = content.items[located.itemIndex] as TextItem;
  var itemStart = 0;
  for (var i = 0; i < located.itemIndex; i++) {
    itemStart += content.items[i] is TextItem
        ? (content.items[i] as TextItem).text.length
        : 1;
  }
  ({int start, int end})? word;
  ({int start, int end})? previous;
  ({int start, int end})? next;
  for (final segment in iterateWordSegments(item.text)) {
    if (!segment.isWordLike) continue;
    if (segment.start <= located.withinItem &&
        segment.end >= located.withinItem) {
      word = (start: segment.start, end: segment.end);
      break;
    }
    if (segment.end <= located.withinItem)
      previous = (start: segment.start, end: segment.end);
    if (segment.start > located.withinItem && next == null)
      next = (start: segment.start, end: segment.end);
  }
  word ??= previous ?? next;
  if (word == null) return Span(anchor: position, focus: position);
  return Span(
    anchor: Position(blockId: position.blockId, offset: itemStart + word.start),
    focus: Position(blockId: position.blockId, offset: itemStart + word.end),
  );
}

Span expandSelection(State state, Span span, String direction) => Span(
      anchor: span.anchor,
      focus: moveByCharacter(state, span.focus, direction),
    );
