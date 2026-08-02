import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'package:taleweaver/taleweaver.dart';

void main() {
  final host = web.document.querySelector('#app');
  if (host is! web.HTMLElement) return;
  final isMac = RegExp(r'Mac|iPhone|iPad', caseSensitive: false)
      .hasMatch(web.window.navigator.userAgent);
  final controller = DigitalEditorController(mac: isMac);
  host.textContent = '';
  host.appendChild(_buildToolbar(controller));
  host.appendChild(_buildDocument(controller));
}

web.HTMLElement _buildToolbar(DigitalEditorController controller) {
  final toolbar = web.document.createElement('div') as web.HTMLElement;
  toolbar.setAttribute('role', 'toolbar');
  toolbar.setAttribute('aria-label', 'Formatting');
  for (final label in [
    'Undo',
    'Redo',
    'Bold',
    'Italic',
    'Center',
    'Line 1.5',
    'Indent',
    'Outdent',
    'Header',
    'Footer',
    'Page #',
    'Page Count'
  ]) {
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.type = 'button';
    button.textContent = label;
    button.addEventListener(
        'click',
        ((web.Event _) {
          switch (label) {
            case 'Undo':
              controller.dispatch(const UndoAction());
            case 'Redo':
              controller.dispatch(const RedoAction());
            case 'Bold':
              controller.dispatch(const ToggleStyleAction('bold'));
            case 'Italic':
              controller.dispatch(const ToggleStyleAction('italic'));
            case 'Center':
              controller.dispatch(const SetTextAlignAction('center'));
            case 'Line 1.5':
              controller.dispatch(const SetLineSpacingAction(1.5));
            case 'Indent':
              controller.dispatch(const IndentAction());
            case 'Outdent':
              controller.dispatch(const OutdentAction());
            case 'Header':
              controller.dispatch(const InsertHeaderAction());
            case 'Footer':
              controller.dispatch(const InsertFooterAction());
            case 'Page #':
              controller.dispatch(const InsertPageNumberAction());
            case 'Page Count':
              controller.dispatch(const InsertPageCountAction());
          }
        }).toJS);
    toolbar.appendChild(button);
  }
  return toolbar;
}

