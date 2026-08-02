library;

import '../editor/editor_action.dart';

EditorAction? mapDigitalKey(
    {required String key,
    bool ctrl = false,
    bool meta = false,
    bool shift = false}) {
  final command = ctrl || meta;
  if (command && key.toLowerCase() == 'z')
    return shift ? const RedoAction() : const UndoAction();
  if (key == 'Backspace') return const DeleteBackwardAction();
  if (key == 'Delete') return const DeleteForwardAction();
  if (key == 'Enter') return const InsertTextAction('\n');
  return null;
}
