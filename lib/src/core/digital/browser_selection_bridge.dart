/// Browser-backed selection bridge for a rendered Taleweaver document.
///
/// The model keeps UTF-16 offsets on leaf blocks, while the browser exposes
/// node/child-index points.  This adapter is deliberately separate from the
/// serializable helpers in `selection_bridge.dart`: hosts that do not use the
/// DOM can keep using those helpers without importing browser APIs.
library;

import 'package:web/web.dart' as web;

import '../state/block_id.dart';
import '../state/block_position.dart';

typedef BlockElementLookup = web.HTMLElement? Function(BlockId blockId);

/// Converts DOM selections inside [root] to Taleweaver positions and back.
///
/// Inline embeds count as one document unit regardless of the text used to
/// paint their label. Generated list markers and empty-line `<br>` fillers are
/// deliberately zero-width in the model.
class BrowserSelectionBridge {
  final web.HTMLElement root;
  final web.Window window;
  final BlockElementLookup? _blockElementLookup;

  BrowserSelectionBridge(
    this.root, {
    web.Window? window,
    BlockElementLookup? blockElementLookup,
  })  : window = window ?? web.window,
        _blockElementLookup = blockElementLookup;

  Position? domToPosition(web.Node node, int nodeOffset) {
    final block = _enclosingBlock(node);
    if (block == null || !root.contains(block)) return null;
    final rawId = block.getAttribute('data-block-id');
    if (rawId == null || rawId.isEmpty) return null;
    final offset = _accumulateToNode(block, node, nodeOffset);
    if (offset == null) return null;
    return Position(blockId: BlockId(rawId), offset: offset);
  }

  Selection? readDomSelection() {
    final selection = window.getSelection();
    final anchorNode = selection?.anchorNode;
    final focusNode = selection?.focusNode;
    if (anchorNode == null || focusNode == null) return null;
    if (!root.contains(anchorNode) || !root.contains(focusNode)) return null;
    final anchor = domToPosition(anchorNode, selection!.anchorOffset);
    final focus = domToPosition(focusNode, selection.focusOffset);
    if (anchor == null || focus == null) return null;
    return Selection(anchor: anchor, focus: focus);
  }

  /// Restores [selection] through the browser's directional selection API.
  ///
  /// It is intentionally a no-op during transient structural reconciliations
  /// when one of the referenced block elements is not mounted yet.
  void positionToDom(Selection selection) {
    final anchorBlock = _findBlock(selection.anchor.blockId);
    final focusBlock = _findBlock(selection.focus.blockId);
    if (anchorBlock == null || focusBlock == null) return;
    final anchor = _locateOffset(anchorBlock, selection.anchor.offset);
    final focus = _locateOffset(focusBlock, selection.focus.offset);
    final domSelection = window.getSelection();
    if (domSelection == null) return;
    domSelection.setBaseAndExtent(
        anchor.node, anchor.offset, focus.node, focus.offset);
  }

  web.HTMLElement? _findBlock(BlockId id) {
    final lookedUp = _blockElementLookup?.call(id);
    if (lookedUp != null) return lookedUp;
    if (root.getAttribute('data-block-id') == id.value) return root;
    final candidates = root.querySelectorAll('[data-block-id]');
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates.item(index);
      // `package:web` interop types are erased at runtime; querySelectorAll
      // guarantees elements, so use the DOM guarantee rather than `is`.
      if (candidate != null) {
        final element = candidate as web.HTMLElement;
        if (element.getAttribute('data-block-id') == id.value) {
          return element;
        }
      }
    }
    return null;
  }
}

web.HTMLElement? _enclosingBlock(web.Node node) {
  web.Node? current =
      node.nodeType == web.Node.TEXT_NODE ? node.parentNode : node;
  while (current != null) {
    final element = _asElement(current);
    if (element != null && element.hasAttribute('data-block-id')) {
      return element as web.HTMLElement;
    }
    current = current.parentNode;
  }
  return null;
}