web.HTMLElement _buildDocument(DigitalEditorController controller) {
  controller.dispatch(const InsertTextAction('Taleweaver Dart'));
  final state = controller.editor.state;
  final paragraphId = getBlock(state, state.rootId)!.firstChildId!;
  final wrapper = web.document.createElement('div') as web.HTMLElement;
  final reconciler = DigitalDomReconciler(
    host: wrapper,
    document: web.document,
    components: createDefaultComponentRegistry(),
    attrs: createDefaultAttrRegistry(),
  );
  reconciler.mount(state);
  final mountedParagraph = _editableParagraph(wrapper, paragraphId);
  final paragraph = mountedParagraph ??
      (web.document.createElement('div') as web.HTMLElement);
  if (mountedParagraph == null) {
    // Keep the demo usable if a custom component registry changes the
    // paragraph tag or omits the block marker.
    wrapper.appendChild(paragraph);
  }
  paragraph.setAttribute('data-block-id', paragraphId.value);
  paragraph.contentEditable = 'true';
  paragraph.setAttribute(
      'style', 'min-height: 1.5em; padding: 1rem; border: 1px solid #ccd3df;');
  final semanticHost = web.document.createElement('div') as web.HTMLElement;
  semanticHost.setAttribute('data-tw-accessibility-mirror', '');
  final mirror =
      AccessibilityDomMirror(host: semanticHost, document: web.document);
  mirror.mount(state);
  wrapper.appendChild(semanticHost);
  controller.addListener((editor) {
    reconciler.reconcile(editor.state);
    final currentParagraph =
        _editableParagraph(wrapper, paragraphId) ?? paragraph;
    currentParagraph.contentEditable = 'true';
    _restoreSelectionToDom(currentParagraph, editor.selection, paragraphId);
    mirror.reconcile(editor.state);
  });
  web.document.addEventListener(
      'selectionchange',
      ((web.Event _) {
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
      }).toJS);
  wrapper.addEventListener(
      'beforeinput',
      ((web.Event event) {
        final input = event as web.InputEvent;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        final action = controller.beforeInput(DigitalInputEvent(
          inputType: input.inputType,
          data: input.data,
          selection: controller.editor.selection,
          targetRanges: _targetRanges(input, currentParagraph, paragraphId),
        ));
        if (action != null) event.preventDefault();
      }).toJS);
  wrapper.addEventListener(
      'paste',
      ((web.Event event) {
        final paste = event as web.ClipboardEvent;
        final transfer = paste.clipboardData;
        final text = transfer?.getData('text/plain') ?? '';
        if (text.isEmpty) return;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        controller.dispatch(PasteTextAction(text));
        event.preventDefault();
      }).toJS);
  wrapper.addEventListener(
      'copy',
      ((web.Event event) {
        final copy = event as web.ClipboardEvent;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        final selection = controller.editor.selection;
        if (selection.anchor.offset == selection.focus.offset &&
            selection.anchor.blockId == selection.focus.blockId) {
          return;
        }
        final text = extractText(
            controller.editor.state, selection, builtinEmbedSerializer);
        if (text.isEmpty) return;
        copy.clipboardData?.setData('text/plain', text);
        event.preventDefault();
      }).toJS);
  wrapper.addEventListener(
      'cut',
      ((web.Event event) {
        final cut = event as web.ClipboardEvent;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        final selection = controller.editor.selection;
        if (selection.anchor.offset == selection.focus.offset &&
            selection.anchor.blockId == selection.focus.blockId) {
          return;
        }
        final text = extractText(
            controller.editor.state, selection, builtinEmbedSerializer);
        if (text.isEmpty) return;
        cut.clipboardData?.setData('text/plain', text);
        controller.dispatch(DeleteRangeAction(selection));
        event.preventDefault();
      }).toJS);
  wrapper.addEventListener(
      'drop',
      ((web.Event event) {
        final drop = event as web.DragEvent;
        final text = drop.dataTransfer?.getData('text/plain') ?? '';
        if (text.isEmpty) return;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        controller.dispatch(PasteTextAction(text));
        event.preventDefault();
      }).toJS);
  wrapper.addEventListener(
      'compositionstart',
      ((web.Event _) {
        controller.compositionStart();
      }).toJS);
  wrapper.addEventListener(
      'compositionend',
      ((web.Event event) {
        final composition = event as web.CompositionEvent;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        final action = controller.compositionEnd(composition.data);
        if (action != null) {
          _restoreSelectionToDom(
              currentParagraph, controller.editor.selection, paragraphId);
        }
      }).toJS);
  wrapper.addEventListener(
      'keydown',
      ((web.Event event) {
        final key = event as web.KeyboardEvent;
        final currentParagraph =
            _editableParagraph(wrapper, paragraphId) ?? paragraph;
        _syncSelectionFromDom(controller, currentParagraph, paragraphId);
        final action = controller.key(
          key: key.key,
          ctrl: key.ctrlKey,
          meta: key.metaKey,
          shift: key.shiftKey,
        );
        if (action != null) event.preventDefault();
      }).toJS);
  return wrapper;
}

web.HTMLElement? _editableParagraph(web.Element host, BlockId paragraphId) {
  final node = host.querySelector('[data-block-id="${paragraphId.value}"]');
  return node is web.HTMLElement ? node : null;
}

List<Selection> _targetRanges(
    web.InputEvent input, web.HTMLElement paragraph, BlockId blockId) {
  final target = input as JSObject;
  final method = 'getTargetRanges'.toJS;
  if (!target.hasProperty(method).toDart) return const [];
  final ranges = target.callMethod<JSArray<web.StaticRange>>(method);
  final length = paragraph.textContent?.length ?? 0;
  final result = <Selection>[];
  for (final range in ranges.toDart) {
    final startNode = range.startContainer;
    final endNode = range.endContainer;
    final start = _domPointOffset(paragraph, startNode, range.startOffset);
    final end = _domPointOffset(paragraph, endNode, range.endOffset);
    if (start == null || end == null) continue;
    result.add(Selection(
      anchor: Position(blockId: blockId, offset: start.clamp(0, length)),
      focus: Position(blockId: blockId, offset: end.clamp(0, length)),
    ));
  }
  return result;
}

