/// Span iteration and normalization.
///
/// Port of `span-iteration.ts`.
library;

import 'block.dart';
import 'block_compare.dart';
import 'block_position.dart';
import 'block_traversal.dart';
import 'inline_content.dart';
import 'state.dart';

/// Normalize a span so anchor comes before focus in document order.
Span normalizeSpan(State state, Span span) {
  if (comparePositions(state, span.anchor, span.focus) <= 0) return span;
  return Span(anchor: span.focus, focus: span.anchor);
}

/// Per-leaf-block range yielded by iterateSpan.
class BlockRange {
  final Block block;
  final int rangeStart;
  final int rangeEnd;

  const BlockRange(this.block, this.rangeStart, this.rangeEnd);
}

/// Yield per-leaf-block ranges for a span in document order.
Iterable<BlockRange> iterateSpan(State state, Span span) sync* {
  final anchorBlockRaw = resolveBlock(state, span.anchor.blockId)?.block;
  final focusBlockRaw = resolveBlock(state, span.focus.blockId)?.block;

  if (anchorBlockRaw == null)
    throw StateError('iterateSpan: anchor block not found');
  if (focusBlockRaw == null)
    throw StateError('iterateSpan: focus block not found');
  if (anchorBlockRaw.inlineContent == null)
    throw StateError('iterateSpan: anchor block is a container, not a leaf');
  if (focusBlockRaw.inlineContent == null)
    throw StateError('iterateSpan: focus block is a container, not a leaf');

  final anchorCtx = selectionContextOf(state, span.anchor.blockId);
  final focusCtx = selectionContextOf(state, span.focus.blockId);
  if (anchorCtx != focusCtx) {
    throw StateError(
        'iterateSpan: anchor and focus are in different selection contexts');
  }

  final normalized = normalizeSpan(state, span);

  if (normalized.anchor.blockId == normalized.focus.blockId) {
    final block = resolveBlock(state, normalized.anchor.blockId)?.block;
    if (block == null) throw StateError('iterateSpan: block not found');
    yield BlockRange(block, normalized.anchor.offset, normalized.focus.offset);
    return;
  }

  final anchorBlock = resolveBlock(state, normalized.anchor.blockId)?.block;
  final focusBlock = resolveBlock(state, normalized.focus.blockId)?.block;
  if (anchorBlock == null) throw StateError('iterateSpan: block not found');
  if (focusBlock == null) throw StateError('iterateSpan: block not found');

  yield BlockRange(
    anchorBlock,
    normalized.anchor.offset,
    anchorBlock.inlineContent != null
        ? inlineContentLength(anchorBlock.inlineContent!)
        : 0,
  );

  final maxSteps = blockCount(state) + 1;
  int steps = 0;
  var currentId = nextBlockInDocOrder(state, normalized.anchor.blockId);
  while (currentId != null && currentId != normalized.focus.blockId) {
    if (++steps > maxSteps)
      throw StateError('iterateSpan: step bound exceeded');
    final current = resolveBlock(state, currentId)?.block;
    if (current != null && current.inlineContent != null) {
      yield BlockRange(
        current,
        0,
        inlineContentLength(current.inlineContent!),
      );
    }
    currentId = nextBlockInDocOrder(state, currentId);
  }

  if (currentId != normalized.focus.blockId) {
    throw StateError(
        'iterateSpan: walked to end of context without reaching focus block');
  }

  yield BlockRange(focusBlock, 0, normalized.focus.offset);
}

/// Yield each block (leaf or container) overlapped by the span, in document order.
Iterable<Block> iterateBlocksInSpan(State state, Span span) sync* {
  if (resolveBlock(state, span.anchor.blockId) == null) {
    throw StateError('iterateBlocksInSpan: anchor block not found');
  }
  if (resolveBlock(state, span.focus.blockId) == null) {
    throw StateError('iterateBlocksInSpan: focus block not found');
  }

  final anchorCtx = selectionContextOf(state, span.anchor.blockId);
  final focusCtx = selectionContextOf(state, span.focus.blockId);
  if (anchorCtx != focusCtx) {
    throw StateError(
        'iterateBlocksInSpan: anchor and focus are in different selection contexts');
  }

  final normalized = normalizeSpan(state, span);

  final anchorBlock = resolveBlock(state, normalized.anchor.blockId)?.block;
  if (anchorBlock == null)
    throw StateError('iterateBlocksInSpan: block not found');
  yield anchorBlock;

  if (normalized.anchor.blockId == normalized.focus.blockId) return;

  final maxSteps = blockCount(state) + 1;
  int steps = 0;
  var currentId = nextBlockInDocOrder(state, normalized.anchor.blockId);
  while (currentId != null) {
    if (++steps > maxSteps)
      throw StateError('iterateBlocksInSpan: step bound exceeded');
    final current = resolveBlock(state, currentId)?.block;
    if (current != null) yield current;
    if (currentId == normalized.focus.blockId) return;
    currentId = nextBlockInDocOrder(state, currentId);
  }

  throw StateError(
      'iterateBlocksInSpan: walked to end of context without reaching focus block');
}
