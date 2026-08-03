import 'package:test/test.dart';
import 'package:taleweaver/src/core/digital/editor_controller.dart';
import 'package:taleweaver/src/core/digital/map_before_input.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/state/block_schema.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';

void main() {
  test('controller dispatches beforeinput and notifies listeners', () {
    final controller = DigitalEditorController();
    var notifications = 0;
    controller.addListener((_) => notifications++);
    controller.beforeInput(
        const DigitalInputEvent(inputType: 'insertText', data: 'hello'));
    expect(notifications, 1);
    final paragraph = controller.editor.state.rootId;
    expect(paragraph, isNotNull);
  });

  test('controller maps keyboard history and editing actions', () {
    final controller = DigitalEditorController();
    expect(controller.key(key: 'Backspace'), isNull);
    expect(controller.key(key: 'z', ctrl: true), isNotNull);
    expect(controller.key(key: 'z', meta: true, mac: true, shift: true),
        isNotNull);
  });

  test('controller applies replacement text as delete plus insertion', () {
    final controller = DigitalEditorController();
    controller.dispatch(const InsertTextAction('hello'));
    final selection = controller.editor.selection;
    controller.beforeInput(DigitalInputEvent(
      inputType: 'insertReplacementText',
      data: 'hi',
      selection: Selection(
        anchor: selection.focus,
        focus: Position(
          blockId: selection.focus.blockId,
          offset: selection.focus.offset - 2,
        ),
      ),
    ));
    expect(controller.editor.selection.focus.offset, greaterThanOrEqualTo(0));
  });

  test('controller suppresses intermediate composition and commits once', () {
    final controller = DigitalEditorController();
    controller.compositionStart();
    expect(controller.isComposing, isTrue);
    expect(
        controller.beforeInput(const DigitalInputEvent(
            inputType: 'insertCompositionText', data: 'あ')),
        isNull);
    final before = controller.editor.selection.focus.offset;
    controller.compositionEnd('あ');
    expect(controller.isComposing, isFalse);
    expect(controller.editor.selection.focus.offset, before + 1);
    expect(controller.compositionEnd('い'), isNull);
  });

  test('controller forwards EditorConfig into reducer dispatch', () {
    final controller = DigitalEditorController(
        config: const EditorConfig(suggestingAuthor: 'alice'));
    controller.dispatch(const InsertTextAction('tracked'));
    final block = getBlock(
        controller.editor.state, controller.editor.selection.focus.blockId)!;
    final item = block.inlineContent!.items.single as TextItem;
    expect(item.attrs['insertionSuggestionId'], isA<String>());
  });

  test('controller applies its configuration to a freshly created state', () {
    final controller = DigitalEditorController(
      config: const EditorConfig(containerWidth: 640),
    );

    expect(controller.editor.containerWidth, 640);
  });

  test('controller reconciles a foreign document change without local undo',
      () {
    final controller = DigitalEditorController();
    var notifications = 0;
    controller.addListener((_) => notifications++);
    final blockId = controller.editor.selection.focus.blockId;
    final remote = applyOperation(controller.editor.state, (doc) {
      doc.getBlockMap(blockId.value)![BlockFields.inlineContent] =
          const InlineContent([TextItem(text: 'texto remoto')]);
    }, origin: 'peer-a');

    controller.reconcileForeignChange(remote.dirtyIds);

    expect(notifications, 1);
    final block = getBlock(controller.editor.state, blockId)!;
    expect(
        (block.inlineContent!.items.single as TextItem).text, 'texto remoto');
    expect(controller.editor.history.canUndo, isFalse);
  });
}
