library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
import '../state/block_id.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import 'render_to_dom.dart';
import 'dom_reconciler.dart';

/// Browser-facing DOM adapter for mounting and reconciling a rendered state.
class DigitalDomReconciler {
  final web.Element host;
  final web.Document document;
  final ComponentRegistry components;
  final AttrRegistry attrs;

  /// When supplied, this reconciler renders one header/footer template body
  /// instead of the main document tree.
  final BlockId? templateBodyId;
  int templatePageNumber;
  int templatePageCount;
  SuggestionView suggestionView;
  web.Element? _root;
  State? _state;
  web.ResizeObserver? _tabLayoutResizeObserver;
  int? _tabLayoutFrame;

  DigitalDomReconciler({
    required this.host,
    required this.document,
    required this.components,
    required this.attrs,
    this.suggestionView = SuggestionView.suggesting,
    this.templateBodyId,
    this.templatePageNumber = 1,
    this.templatePageCount = 1,
  });

  web.Element? get root => _root;
  State? get state => _state;

  /// Re-renders a template projection with concrete PAGE/NUMPAGES values.
  ///
  /// Template hosts share the controller with the document host, so changing
  /// these display-only values must not dispatch a document transaction or
  /// alter undo history.
  void setTemplatePageValues(int pageNumber, int pageCount) {
    final normalizedPage = pageNumber < 1 ? 1 : pageNumber;
    final normalizedCount = pageCount < 1 ? 1 : pageCount;
    if (templateBodyId == null ||
        (templatePageNumber == normalizedPage &&
            templatePageCount == normalizedCount)) {
      return;
    }
    templatePageNumber = normalizedPage;
    templatePageCount = normalizedCount;
    final current = _state;
    if (current != null) reconcile(current);
  }

  void mount(State state) {
    destroy();
    final next = _render(state);
    host.appendChild(next);
    _root = next;
    _state = state;
    _layoutTabsNow();
    _installTabLayoutResizeObserver();
    _scheduleTabLayout();
  }

  void reconcile(State state) {
    if (_root == null) {
      mount(state);
      return;
    }
    final next = _render(state);
    final current = _root!;
    if (!_reconcileElement(current, next)) {
      host.replaceChild(next, current);
      _root = next;
    }
    _state = state;
    _layoutTabsNow();
    _scheduleTabLayout();
  }

  void destroy() {
    final frame = _tabLayoutFrame;
    if (frame != null) web.window.cancelAnimationFrame(frame);
    _tabLayoutFrame = null;
    _tabLayoutResizeObserver?.disconnect();
    _tabLayoutResizeObserver = null;
    final current = _root;
    if (current != null && current.parentNode != null) {
      current.parentNode!.removeChild(current);
    }
    _root = null;
    _state = null;
  }

  /// Tab stops need a mounted line box to resolve their advance.  Running once
  /// immediately covers ordinary edits; a second frame accounts for a newly
  /// attached host, font metrics and browser reflow.  Only style/data
  /// attributes on existing inline tab atoms are touched.
  void _layoutTabsNow() {
    final root = _root;
    if (root == null) return;
    layoutTabStopsInDom(root, window: document.defaultView);
  }

  void _scheduleTabLayout() {
    if (_tabLayoutFrame != null) return;
    _tabLayoutFrame = web.window.requestAnimationFrame(((double _) {
      _tabLayoutFrame = null;
      _layoutTabsNow();
    }).toJS);
  }

  void _installTabLayoutResizeObserver() {
    if (_tabLayoutResizeObserver != null) return;
    _tabLayoutResizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver _) {
        if (entries.length > 0) _scheduleTabLayout();
      }).toJS,
    )..observe(host);
  }

  web.Element _render(State state) {
    final template = templateBodyId;
    if (template != null) {
      return renderTemplateBodyToDom(
        state,
        template,
        components,
        attrs,
        document,
        suggestionView: suggestionView,
        pageNumber: templatePageNumber,
        pageCount: templatePageCount,
      );
    }
    return renderDocumentToDom(state, components, attrs, document,
        suggestionView: suggestionView);
  }
}

