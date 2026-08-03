import 'package:test/test.dart';
import 'package:taleweaver/src/core/digital/map_before_input.dart';
import 'package:taleweaver/src/core/digital/map_digital_key.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/block_id.dart';

void main() {
  test('keyboard mapping dispatches Escape as ESCAPE', () {
    expect(mapDigitalKey(key: 'Escape'), isA<EscapeAction>());
  });

  test('beforeinput maps insertion, deletion and history events', () {
    expect(
        mapBeforeInput(
            const DigitalInputEvent(inputType: 'insertText', data: 'x')),
        isA<InsertTextAction>());
    expect(
        mapBeforeInput(const DigitalInputEvent(
            inputType: 'insertText', data: null, dataTransferText: 'paste')),
        isA<InsertTextAction>());
    expect(
        mapBeforeInput(
            const DigitalInputEvent(inputType: 'deleteContentBackward')),
        isA<DeleteBackwardAction>());
    expect(mapBeforeInput(const DigitalInputEvent(inputType: 'historyUndo')),
        isA<UndoAction>());
    expect(
        mapBeforeInput(
            const DigitalInputEvent(inputType: 'insertCompositionText')),
        isNull);
  });

  test('beforeinput maps plain-text paste separately', () {
    final action = mapBeforeInput(
        const DigitalInputEvent(inputType: 'insertFromPaste', data: 'pasted'));
    expect(action, isNull);
  });

  test('keyboard mapping handles platform undo and editing keys', () {
    expect(mapDigitalKey(key: 'z', ctrl: true), isA<UndoAction>());
    expect(mapDigitalKey(key: 'z', meta: true, mac: true, shift: true),
        isA<RedoAction>());
    expect(mapDigitalKey(key: 'z', meta: true), isNull);
    expect(mapDigitalKey(key: 'Backspace'), isNull);
    expect(mapDigitalKey(key: 'Delete'), isNull);
    expect(mapDigitalKey(key: 'Enter'), isNull);
    expect(mapDigitalKey(key: 'Enter', ctrl: true), isA<PageBreakAction>());
    expect(mapDigitalKey(key: 'Enter', meta: true, mac: true),
        isA<PageBreakAction>());
  });

  test('digital mapping covers formatting, tab context and word deletes', () {
    expect(mapDigitalKey(key: 'b', ctrl: true), isA<ToggleStyleAction>());
    expect(mapDigitalKey(key: 'Tab'), isA<InsertTabAction>());
    expect(
        mapDigitalKey(key: 'Tab', inListItem: true), isA<ListIndentAction>());
    expect(mapDigitalKey(key: 'Tab', inListItem: true, shift: true),
        isA<ListOutdentAction>());
    expect(
        mapBeforeInput(
            const DigitalInputEvent(inputType: 'deleteWordBackward')),
        isA<DeleteWordAction>());
  });

  test('beforeinput falls back to DOM target ranges', () {
    const range = Selection(
        anchor: Position(blockId: BlockId('p'), offset: 1),
        focus: Position(blockId: BlockId('p'), offset: 3));
    final action = mapBeforeInput(const DigitalInputEvent(
        inputType: 'insertReplacementText', data: 'x', targetRanges: [range]));
    expect(action, isA<DeleteRangeAction>());
    expect((action as DeleteRangeAction).span, range);
    expect(
        mapBeforeInput(const DigitalInputEvent(
            inputType: 'deleteByCut', targetRanges: [range])),
        isNull);
    expect(
        mapBeforeInput(const DigitalInputEvent(
            inputType: 'deleteByDrag', selection: range)),
        isA<DeleteRangeAction>());
    expect(
        mapBeforeInput(const DigitalInputEvent(
            inputType: 'deleteWordBackward', targetRanges: [range])),
        isA<DeleteRangeAction>());
  });

  test('replacement text can come from the data-transfer fallback', () {
    const range = Selection(
        anchor: Position(blockId: BlockId('p'), offset: 0),
        focus: Position(blockId: BlockId('p'), offset: 1));
    final action = mapBeforeInput(const DigitalInputEvent(
      inputType: 'insertReplacementText',
      dataTransferText: 'fallback',
      targetRanges: [range],
    ));
    expect(action, isA<DeleteRangeAction>());
  });
}
