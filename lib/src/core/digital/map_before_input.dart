library;

import '../editor/editor_action.dart';

class DigitalInputEvent {
  final String inputType;
  final String? data;
  final String? dataTransferText;
  const DigitalInputEvent(
      {required this.inputType, this.data, this.dataTransferText});
}

EditorAction? mapBeforeInput(DigitalInputEvent event) {
  switch (event.inputType) {
    case 'insertText':
      final text = event.data ?? event.dataTransferText;
      return text == null || text.isEmpty ? null : InsertTextAction(text);
    case 'insertParagraph':
    case 'insertLineBreak':
      return const InsertTextAction('\n');
    case 'deleteContentBackward':
      return const DeleteBackwardAction();
    case 'deleteContentForward':
      return const DeleteForwardAction();
    case 'historyUndo':
      return const UndoAction();
    case 'historyRedo':
      return const RedoAction();
    default:
      return null;
  }
}