/// Reconciles a rendered subtree while retaining keyed block elements.
///
/// The fresh tree is still produced off-DOM (which keeps rendering pure), but
/// elements stamped with `data-block-id` are moved into the existing tree and
/// recursively patched instead of being discarded. This preserves browser
/// selection/focus and gives the digital backend a real fine-grained update
/// path. Non-keyed children are reconciled by node position so inline marker
/// and text subtrees are not needlessly destroyed.
bool _reconcileElement(web.Element current, web.Element fresh) {
  if (current.localName != fresh.localName) return false;
  // Copy the externally visible attributes used by the renderer.
  for (var i = 0; i < fresh.attributes.length; i++) {
    final attr = fresh.attributes.item(i);
    if (attr != null) current.setAttribute(attr.name, attr.value);
  }
  final freshAttributeNames = <String>{};
  for (var i = 0; i < fresh.attributes.length; i++) {
    final attr = fresh.attributes.item(i);
    if (attr != null) freshAttributeNames.add(attr.name);
  }
  final currentAttributeNames = <String>[];
  for (var i = 0; i < current.attributes.length; i++) {
    final attr = current.attributes.item(i);
    if (attr != null) currentAttributeNames.add(attr.name);
  }
  for (final key in currentAttributeNames) {
    if (!freshAttributeNames.contains(key)) current.removeAttribute(key);
  }

  final freshNodes = _childNodes(fresh);
  final currentNodes = _childNodes(current);
  final keyed = <String, web.Element>{};
  for (final node in currentNodes) {
    if (!_isDomElement(node)) continue;
    final element = node as web.Element;
    final key = element.getAttribute('data-block-id');
    if (key != null && key.isNotEmpty) keyed[key] = element;
  }
  final hasKeys = freshNodes.any((node) =>
      _isDomElement(node) &&
      ((node as web.Element).getAttribute('data-block-id') ?? '').isNotEmpty);
  if (!hasKeys) {
    _reconcileUnkeyedChildren(current, fresh);
    return true;
  }

  final desired = <web.Node>[];
  for (var i = 0; i < freshNodes.length; i++) {
    final next = freshNodes[i];
    if (_isDomElement(next)) {
      final nextElement = next as web.Element;
      final key = nextElement.getAttribute('data-block-id');
      final keyedOld = key == null ? null : keyed[key];
      if (keyedOld != null && _reconcileElement(keyedOld, nextElement)) {
        desired.add(keyedOld);
        continue;
      }
      final positional = i < currentNodes.length ? currentNodes[i] : null;
      if (key == null &&
          positional != null &&
          _isDomElement(positional) &&
          _reconcileElement(positional as web.Element, nextElement)) {
        desired.add(positional);
        continue;
      }
    } else if (i < currentNodes.length) {
      final positional = currentNodes[i];
      if (positional.nodeType == web.Node.TEXT_NODE &&
          next.nodeType == web.Node.TEXT_NODE) {
        if (positional.nodeValue != next.nodeValue) {
          positional.nodeValue = next.nodeValue;
        }
        desired.add(positional);
        continue;
      }
    }
    desired.add(next);
  }
  while (current.firstChild != null) {
    current.removeChild(current.firstChild!);
  }
  for (final child in desired) current.appendChild(child);
  return true;
}

List<web.Node> _childNodes(web.Element element) {
  final nodes = <web.Node>[];
  for (var i = 0; i < element.childNodes.length; i++) {
    final node = element.childNodes.item(i);
    if (node != null) nodes.add(node);
  }
  return nodes;
}

void _reconcileUnkeyedChildren(web.Element current, web.Element fresh) {
  final freshNodes = <web.Node>[];
  for (var i = 0; i < fresh.childNodes.length; i++) {
    final node = fresh.childNodes.item(i);
    if (node != null) freshNodes.add(node);
  }
  final currentNodes = <web.Node>[];
  for (var i = 0; i < current.childNodes.length; i++) {
    final node = current.childNodes.item(i);
    if (node != null) currentNodes.add(node);
  }
  final common = currentNodes.length < freshNodes.length
      ? currentNodes.length
      : freshNodes.length;
  for (var i = 0; i < common; i++) {
    final oldNode = currentNodes[i];
    final newNode = freshNodes[i];
    if (oldNode.nodeType == web.Node.TEXT_NODE &&
        newNode.nodeType == web.Node.TEXT_NODE) {
      if (oldNode.nodeValue != newNode.nodeValue) {
        oldNode.nodeValue = newNode.nodeValue;
      }
    } else if (_isDomElement(oldNode) && _isDomElement(newNode)) {
      final oldElement = oldNode as web.Element;
      final newElement = newNode as web.Element;
      if (!_reconcileElement(oldElement, newElement)) {
        current.replaceChild(newNode, oldNode);
      }
    } else if (oldNode.nodeType != newNode.nodeType) {
      current.replaceChild(newNode, oldNode);
    }
  }
  for (var i = currentNodes.length - 1; i >= freshNodes.length; i--) {
    current.removeChild(currentNodes[i]);
  }
  for (var i = common; i < freshNodes.length; i++) {
    current.appendChild(freshNodes[i]);
  }
}

/// `package:web` DOM interfaces are erased at runtime. Never use `is
/// web.Element` to distinguish a Text node; use the browser node type first.
bool _isDomElement(web.Node node) => node.nodeType == web.Node.ELEMENT_NODE;

/// Applies a keyed child order to a real DOM parent.
///
/// Nodes are supplied by key so the function never guesses identity from
/// position. Existing nodes are moved by `appendChild`, while removed nodes
/// are detached first; this mirrors the pure [reconcileKeys] contract.
void applyKeyedDomOrder(
  web.Element parent,
  List<String> previous,
  List<String> next,
  Map<String, web.Node> nodesByKey,
) {
  final nextKeys = next.toSet();
  for (final key in previous) {
    if (nextKeys.contains(key)) continue;
    final node = nodesByKey[key];
    if (node != null && node.parentNode == parent) {
      parent.removeChild(node);
    }
  }
  for (final key in next) {
    final node = nodesByKey[key];
    if (node != null) parent.appendChild(node);
  }
}