web.Element? _asElement(web.Node node) =>
    node.nodeType == web.Node.ELEMENT_NODE ? node as web.Element : null;

bool _isInlineEmbed(web.Node node) =>
    _asElement(node)?.hasAttribute('data-inline-embed') ?? false;

bool _isListMarker(web.Node node) =>
    _asElement(node)?.hasAttribute('data-tw-marker') ?? false;

bool _isEmptyLineFiller(web.Node node) =>
    _asElement(node)?.localName == 'br' &&
    (_asElement(node)?.hasAttribute('data-tw-empty-line') ?? false);

int _textLength(web.Node node) => node.textContent?.length ?? 0;

int _measure(web.Node node) {
  if (node.nodeType == web.Node.TEXT_NODE) return _textLength(node);
  if (_isInlineEmbed(node)) return 1;
  if (_isListMarker(node)) return 0;
  var result = 0;
  for (var index = 0; index < node.childNodes.length; index++) {
    final child = node.childNodes.item(index);
    if (child != null) result += _measure(child);
  }
  return result;
}

int? _accumulateToNode(
    web.HTMLElement block, web.Node target, int targetOffset) {
  var accumulated = 0;
  int? found;

  void visit(web.Node node) {
    if (found != null || _isListMarker(node)) return;
    if (node.isSameNode(target)) {
      if (node.nodeType == web.Node.TEXT_NODE) {
        found = accumulated + targetOffset.clamp(0, _textLength(node));
      } else if (_isInlineEmbed(node)) {
        found = accumulated + targetOffset.clamp(0, 1);
      } else {
        var local = 0;
        final childLimit = targetOffset.clamp(0, node.childNodes.length);
        for (var index = 0; index < childLimit; index++) {
          final child = node.childNodes.item(index);
          if (child != null) local += _measure(child);
        }
        found = accumulated + local;
      }
      return;
    }
    if (node.nodeType == web.Node.TEXT_NODE) {
      accumulated += _textLength(node);
      return;
    }
    if (_isInlineEmbed(node)) {
      accumulated++;
      return;
    }
    for (var index = 0; index < node.childNodes.length; index++) {
      final child = node.childNodes.item(index);
      if (child != null) visit(child);
    }
  }

  visit(block);
  return found;
}

({web.Node node, int offset}) _locateOffset(
    web.HTMLElement block, int requestedOffset) {
  var remaining = requestedOffset < 0 ? 0 : requestedOffset;
  ({web.Node node, int offset})? result;

  bool visit(web.Node node, web.Node parent, int indexInParent) {
    if (result != null || _isListMarker(node)) return result != null;
    if (node.nodeType == web.Node.TEXT_NODE) {
      final length = _textLength(node);
      if (remaining <= length) {
        result = (node: node, offset: remaining);
        return true;
      }
      remaining -= length;
      return false;
    }
    if (_isInlineEmbed(node)) {
      if (remaining == 0) {
        result = (node: parent, offset: indexInParent);
        return true;
      }
      if (remaining == 1) {
        result = (node: parent, offset: indexInParent + 1);
        return true;
      }
      remaining--;
      return false;
    }
    for (var index = 0; index < node.childNodes.length; index++) {
      final child = node.childNodes.item(index);
      if (child != null && visit(child, node, index)) return true;
    }
    return false;
  }

  for (var index = 0; index < block.childNodes.length; index++) {
    final child = block.childNodes.item(index);
    if (child != null && visit(child, block, index)) break;
  }
  if (result != null) return result!;

  final contentChildren = <web.Node>[];
  for (var index = 0; index < block.childNodes.length; index++) {
    final child = block.childNodes.item(index);
    if (child != null && !_isListMarker(child)) contentChildren.add(child);
  }
  if (contentChildren.length == 1 &&
      _isEmptyLineFiller(contentChildren.first)) {
    return (node: block, offset: 0);
  }
  return (node: block, offset: block.childNodes.length);
}
