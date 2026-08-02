library;

import '../cursor/cursor_ops.dart';
import '../state/block_position.dart';
import '../state/block_id.dart';
import '../state/history.dart';
import '../state/ops/delete_range.dart';
import '../state/ops/insert_text.dart';
import '../state/state.dart';
import 'editor_action.dart';

class EditorConfig {
  final double containerWidth;
  const EditorConfig({this.containerWidth = 800});
}

class EditorState {
  final State state;
  final Selection selection;
  final History history;
  final Set<BlockId>? lastDirtyIds;
  final double containerWidth;

  const EditorState(
      {required this.state,
      required this.selection,
      required this.history,
      required this.containerWidth,
      this.lastDirtyIds});
}

EditorState createInitialEditorState(
    {EditorConfig config = const EditorConfig()}) {
  final state = createEmptyDocument();
  final paragraph = getBlock(state, state.rootId)!.firstChildId!;
  final selection = Selection(
    anchor: Position(blockId: paragraph, offset: 0),
    focus: Position(blockId: paragraph, offset: 0),
  );
  return EditorState(
      state: state,
      selection: selection,
      history: createHistory(state),
      containerWidth: config.containerWidth);
}

EditorState reduceEditor(EditorState editor, EditorAction action) {
  if (action is SetSelectionAction) {
    return EditorState(
        state: freshState(editor.state),
        selection: action.selection,
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is MoveWordAction) {
    return EditorState(
        state: freshState(editor.state),
        selection: Selection(
            anchor: moveByWord(
                editor.state, editor.selection.anchor, action.direction),
            focus: moveByWord(
                editor.state, editor.selection.focus, action.direction)),
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is ExpandWordAction) {
    final expanded = selectWord(editor.state, editor.selection.focus);
    return EditorState(
        state: editor.state,
        selection: action.direction == 'backward'
            ? Selection(anchor: expanded.focus, focus: expanded.anchor)
            : expanded,
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is UndoAction) {
    final result = editor.history.undo();
    if (result == null) return editor;
    return EditorState(
        state: editor.state,
        selection: result.selection ?? editor.selection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  if (action is RedoAction) {
    final result = editor.history.redo();
    if (result == null) return editor;
    return EditorState(
        state: editor.state,
        selection: result.selection ?? editor.selection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  final span = editor.selection;
  if (action is DeleteRangeAction) {
    editor.history.beginCapture(selectionBefore: span);
    final result = deleteRange(editor.state, action.span);
    editor.history.commit(
        selectionAfter:
            Selection(anchor: action.span.anchor, focus: action.span.anchor));
    return EditorState(
        state: result.state,
        selection:
            Selection(anchor: action.span.anchor, focus: action.span.anchor),
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  if (action is InsertTextAction) {
    final target = isCollapsed(span) ? span.anchor : span.start;
    editor.history.beginCapture(selectionBefore: span);
    var nextState = editor.state;
    var dirty = <BlockId>{};
    if (!isCollapsed(span)) {
      final deleted = deleteRange(nextState, span);
      nextState = deleted.state;
      dirty.addAll(deleted.dirtyIds);
    }
    final inserted = insertText(nextState, target, action.text, const {});
    dirty.addAll(inserted.dirtyIds);
    final caret = Position(
        blockId: target.blockId, offset: target.offset + action.text.length);
    final nextSelection = Selection(anchor: caret, focus: caret);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
        state: inserted.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: dirty);
  }
  if (action is DeleteBackwardAction || action is DeleteForwardAction) {
    final caret = span.focus;
    final target = action is DeleteBackwardAction
        ? moveByCharacter(editor.state, caret, 'backward')
        : moveByCharacter(editor.state, caret, 'forward');
    final range = action is DeleteBackwardAction
        ? Span(anchor: target, focus: caret)
        : Span(anchor: caret, focus: target);
    return reduceEditor(editor, DeleteRangeAction(range));
  }
  return editor;
}

extension on Span {
  Position get start => anchor.offset <= focus.offset ? anchor : focus;
}
