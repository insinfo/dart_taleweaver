library;

import '../state/block_id.dart';
import '../state/block_position.dart';

/// The small, serializable portion of a browser Selection needed by the
/// editor. A DOM adapter resolves its nodes to `data-block-id` before calling
/// [selectionFromDomPoints].
class DomSelectionPoint {
  final String blockId;
  final int offset;
  const DomSelectionPoint(this.blockId, this.offset);
}

Selection? selectionFromDomPoints(
    DomSelectionPoint anchor, DomSelectionPoint focus) {
  if (anchor.offset < 0 || focus.offset < 0) return null;
  return Selection(
    anchor: Position(blockId: BlockId(anchor.blockId), offset: anchor.offset),
    focus: Position(blockId: BlockId(focus.blockId), offset: focus.offset),
  );
}

({DomSelectionPoint anchor, DomSelectionPoint focus}) selectionToDomPoints(
        Selection selection) =>
    (
      anchor: DomSelectionPoint(
          selection.anchor.blockId.value, selection.anchor.offset),
      focus: DomSelectionPoint(
          selection.focus.blockId.value, selection.focus.offset),
    );
