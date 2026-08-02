library;

import '../editor/editor_action.dart';
import '../editor/editor_state.dart';
import 'map_before_input.dart';
import 'map_digital_key.dart';

typedef EditorStateListener = void Function(EditorState state);

/// Framework-independent controller used by both the browser host and tests.
/// It is deliberately synchronous: a DOM adapter only needs to translate an
/// event, dispatch it, and mirror the resulting selection/content.
class DigitalEditorController {
  EditorState _editor;
  final bool mac;
  bool _isComposing = false;
  final List<EditorStateListener> _listeners = [];

  DigitalEditorController({EditorState? initial, this.mac = false})
      : _editor = initial ?? createInitialEditorState();

  EditorState get editor => _editor;
  bool get isComposing => _isComposing;

  void compositionStart() => _isComposing = true;

  /// Commits the IME payload exactly once at composition end. Intermediate
  /// `insertCompositionText` beforeinput events remain suppressed.
  EditorState? compositionEnd(String? data) {
    if (!_isComposing) return null;
    _isComposing = false;
    if (data == null || data.isEmpty) return null;
    return dispatch(InsertTextAction(data));
  }

  void compositionCancel() => _isComposing = false;

  void addListener(EditorStateListener listener) => _listeners.add(listener);
  void removeListener(EditorStateListener listener) =>
      _listeners.remove(listener);

  EditorState dispatch(EditorAction action) {
    final next = reduceEditor(_editor, action);
    if (!identical(next, _editor)) {
      _editor = next;
      for (final listener in List<EditorStateListener>.of(_listeners)) {
        listener(_editor);
      }
    }
    return _editor;
  }

  EditorState? beforeInput(DigitalInputEvent event) {
    final action = mapBeforeInput(event);
    if (action == null) return null;
    var result = dispatch(action);
    final replacement = event.data ?? event.dataTransferText;
    if (event.inputType == 'insertReplacementText' &&
        replacement != null &&
        replacement.isNotEmpty) {
      result = dispatch(InsertTextAction(replacement));
    }
    return result;
  }

  EditorState? key(
      {required String key,
      bool ctrl = false,
      bool meta = false,
      bool? mac,
      bool shift = false,
      bool inListItem = false}) {
    final action = mapDigitalKey(
        key: key,
        ctrl: ctrl,
        meta: meta,
        mac: mac ?? this.mac,
        shift: shift,
        inListItem: inListItem);
    return action == null ? null : dispatch(action);
  }
}