void _syncSelectionFromDom(DigitalEditorController controller,
    web.HTMLElement paragraph, BlockId blockId) {
  final selection = web.window.getSelection();
  if (selection == null || selection.rangeCount == 0) {
    return;
  }
  final anchorNode = selection.anchorNode;
  final focusNode = selection.focusNode;
  if (anchorNode == null || focusNode == null) return;
  final length = paragraph.textContent?.length ?? 0;
  final anchor = _domPointOffset(paragraph, anchorNode, selection.anchorOffset)
      ?.clamp(0, length);
  final focus = _domPointOffset(paragraph, focusNode, selection.focusOffset)
      ?.clamp(0, length);
  if (anchor == null || focus == null) return;
  final next = Selection(
    anchor: Position(blockId: blockId, offset: anchor),
    focus: Position(blockId: blockId, offset: focus),
  );
  if (next == controller.editor.selection) return;
  controller.dispatch(SetSelectionAction(next));
}

void _restoreSelectionToDom(
    web.HTMLElement paragraph, Selection selection, BlockId blockId) {
  if (selection.anchor.blockId != blockId ||
      selection.focus.blockId != blockId) {
    return;
  }
  final length = paragraph.textContent?.length ?? 0;
  final anchor = selection.anchor.offset.clamp(0, length);
  final focus = selection.focus.offset.clamp(0, length);
  final domSelection = web.window.getSelection();
  if (domSelection == null) return;
  final anchorPoint = _textPointAtOffset(paragraph, anchor);
  final focusPoint = _textPointAtOffset(paragraph, focus);
  if (anchorPoint == null || focusPoint == null) return;
  domSelection.setBaseAndExtent(
      anchorPoint.node, anchorPoint.offset, focusPoint.node, focusPoint.offset);
}

/// Converts a DOM Selection point (which may target an element boundary or a
/// nested text node) into a literal UTF-16 offset relative to [root].
int? _domPointOffset(web.Node root, web.Node target, int localOffset) {
  int? visit(web.Node node, int base) {
    if (node.isSameNode(target)) {
      if (node.nodeType == web.Node.TEXT_NODE) {
        final length = node.textContent?.length ?? 0;
        return base + localOffset.clamp(0, length);
      }
      var offset = 0;
      final count = localOffset.clamp(0, node.childNodes.length);
      for (var i = 0; i < count; i++) {
        final child = node.childNodes.item(i);
        offset += child?.textContent?.length ?? 0;
      }
      return base + offset;
    }
    var cursor = base;
    for (var i = 0; i < node.childNodes.length; i++) {
      final child = node.childNodes.item(i);
      if (child == null) continue;
      final found = visit(child, cursor);
      if (found != null) return found;
      cursor += child.textContent?.length ?? 0;
    }
    return null;
  }

  return visit(root, 0);
}

({web.Node node, int offset})? _textPointAtOffset(
    web.Node root, int requestedOffset) {
  final target = requestedOffset < 0 ? 0 : requestedOffset;
  ({web.Node node, int offset})? visit(web.Node node, int base) {
    if (node.nodeType == web.Node.TEXT_NODE) {
      final length = node.textContent?.length ?? 0;
      if (target <= base + length) {
        return (node: node, offset: (target - base).clamp(0, length));
      }
      return null;
    }
    var cursor = base;
    for (var i = 0; i < node.childNodes.length; i++) {
      final child = node.childNodes.item(i);
      if (child == null) continue;
      final found = visit(child, cursor);
      if (found != null) return found;
      cursor += child.textContent?.length ?? 0;
    }
    return null;
  }

  final found = visit(root, 0);
  if (found != null) return found;
  final last = root.lastChild;
  if (last != null && last.nodeType == web.Node.TEXT_NODE) {
    return (node: last, offset: last.textContent?.length ?? 0);
  }
  return null;
}
