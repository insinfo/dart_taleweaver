library;

import '../editor/editor_action.dart';
import '../state/block_position.dart';

class DigitalInputEvent {
  final String inputType;
  final String? data;
  final String? dataTransferText;
  final Selection? selection;

  /// DOM `getTargetRanges()` projected into document positions. Browsers can
  /// provide multiple ranges for replacement/deletion; the editor contract
  /// consumes the first valid range when no explicit selection is supplied.
  final List<Selection> targetRanges;
  const DigitalInputEvent(
      {required this.inputType,
      this.data,
      this.dataTransferText,
      this.selection,
      this.targetRanges = const []});
}

Selection? _effectiveSelection(DigitalInputEvent event) =>
    event.selection ??
    (event.targetRanges.isEmpty ? null : event.targetRanges.first);

EditorAction? mapBeforeInput(DigitalInputEvent event) {
  switch (event.inputType) {
    case 'insertText':
      if (event.data != null) return InsertTextAction(event.data!);
      final text = event.dataTransferText;
      return text == null || text.isEmpty ? null : InsertTextAction(text);
    case 'insertFromPaste':
      // Native paste is handled by the ClipboardEvent listener; mapping it
      // here would dispatch the same insertion twice.
      return null;
    case 'insertParagraph':
    case 'insertLineBreak':
      return const SplitNodeAction();
    case 'insertCompositionText':
      return null;
    case 'insertFromDrop':
      final dropText = event.data ?? event.dataTransferText;
      return dropText == null || dropText.isEmpty
          ? null
          : PasteTextAction(dropText);
    case 'insertReplacementText':
      final selection = _effectiveSelection(event);
      return selection == null ? null : DeleteRangeAction(selection);
    case 'deleteContentBackward':
      return const DeleteBackwardAction();
    case 'deleteContentForward':
      return const DeleteForwardAction();
    case 'deleteWordBackward':
      final selection = _effectiveSelection(event);
      return selection == null
          ? const DeleteWordAction('backward')
          : DeleteRangeAction(selection);
    case 'deleteWordForward':
      final selection = _effectiveSelection(event);
      return selection == null
          ? const DeleteWordAction('forward')
          : DeleteRangeAction(selection);
    case 'deleteSoftLineBackward':
    case 'deleteHardLineBackward':
      final selection = _effectiveSelection(event);
      return selection == null
          ? const DeleteBackwardAction()
          : DeleteRangeAction(selection);
    case 'deleteSoftLineForward':
    case 'deleteHardLineForward':
      final selection = _effectiveSelection(event);
      return selection == null
          ? const DeleteForwardAction()
          : DeleteRangeAction(selection);
    case 'deleteByCut':
    case 'deleteByDrag':
      // Cut/drag are anchored to the controller's current selection. Unlike
      // word/line deletion, the TypeScript mapper deliberately ignores
      // targetRanges for these gestures.
      final selection = event.selection;
      return selection == null ? null : DeleteRangeAction(selection);
    case 'formatBold':
      return const ToggleStyleAction('bold');
    case 'formatItalic':
      return const ToggleStyleAction('italic');
    case 'formatUnderline':
      return const ToggleStyleAction('underline');
    case 'formatStrikeThrough':
      return const ToggleStyleAction('strikethrough');
    case 'historyUndo':
      return const UndoAction();
    case 'historyRedo':
      return const RedoAction();
    default:
      return null;
  }
}
