library;

import '../editor/editor_action.dart';

EditorAction? mapDigitalKey(
    {required String key,
    bool ctrl = false,
    bool meta = false,
    bool mac = false,
    bool shift = false,
    bool inListItem = false}) {
  final command = mac ? meta : ctrl;
  if (key == 'Escape') return const EscapeAction();
  // Ctrl/Cmd+Enter is a document command, not a browser text edit.  Handle it
  // before the ordinary Enter fast-path below so the browser never inserts an
  // extra DOM paragraph alongside the model's manual page boundary.
  if (key == 'Enter' && command) return const PageBreakAction();
  if (key == 'Tab') {
    if (!inListItem) return shift ? null : const InsertTabAction();
    return shift ? const ListOutdentAction() : const ListIndentAction();
  }
  // Editing keys are owned by the browser's beforeinput stream. Returning
  // null here preserves the digital/layout boundary and avoids double edits.
  if (key == 'Backspace' || key == 'Delete' || key == 'Enter') return null;
  if (!command) return null;
  switch (key.toLowerCase()) {
    case 'z':
      return shift ? const RedoAction() : const UndoAction();
    case 'y':
      return const RedoAction();
    case 'b':
      return const ToggleStyleAction('bold');
    case 'i':
      return const ToggleStyleAction('italic');
    case 'u':
      return const ToggleStyleAction('underline');
    case 'x':
      return shift ? const ToggleStyleAction('strikethrough') : null;
    case 'a':
      return const SelectAllAction();
    case '\\':
      return const ClearFormattingAction();
  }
  return null;
}
