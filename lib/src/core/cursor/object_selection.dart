library;

import '../state/block_kinds.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/state.dart';
import '../state/inline_content.dart';
import 'cursor_ops.dart';

BlockId? objectSelection(
    State state, Selection selection, BlockKindResolver resolver) {
  if (!isCollapsed(selection) || selection.focus.offset != 0) return null;
  final block = resolveBlock(state, selection.focus.blockId)?.block;
  if (block == null || resolver.getBlockKind(block.type) != Kind.atomicLeaf)
    return null;
  return block.id;
}

/// Purely moves a caret off an atomic object in document order.
Selection? moveOffObjectSelection(
    State state, BlockId objectId, String direction) {
  final target = direction == 'backward'
      ? findPrevContentBlock(state, objectId)
      : findNextContentBlock(state, objectId);
  if (target == null) return null;
  final block = getBlock(state, target);
  if (block == null) return null;
  final offset = direction == 'backward'
      ? inlineContentLength(block.inlineContent ?? InlineContent.empty)
      : 0;
  final position = Position(blockId: target, offset: offset);
  return Selection(anchor: position, focus: position);
}
