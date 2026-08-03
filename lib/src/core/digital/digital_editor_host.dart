/// Browser DOM host for the framework-independent digital editor controller.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
import '../editor/editor_action.dart';
import '../editor/editor_state.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/extract_text.dart';
import '../state/state.dart';
import 'browser_selection_bridge.dart';
import 'digital_editor_host_config.dart';
import 'dom_browser_reconciler.dart';
import 'editor_controller.dart';
import 'map_before_input.dart';

/// Mounts a browser-flowed, DOM-backed Taleweaver editing surface.
///
/// The host deliberately owns only the contenteditable surface and its input
/// pipeline. Toolbars, ribbons, page views, rulers, and application styling
/// remain outside this class, so it can be embedded by any web framework.
class DigitalEditorHost {
  /// Parent supplied by the embedding application.
  final web.HTMLElement container;

  /// The real contenteditable element created under [container].
  final web.HTMLElement surface;

  /// Controller that owns all document mutations and history.
  final DigitalEditorController controller;

  /// Browser configuration selected at mount time.
  final DigitalEditorHostConfig config;

  /// Document that owns [surface] and emits `selectionchange`.
  final web.Document document;

  /// Window that owns the browser Selection API.
  final web.Window window;

  final DigitalDomReconciler _reconciler;
  final Map<BlockId, web.HTMLElement> _blockElements = {};
  final List<_DigitalDomListener> _listeners = [];

  late final BrowserSelectionBridge _selectionBridge;
  late final EditorStateListener _controllerListener;

  bool _destroyed = false;
  bool _readOnly = false;
  bool _pendingDropBeforeInput = false;
  late final bool _mac;
  Selection? _lastSelectionNotification;
  late int _lastDocumentRevision;

  DigitalEditorHost._({
    required this.container,
    required this.surface,
    required this.controller,
    required this.config,
    required this.document,
    required this.window,
    required DigitalDomReconciler reconciler,
    required bool mac,
  })  : _reconciler = reconciler,
        _mac = mac,
        _readOnly = config.readOnly {
    _mount();
  }

  /// Creates and mounts a DOM surface below [container].
  ///
  /// Passing an existing [controller] lets an application share the document,
  /// undo history, or collaboration wiring it already owns. Otherwise a
  /// controller is created from [config]. The explicit [document] parameter is
  /// useful for an iframe or test document and takes precedence over config.
  static DigitalEditorHost mount(
    web.HTMLElement container, {
    DigitalEditorHostConfig config = const DigitalEditorHostConfig(),
    DigitalEditorController? controller,
    web.Document? document,
  }) {
    if (controller != null && config.initialEditorState != null) {
      throw ArgumentError(
          'controller e config.initialEditorState não podem ser usados juntos.');
    }
    final ownerDocument =
        document ?? config.document ?? container.ownerDocument ?? web.document;
    final ownerWindow =
        config.window ?? ownerDocument.defaultView ?? web.window;
    final mac = config.mac ?? _isMacPlatform(ownerWindow);
    final components = config.componentRegistry ??
        config.editorConfig.componentRegistry ??
        controller?.config.componentRegistry ??
        createDefaultComponentRegistry();
    final attrs = config.attrRegistry ?? createDefaultAttrRegistry();
    final editorConfig = _editorConfigFor(config.editorConfig, components);
    final effectiveController = controller ??
        DigitalEditorController(
          initial: config.initialEditorState ??
              createInitialEditorState(config: editorConfig),
          mac: mac,
          config: editorConfig,
        );
    final surface = ownerDocument.createElement('div') as web.HTMLElement;
    final reconciler = DigitalDomReconciler(
      host: surface,
      document: ownerDocument,
      components: components,
      attrs: attrs,
      suggestionView: config.suggestionView,
      templateBodyId: config.templateBodyId,
      templatePageNumber: config.templatePageNumber,
      templatePageCount: config.templatePageCount,
    );
    return DigitalEditorHost._(
      container: container,
      surface: surface,
      controller: effectiveController,
      config: config,
      document: ownerDocument,
      window: ownerWindow,
      reconciler: reconciler,
      mac: config.mac ?? effectiveController.mac,
    );
  }

  /// Current editor state. This is the same object exposed by [controller].
  EditorState get editorState => controller.editor;

  /// The selection bridge backed by the currently reconciled block elements.
  BrowserSelectionBridge get selectionBridge => _selectionBridge;

  /// The renderer-owned root below [surface].
  ///
  /// Browser-only presentation layers may place inert siblings before this
  /// node (for example physical-page decorations) without becoming part of
  /// the keyed document reconciliation contract.
  web.Element? get renderRoot => _reconciler.root;

