import 'package:test/test.dart';
import 'package:taleweaver/src/core/digital/map_before_input.dart';
import 'package:taleweaver/src/core/digital/map_digital_key.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';

void main() {
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

  test('keyboard mapping handles platform undo and editing keys', () {
    expect(mapDigitalKey(key: 'z', ctrl: true), isA<UndoAction>());
    expect(mapDigitalKey(key: 'z', meta: true, shift: true), isA<RedoAction>());
    expect(mapDigitalKey(key: 'Backspace'), isA<DeleteBackwardAction>());
    expect(mapDigitalKey(key: 'Enter'), isA<InsertTextAction>());
  });
}
