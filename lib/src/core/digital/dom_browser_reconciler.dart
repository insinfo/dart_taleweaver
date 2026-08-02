library;

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
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
  SuggestionView suggestionView;
  web.Element? _root;
  State? _state;

  DigitalDomReconciler({
    required this.host,
    required this.document,
    required this.components,
    required this.attrs,
    this.suggestionView = SuggestionView.suggesting,
  });

  web.Element? get root => _root;
  State? get state => _state;

  void mount(State state) {
    destroy();
    final next = renderDocumentToDom(state, components, attrs, document,
        suggestionView: suggestionView);
    host.appendChild(next);
    _root = next;
    _state = state;
  }

  void reconcile(State state) {
    if (_root == null) {
      mount(state);
      return;
    }
    final next = renderDocumentToDom(state, components, attrs, document,
        suggestionView: suggestionView);
    final current = _root!;
    if (!_reconcileElement(current, next)) {
      host.replaceChild(next, current);
      _root = next;
    }
    _state = state;
  }

  void destroy() {
    final current = _root;
    if (current != null && current.parentNode != null) {
      current.parentNode!.removeChild(current);
    }
    _root = null;
    _state = null;
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
    if (node is! web.Element) continue;
    final key = node.getAttribute('data-block-id');
    if (key != null && key.isNotEmpty) keyed[key] = node;
  }
  final hasKeys = freshNodes.any((node) =>
      node is web.Element &&
      (node.getAttribute('data-block-id') ?? '').isNotEmpty);
  if (!hasKeys) {
    _reconcileUnkeyedChildren(current, fresh);
    return true;
  }

  final desired = <web.Node>[];
  for (var i = 0; i < freshNodes.length; i++) {
    final next = freshNodes[i];
    if (next is web.Element) {
      final key = next.getAttribute('data-block-id');
      final keyedOld = key == null ? null : keyed[key];
      if (keyedOld != null && _reconcileElement(keyedOld, next)) {
        desired.add(keyedOld);
        continue;
      }
      final positional = i < currentNodes.length ? currentNodes[i] : null;
      if (key == null &&
          positional is web.Element &&
          _reconcileElement(positional, next)) {
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
    } else if (oldNode is web.Element && newNode is web.Element) {
      if (!_reconcileElement(oldNode, newNode)) {
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