  /// Returns the currently mounted DOM element for a model block.
  ///
  /// This is observational: callers must never mutate the returned keyed
  /// element.  Browser presentation layers use it to locate the physical page
  /// containing the editor's selection without rescanning or inventing an
  /// independent DOM-to-model mapping.
  web.HTMLElement? blockElement(BlockId blockId) => _blockElements[blockId];

  /// Whether this host has been destroyed.
  bool get isDestroyed => _destroyed;

  /// Whether user-originated edits are disabled.
  bool get readOnly => _readOnly;

  /// Alias retained for integrations that use the all-lowercase spelling.
  bool get readonly => readOnly;

  /// Dispatches a programmatic editor action and returns the resulting state.
  ///
  /// Read-only mode blocks browser-originated editing only; programmatic
  /// dispatch remains available for controlled/document-viewer integrations.
  EditorState dispatch(EditorAction action) {
    if (_destroyed) return controller.editor;
    return controller.dispatch(action);
  }

  /// Focuses the contenteditable surface and restores its model selection.
  void focus() {
    if (_destroyed) return;
    surface.focus();
    restoreSelection();
  }

  /// Restores [editorState]'s potentially multi-block, directional selection.
  void restoreSelection() {
    if (_destroyed || controller.isComposing) return;
    _selectionBridge.positionToDom(controller.editor.selection);
  }

  /// Changes whether browser input is accepted without remounting the editor.
  void setReadOnly(bool value) {
    if (_destroyed || _readOnly == value) return;
    _readOnly = value;
    _applyEditability();
  }

  /// Alias for [setReadOnly].
  void setReadonly(bool value) => setReadOnly(value);

  /// Updates concrete PAGE/NUMPAGES values when this host renders a template.
  /// The call is display-only and does not dispatch an editor action.
  void setTemplatePageValues(int pageNumber, int pageCount) {
    if (_destroyed) return;
    _reconciler.setTemplatePageValues(pageNumber, pageCount);
  }

  /// Removes listeners, the reconciled DOM tree, and the generated surface.
  ///
  /// It is intentionally idempotent. A controller passed into [mount] is not
  /// destroyed because it may be shared by its embedding application.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;

