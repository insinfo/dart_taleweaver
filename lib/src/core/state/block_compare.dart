/// Compare blocks in document order.
///
/// Port of `block-compare.ts`.
library;

import 'block_id.dart';
import 'block_position.dart';
import 'block_traversal.dart';
import 'state.dart';

/// Compare two blocks in document order.
/// Returns negative if a is before b, positive if a is after b, zero if equal.
int compareBlocksInDocOrder(State state, BlockId idA, BlockId idB) {
  if (idA == idB) return 0;

  final chainA = ancestorChain(state, idA);
  final chainB = ancestorChain(state, idB);

  if (chainA.isEmpty)
    throw StateError('compareBlocksInDocOrder: block "$idA" not found');
  if (chainB.isEmpty)
    throw StateError('compareBlocksInDocOrder: block "$idB" not found');

  final rootA = chainA.last;
  final rootB = chainB.last;
  if (rootA != rootB) {
    throw StateError(
        'compareBlocksInDocOrder: blocks "$idA" and "$idB" have no common ancestor');
  }

  int i = chainA.length - 1;
  int j = chainB.length - 1;

  while (i >= 0 && j >= 0 && chainA[i] == chainB[j]) {
    i--;
    j--;
  }

  if (i < 0) return -1;
  if (j < 0) return 1;

  final lcaId = chainA[i + 1];
  final lca = resolveBlock(state, lcaId)?.block;
  if (lca == null)
    throw StateError('compareBlocksInDocOrder: LCA "$lcaId" not found');

  var cursor = lca.firstChildId;
  while (cursor != null) {
    if (cursor == chainA[i]) return -1;
    if (cursor == chainB[j]) return 1;
    final block = resolveBlock(state, cursor)?.block;
    cursor = block?.nextSiblingId;
  }

  throw StateError(
      'compareBlocksInDocOrder: branches not found in LCA "$lcaId" children');
}

/// Compare two positions in document order.
int comparePositions(State state, Position a, Position b) {
  if (a.blockId == b.blockId) return a.offset - b.offset;
  return compareBlocksInDocOrder(state, a.blockId, b.blockId);
}

/// Return the earlier position of a Span in document order.
Position spanStart(State state, Span span) {
  return comparePositions(state, span.anchor, span.focus) <= 0
      ? span.anchor
      : span.focus;
}

/// Return the later position of a Span in document order.
Position spanEnd(State state, Span span) {
  return comparePositions(state, span.anchor, span.focus) <= 0
      ? span.focus
      : span.anchor;
}

/// Return the id of the selection-context root for the given block.
BlockId? selectionContextOf(State state, BlockId blockId) {
  var cursor = resolveBlock(state, blockId)?.block;
  if (cursor == null) return null;

  final maxSteps = blockCount(state) + 1;
  int steps = 0;
  while (cursor!.parentId != null) {
    if (++steps > maxSteps) {
      throw StateError('selectionContextOf: cycle detected');
    }
    final parent = resolveBlock(state, cursor.parentId!)?.block;
    if (parent == null) break;
    cursor = parent;
  }
  return cursor.id;
}
