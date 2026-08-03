library;

import '../editor/editor_action.dart';
import '../editor/editor_state.dart';
import '../editor/reconcile_foreign_change.dart' as foreign;
import '../state/block_id.dart';
import 'map_before_input.dart';
import 'map_digital_key.dart';

typedef EditorStateListener = void Function(EditorState state);

/// Framework-independent controller used by both the browser host and tests.
/// It is deliberately synchronous: a DOM adapter only needs to translate an
/// event, dispatch it, and mirror the resulting selection/content.
class DigitalEditorController {
  EditorState _editor;
  final bool mac;
  final EditorConfig config;
  bool _isComposing = false;
  final List<EditorStateListener> _listeners = [];

  DigitalEditorController({
    EditorState? initial,
    this.mac = false,
    this.config = const EditorConfig(),
  }) : _editor = initial ?? createInitialEditorState(config: config);

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
    final next = reduceEditor(_editor, action, config);
    if (!identical(next, _editor)) {
      _editor = next;
      for (final listener in List<EditorStateListener>.of(_listeners)) {
        listener(_editor);
      }
    }
    return _editor;
  }

  /// Replaces the controller snapshot through the ordinary listener channel.
  ///
  /// Import adapters use this instead of reaching into a mounted DOM host, so
  /// all embedded surfaces reconcile the same document and selection.
  EditorState replaceState(EditorState state) {
    if (identical(state, _editor)) return _editor;
    _editor = state;
    for (final listener in List<EditorStateListener>.of(_listeners)) {
      listener(_editor);
    }
    return _editor;
  }

  /// Adopts a remote/shared-document transaction without adding it to local
  /// undo history, then notifies mounted hosts to reconcile their DOM.
  EditorState reconcileForeignChange(Set<BlockId> dirtyIds) {
    if (dirtyIds.isEmpty) return _editor;
    _editor = foreign.reconcileForeignChange(_editor, dirtyIds);
    for (final listener in List<EditorStateListener>.of(_listeners)) {
      listener(_editor);
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
