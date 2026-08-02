/// Block traversal — document-order navigation across the block tree.
///
/// Port of `block-traversal.ts`.
library;

import 'block.dart';
import 'block_id.dart';
import 'state.dart';

/// Next block in document order (depth-first pre-order).
///
/// 1. If current has children → first child.
/// 2. Else if current has a next sibling → next sibling.
/// 3. Else walk up to the nearest ancestor that has a next sibling.
///
/// Returns null at end of document.
Block? nextBlockInDocOrder(State state, Block block) {
  // 1. First child
  if (block.firstChildId != null) {
    return getBlock(state, block.firstChildId!);
  }

  // 2. Next sibling or ancestor's next sibling
  Block? current = block;
  while (current != null) {
    if (current.nextSiblingId != null) {
      return getBlock(state, current.nextSiblingId!);
    }
    if (current.parentId != null) {
      current = getBlock(state, current.parentId!);
    } else {
      current = null;
    }
  }

  return null;
}

/// Previous block in document order (reverse depth-first pre-order).
///
/// 1. If current has a prev sibling → last descendant of that sibling.
/// 2. Else → parent.
///
/// Returns null at start of document.
Block? prevBlockInDocOrder(State state, Block block) {
  // 1. Previous sibling → last descendant
  if (block.prevSiblingId != null) {
    var prev = getBlock(state, block.prevSiblingId!);
    if (prev == null) return null;
    // Walk to the last descendant.
    while (prev!.lastChildId != null) {
      prev = getBlock(state, prev.lastChildId!);
      if (prev == null) break;
    }
    return prev;
  }

  // 2. Parent
  if (block.parentId != null) {
    return getBlock(state, block.parentId!);
  }

  return null;
}

/// Walk from [block] up to the root, collecting ancestor blocks.
///
/// Returns the chain from [block] (index 0) to the root (last index).
/// The [block] itself is included.
List<Block> ancestorChain(State state, Block block) {
  final chain = <Block>[block];
  var current = block;
  while (current.parentId != null) {
    final parent = getBlock(state, current.parentId!);
    if (parent == null) break;
    chain.add(parent);
    current = parent;
  }
  return chain;
}

/// The first leaf block in the subtree rooted at [block].
Block firstLeafBlock(State state, Block block) {
  var current = block;
  while (current.firstChildId != null) {
    final child = getBlock(state, current.firstChildId!);
    if (child == null) break;
    current = child;
  }
  return current;
}

/// The last leaf block in the subtree rooted at [block].
Block lastLeafBlock(State state, Block block) {
  var current = block;
  while (current.lastChildId != null) {
    final child = getBlock(state, current.lastChildId!);
    if (child == null) break;
    current = child;
  }
  return current;
}

/// Next leaf block after [block] in document order.
Block? nextLeafBlock(State state, Block block) {
  var next = nextBlockInDocOrder(state, block);
  while (next != null && !next.isLeaf) {
    next = nextBlockInDocOrder(state, next);
  }
  return next;
}

/// Previous leaf block before [block] in document order.
Block? prevLeafBlock(State state, Block block) {
  var prev = prevBlockInDocOrder(state, block);
  while (prev != null && !prev.isLeaf) {
    prev = prevBlockInDocOrder(state, prev);
  }
  return prev;
}

/// Iterate over all blocks in the document tree in document order.
Iterable<Block> iterateBlocksInDocumentOrder(State state,
    [BlockId? rootId]) sync* {
  rootId ??= state.rootId;
  final root = getBlock(state, rootId);
  if (root == null) return;

  var current = root;
  while (true) {
    yield current;
    final next = nextBlockInDocOrder(state, current);
    if (next == null) break;
    current = next;
  }
}

/// Iterate over all leaf blocks in the document tree in document order.
Iterable<Block> iterateLeafBlocksInDocumentOrder(State state,
    [BlockId? rootId]) sync* {
  rootId ??= state.rootId;
  final root = getBlock(state, rootId);
  if (root == null) return;

  var current = root.isLeaf ? root : firstLeafBlock(state, root);
  while (true) {
    yield current;
    final next = nextLeafBlock(state, current);
    if (next == null) break;
    current = next;
  }
}
