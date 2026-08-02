library;

import '../state/block_position.dart';

sealed class EditorAction {
  const EditorAction();
}

class InsertTextAction extends EditorAction {
  final String text;
  const InsertTextAction(this.text);
}

class DeleteBackwardAction extends EditorAction {
  const DeleteBackwardAction();
}

class DeleteForwardAction extends EditorAction {
  const DeleteForwardAction();
}

class SetSelectionAction extends EditorAction {
  final Selection selection;
  const SetSelectionAction(this.selection);
}

class MoveWordAction extends EditorAction {
  final String direction;
  const MoveWordAction(this.direction);
}

class ExpandWordAction extends EditorAction {
  final String direction;
  const ExpandWordAction(this.direction);
}

class DeleteRangeAction extends EditorAction {
  final Span span;
  const DeleteRangeAction(this.span);
}

class UndoAction extends EditorAction {
  const UndoAction();
}

class RedoAction extends EditorAction {
  const RedoAction();
}
