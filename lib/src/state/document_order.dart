/// Document-order comparison and span utilities.
///
/// Port of `document-order.ts` and `block-compare.ts`.
library;

import 'block.dart';
import 'block_id.dart';
import 'block_position.dart';
import 'block_traversal.dart';
import 'inline_content.dart';
import 'state.dart';

// ---------------------------------------------------------------------------
// Block ordering
// ---------------------------------------------------------------------------

/// Compare two blocks by their position in document order.
///
/// Returns negative if [aId] comes before [bId], zero if same, positive
/// if [aId] comes after [bId].
///
/// This walks the ancestor chains of both blocks to find the common
/// ancestor, then compares sibling order at the divergence point.
int compareBlocksInDocOrder(State state, BlockId aId, BlockId bId) {
  if (aId == bId) return 0;

  final aBlock = getBlock(state, aId);
  final bBlock = getBlock(state, bId);
  if (aBlock == null || bBlock == null) {
    throw StateError(
      'compareBlocksInDocOrder: one or both blocks not found ($aId, $bId)',
    );
  }

  // Build ancestor chains (block → root).
  final aChain = ancestorChain(state, aBlock);
  final bChain = ancestorChain(state, bBlock);

  // Walk from root down to find divergence.
  var ai = aChain.length - 1;
  var bi = bChain.length - 1;

  // Roots must be the same for blocks in the same tree.
  if (aChain[ai].id != bChain[bi].id) {
    // Different trees — compare tree roots arbitrarily.
    return aChain[ai].id.value.compareTo(bChain[bi].id.value);
  }

  // Walk down from root until chains diverge.
  while (ai > 0 && bi > 0 && aChain[ai - 1].id == bChain[bi - 1].id) {
    ai--;
    bi--;
  }

  // If one chain is exhausted, it's an ancestor of the other.
  if (ai == 0) return -1; // a is ancestor of b → a comes first
  if (bi == 0) return 1; // b is ancestor of a → b comes first

  // Compare siblings at the divergence point.
  final aSibling = aChain[ai - 1];
  final bSibling = bChain[bi - 1];

  // Walk forward from aSibling to see if we reach bSibling.
  Block? cursor = aSibling;
  while (cursor != null) {
    if (cursor.id == bSibling.id) return -1; // a comes before b
    cursor = cursor.nextSiblingId != null
        ? getBlock(state, cursor.nextSiblingId!)
        : null;
  }

  return 1; // a comes after b
}

/// Compare two positions in the document.
///
/// If positions are in the same block, compares by offset.
/// Otherwise, compares by document order of their blocks.
int comparePositions(State state, Position a, Position b) {
  if (a.blockId == b.blockId) {
    return a.offset - b.offset;
  }
  return compareBlocksInDocOrder(state, a.blockId, b.blockId);
}

// ---------------------------------------------------------------------------
// Span utilities
// ---------------------------------------------------------------------------

/// Return the document-order start position of a span.
Position spanStart(State state, Span span) {
  final cmp = comparePositions(state, span.anchor, span.focus);
  return cmp <= 0 ? span.anchor : span.focus;
}

/// Return the document-order end position of a span.
Position spanEnd(State state, Span span) {
  final cmp = comparePositions(state, span.anchor, span.focus);
  return cmp <= 0 ? span.focus : span.anchor;
}

/// Normalize a span so anchor ≤ focus in document order.
Span normalizeSpan(State state, Span span) {
  final cmp = comparePositions(state, span.anchor, span.focus);
  if (cmp <= 0) return span;
  return Span(anchor: span.focus, focus: span.anchor);
}

/// Determine the "selection context" of a position — which tree it belongs to.
///
/// Returns the root block ID of the tree containing the position's block.
BlockId selectionContextOf(State state, Position pos) {
  final block = getBlock(state, pos.blockId);
  if (block == null) {
    throw StateError('selectionContextOf: block ${pos.blockId} not found');
  }
  // Walk up to root.
  var current = block;
  while (current.parentId != null) {
    final parent = getBlock(state, current.parentId!);
    if (parent == null) break;
    current = parent;
  }
  return current.id;
}

// ---------------------------------------------------------------------------
// Span iteration
// ---------------------------------------------------------------------------

/// Iterate over all leaf blocks touched by a span, yielding each block
/// with the start and end offsets within that block.
///
/// The span must be normalized (anchor ≤ focus in document order).
Iterable<SpanBlockSlice> iterateBlocksInSpan(
  State state,
  Span span,
) sync* {
  final norm = normalizeSpan(state, span);
  final startPos = norm.anchor;
  final endPos = norm.focus;

  if (startPos.blockId == endPos.blockId) {
    // Single-block span.
    yield SpanBlockSlice(
      blockId: startPos.blockId,
      startOffset: startPos.offset,
      endOffset: endPos.offset,
    );
    return;
  }

  // Multi-block span.
  // First block: from startOffset to end.
  final firstBlock = getBlock(state, startPos.blockId);
  if (firstBlock != null && firstBlock.isLeaf) {
    yield SpanBlockSlice(
      blockId: startPos.blockId,
      startOffset: startPos.offset,
      endOffset: firstBlock.inlineContent != null
          ? inlineContentLength(firstBlock.inlineContent!)
          : 0,
    );
  }

  // Middle blocks: full content.
  var current = firstBlock;
  if (current != null) {
    current = nextBlockInDocOrder(state, current);
  }
  while (current != null && current.id != endPos.blockId) {
    if (current.isLeaf) {
      yield SpanBlockSlice(
        blockId: current.id,
        startOffset: 0,
        endOffset: current.inlineContent != null
            ? inlineContentLength(current.inlineContent!)
            : 0,
      );
    }
    current = nextBlockInDocOrder(state, current);
  }

  // Last block: from start to endOffset.
  if (current != null && current.id == endPos.blockId && current.isLeaf) {
    yield SpanBlockSlice(
      blockId: endPos.blockId,
      startOffset: 0,
      endOffset: endPos.offset,
    );
  }
}

/// A slice of a block's inline content that a span covers.
class SpanBlockSlice {
  final BlockId blockId;
  final int startOffset;
  final int endOffset;

  const SpanBlockSlice({
    required this.blockId,
    required this.startOffset,
    required this.endOffset,
  });

  /// Whether this slice covers the entire block's content.
  bool get isFullBlock => startOffset == 0;
}