    for (final listener in _listeners) {
      listener.target.removeEventListener(listener.type, listener.callback);
    }
    _listeners.clear();
    controller.removeListener(_controllerListener);
    _reconciler.destroy();
    _blockElements.clear();
    surface.contentEditable = 'false';
    surface.setAttribute('aria-readonly', 'true');
    config.onDestroy?.call(surface);
    if (surface.parentNode == container) {
      container.removeChild(surface);
    }
  }

  void _mount() {
    _configureSurface();
    container.appendChild(surface);
    _reconciler.mount(controller.editor.state);
    _indexBlockElements();
    _selectionBridge = BrowserSelectionBridge(
      surface,
      window: window,
      blockElementLookup: (id) => _blockElements[id],
    );
    _lastSelectionNotification = controller.editor.selection;
    _lastDocumentRevision = controller.editor.state.doc.revision;
    _controllerListener = _onControllerState;
    controller.addListener(_controllerListener);
    _installListeners();
    restoreSelection();
    config.onMount?.call(surface);
  }

  void _configureSurface() {
    surface.setAttribute('data-tw-digital-surface', '');
    surface.setAttribute('role', 'textbox');
    surface.setAttribute('aria-multiline', 'true');
    surface.tabIndex = config.tabIndex;
    if (config.surfaceClassName != null) {
      surface.setAttribute('class', config.surfaceClassName!);
    }
    if (config.ariaLabel != null) {
      surface.setAttribute('aria-label', config.ariaLabel!);
    }
    for (final entry in config.surfaceAttributes.entries) {
      if (_hostOwnedAttributes.contains(entry.key.toLowerCase())) continue;
      surface.setAttribute(entry.key, entry.value);
    }
    _applyEditability();
  }

  void _applyEditability() {
    surface.contentEditable = _readOnly ? 'false' : 'true';
    surface.setAttribute('aria-readonly', _readOnly ? 'true' : 'false');
  }

  void _installListeners() {
    _listen(surface, 'beforeinput', _onBeforeInput);
    _listen(surface, 'keydown', _onKeyDown);
    _listen(surface, 'compositionstart', _onCompositionStart);
    _listen(surface, 'compositionend', _onCompositionEnd);
    _listen(surface, 'compositioncancel', _onCompositionCancel);
    _listen(surface, 'copy', _onCopy);
    _listen(surface, 'cut', _onCut);
    _listen(surface, 'paste', _onPaste);
    _listen(surface, 'drop', _onDrop);
    _listen(surface, 'focus', _onFocus);
    _listen(surface, 'blur', _onBlur);
    _listen(document, 'selectionchange', _onSelectionChange);
  }

  void _listen(
      web.EventTarget target, String type, void Function(web.Event) handler) {
    final callback = handler.toJS;
    target.addEventListener(type, callback);
    _listeners.add(_DigitalDomListener(target, type, callback));
  }

  void _onControllerState(EditorState state) {
    if (_destroyed) return;
    final revision = state.state.doc.revision;
    final documentChanged = revision != _lastDocumentRevision;
    _lastDocumentRevision = revision;
    if (documentChanged) {
      _reconciler.reconcile(state.state);
      _indexBlockElements();
    }
    restoreSelection();

    final previousSelection = _lastSelectionNotification;
    if (previousSelection == null ||
        !selectionsEqual(previousSelection, state.selection)) {
      _lastSelectionNotification = state.selection;
      config.onSelectionChange?.call(state.selection);
    }
    if (documentChanged) config.onChange?.call(state);
    config.onStateChange?.call(state);
  }

  void _onBeforeInput(web.Event event) {
    if (_destroyed) return;
    final input = event as web.InputEvent;
    config.onBeforeInput?.call(input);
    if (input.defaultPrevented) return;
    if (_readOnly) {
      input.preventDefault();
      return;
    }

    // The clipboard handler is the single paste source. A browser drop is
    // normally handled by `drop`; its paired beforeinput is suppressed below,
    // while a standalone `insertFromDrop` remains a useful browser fallback.
    if (input.inputType == 'insertFromPaste' ||
        input.inputType == 'deleteByCut') {
      input.preventDefault();
      return;
    }
    if (input.inputType == 'insertFromDrop' && _pendingDropBeforeInput) {
      _pendingDropBeforeInput = false;
      input.preventDefault();
      return;
    }

    if (controller.isComposing && input.inputType != 'insertCompositionText') {
      return;
    }

    // Capture these while the browser's original nodes are still mounted.
    final domSelection = _selectionBridge.readDomSelection();
    final targetRanges = _targetRanges(input);
    _syncSelection(domSelection);

    final action = controller.beforeInput(DigitalInputEvent(
      inputType: input.inputType,
      data: input.data,
      dataTransferText: _plainText(input.dataTransfer),
      // `deleteByCut`/`deleteByDrag` is specified to use the live selection;
      // other commands prefer their target range when one is supplied.
      selection: input.inputType == 'deleteByDrag'
          ? controller.editor.selection
          : null,
      targetRanges: targetRanges,
    ));
    if (action != null) input.preventDefault();
  }

  void _onKeyDown(web.Event event) {
    if (_destroyed) return;
    final key = event as web.KeyboardEvent;
    config.onKeyDown?.call(key);
    if (key.defaultPrevented) return;
    if (_readOnly) return;

    _syncSelection(_selectionBridge.readDomSelection());
    final focusBlock = resolveBlock(
            controller.editor.state, controller.editor.selection.focus.blockId)
        ?.block;
    final action = controller.key(
      key: key.key,
      ctrl: key.ctrlKey,
      meta: key.metaKey,
      mac: _mac,
      shift: key.shiftKey,
      inListItem: focusBlock?.type == 'list-item',
    );
    if (action == null) return;
    key.preventDefault();
  }

  void _onCompositionStart(web.Event event) {
    if (_destroyed) return;
    final composition = event as web.CompositionEvent;
    config.onCompositionStart?.call(composition);
    if (_readOnly || composition.defaultPrevented) return;
    controller.compositionStart();
  }

  void _onCompositionEnd(web.Event event) {
    if (_destroyed) return;
    final composition = event as web.CompositionEvent;
    config.onCompositionEnd?.call(composition);
    if (_readOnly || composition.defaultPrevented) {
      controller.compositionCancel();
      return;
    }
    _syncSelection(_selectionBridge.readDomSelection());
    controller.compositionEnd(composition.data);
  }

  void _onCompositionCancel(web.Event _) {
    if (_destroyed) return;
    controller.compositionCancel();
  }

  void _onSelectionChange(web.Event _) {
    if (_destroyed || controller.isComposing) return;
    _syncSelection(_selectionBridge.readDomSelection());
  }

  void _onCopy(web.Event event) {
    if (_destroyed) return;
    final copy = event as web.ClipboardEvent;
    config.onCopy?.call(copy);
    if (copy.defaultPrevented) return;
    copy.preventDefault();
    final selection = _selectionBridge.readDomSelection();
    _syncSelection(selection);
    final text = extractText(
      controller.editor.state,
      controller.editor.selection,
      builtinEmbedSerializer,
      config.suggestionView,
    );
    copy.clipboardData?.setData('text/plain', text);
  }

  void _onCut(web.Event event) {
    if (_destroyed) return;
    final cut = event as web.ClipboardEvent;
    config.onCut?.call(cut);
    if (cut.defaultPrevented) return;
    cut.preventDefault();
    final selection = _selectionBridge.readDomSelection();
    _syncSelection(selection);
    final activeSelection = controller.editor.selection;
    final text = extractText(
      controller.editor.state,
      activeSelection,
      builtinEmbedSerializer,
      config.suggestionView,
    );
    cut.clipboardData?.setData('text/plain', text);
    if (!_readOnly) controller.dispatch(DeleteRangeAction(activeSelection));
  }

  void _onPaste(web.Event event) {
    if (_destroyed) return;
    final paste = event as web.ClipboardEvent;
    config.onPaste?.call(paste);
    if (paste.defaultPrevented) return;
    paste.preventDefault();
    if (_readOnly) return;
    _syncSelection(_selectionBridge.readDomSelection());
    final text = _plainText(paste.clipboardData);
    if (text.isNotEmpty) controller.dispatch(PasteTextAction(text));
  }

  void _onDrop(web.Event event) {
    if (_destroyed) return;
    final drop = event as web.DragEvent;
    config.onDrop?.call(drop);
    if (drop.defaultPrevented) return;
    drop.preventDefault();
    _pendingDropBeforeInput = true;
    if (_readOnly) return;
    _syncSelection(_selectionBridge.readDomSelection());
    final text = _plainText(drop.dataTransfer);
    if (text.isNotEmpty) controller.dispatch(PasteTextAction(text));
  }

  void _onFocus(web.Event _) {
    if (!_destroyed) config.onFocus?.call(surface);
  }

  void _onBlur(web.Event _) {
    if (!_destroyed) config.onBlur?.call(surface);
  }

  void _syncSelection(Selection? selection) {
    if (selection == null ||
        selectionsEqual(selection, controller.editor.selection)) {
      return;
    }
    controller.dispatch(SetSelectionAction(selection));
  }

  List<Selection> _targetRanges(web.InputEvent input) {
    try {
      final result = <Selection>[];
      for (final range in input.getTargetRanges().toDart) {
        final start = _selectionBridge.domToPosition(
            range.startContainer, range.startOffset);
        final end =
            _selectionBridge.domToPosition(range.endContainer, range.endOffset);
        if (start != null && end != null) {
          result.add(Selection(anchor: start, focus: end));
        }
      }
      return result;
    } catch (_) {
      // Older/synthetic browser events can omit getTargetRanges. The mapper
      // has a safe fallback for commands without an explicit range.
      return const [];
    }
  }

  void _indexBlockElements() {
    _blockElements.clear();
    final root = _reconciler.root;
    if (root is web.HTMLElement) _indexBlockElement(root);
    final candidates = surface.querySelectorAll('[data-block-id]');
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates.item(index);
      if (candidate is web.HTMLElement) _indexBlockElement(candidate);
    }
  }

  void _indexBlockElement(web.HTMLElement element) {
    final rawId = element.getAttribute('data-block-id');
    if (rawId == null || rawId.isEmpty) return;
    _blockElements[BlockId(rawId)] = element;
  }
}

const Set<String> _hostOwnedAttributes = {
  'contenteditable',
  'role',
  'aria-multiline',
  'aria-readonly',
  'tabindex',
};

class _DigitalDomListener {
  final web.EventTarget target;
  final String type;
  final JSFunction callback;

  const _DigitalDomListener(this.target, this.type, this.callback);
}

EditorConfig _editorConfigFor(
    EditorConfig source, ComponentRegistry componentRegistry) {
  return EditorConfig(
    containerWidth: source.containerWidth,
    now: source.now,
    suggestingAuthor: source.suggestingAuthor,
    componentRegistry: source.componentRegistry ?? componentRegistry,
    pageConfig: source.pageConfig,
  );
}

bool _isMacPlatform(web.Window window) {
  return RegExp(r'Mac|iPhone|iPad', caseSensitive: false)
      .hasMatch(window.navigator.userAgent);
}

String _plainText(web.DataTransfer? transfer) {
  if (transfer == null) return '';
  try {
    return transfer.getData('text/plain');
  } catch (_) {
    // Synthetic events may expose no functional DataTransfer object.
    return '';
  }
}
