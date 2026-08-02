library;

import '../state/block_kinds.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/state.dart';

BlockId? objectSelection(
    State state, Selection selection, BlockKindResolver resolver) {
  if (!isCollapsed(selection) || selection.focus.offset != 0) return null;
  final block = resolveBlock(state, selection.focus.blockId)?.block;
  if (block == null || resolver.getBlockKind(block.type) != Kind.atomicLeaf)
    return null;
  return block.id;
}
