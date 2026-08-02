import 'package:test/test.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/state.dart';

void main() {
  test('editor reducer inserts text and records selection', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('hello'));
    expect(editor.selection.anchor.offset, 5);
    expect(editor.history.canUndo, isTrue);
    editor = reduceEditor(editor, const UndoAction());
    expect(editor.selection.anchor.offset, 0);
  });

  test('editor reducer expands a word and deletes a range', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('one two'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 1),
      )),
    );
    editor = reduceEditor(editor, const ExpandWordAction('forward'));
    expect(editor.selection.focus.offset,
        greaterThan(editor.selection.anchor.offset));
  });
}
