/// Browser lifecycle adapter for the accessibility DOM mirror.
library;

import 'package:web/web.dart' as web;

import '../state/state.dart';
import '../state/suggestions.dart';
import 'accessibility.dart';
import 'dom_mirror.dart';

/// Maintains a detached/hidden semantic subtree alongside the visual editor.
///
/// The mirror is intentionally driven from [State] and an optional field map;
/// it never reads layout geometry and can therefore be updated independently
/// from Canvas pagination or the contenteditable renderer.
class AccessibilityDomMirror {
  final web.HTMLElement host;
  final web.Document document;
  SuggestionView suggestionView;
  web.Element? _root;
  State? _state;

  AccessibilityDomMirror({
    required this.host,
    required this.document,
    this.suggestionView = SuggestionView.suggesting,
  }) {
    // Match dom-mirror-host.ts: the mirror is a focusable, AT-visible editing
    // surface. The semantic subtree remains visually clipped, but must not be
    // aria-hidden or display:none so screen readers can review it.
    host.setAttribute('data-taleweaver-a11y-mirror', 'true');
    host.contentEditable = 'true';
    host.setAttribute('role', 'textbox');
    host.setAttribute('aria-multiline', 'true');
    host.tabIndex = 0;
    host.style.cssText =
        'position:absolute;width:1px;height:1px;overflow:hidden;'
        'clip:rect(0 0 0 0);clip-path:inset(50%);white-space:pre;'
        'caret-color:transparent;outline:none';
  }

  web.Element? get root => _root;
  State? get state => _state;

  /// Move browser focus to the semantic mirror, as the TypeScript host does.
  void focus() => host.focus();

  void mount(State state, {Map<String, String>? resolvedFields}) {
    destroy();
    final next = buildAccessibilityDomMirror(
      buildAccessibilityTree(state, suggestionView: suggestionView),
      document,
      resolvedFields: resolvedFields,
    );
    host.appendChild(next);
    _root = next;
    _state = state;
  }

  void reconcile(State state, {Map<String, String>? resolvedFields}) {
    if (_root == null) {
      mount(state, resolvedFields: resolvedFields);
      return;
    }
    final next = buildAccessibilityDomMirror(
      buildAccessibilityTree(state, suggestionView: suggestionView),
      document,
      resolvedFields: resolvedFields,
    );
    final current = _root!;
    // Keep the root and keyed semantic descendants stable so assistive
    // technology focus and references are not invalidated on every editor
    // transaction. Non-keyed inline runs reconcile by position.
    _reconcileSemanticElement(current, next);
    _state = state;
  }

  void destroy() {
    final current = _root;
    if (current != null && current.parentNode == host) {
      host.removeChild(current);
    }
    _root = null;
    _state = null;
  }
}

bool _reconcileSemanticElement(web.Element current, web.Element fresh) {
  if (current.localName != fresh.localName) return false;
  _reconcileAttributes(current, fresh);
  final oldNodes = _nodes(current);
  final freshNodes = _nodes(fresh);
  final keyed = <String, web.Element>{};
  for (final node in oldNodes) {
    if (node is! web.Element) continue;
    final key = node.getAttribute('data-block-id');
    if (key != null && key.isNotEmpty) keyed[key] = node;
  }
  final desired = <web.Node>[];
  for (var i = 0; i < freshNodes.length; i++) {
    final incoming = freshNodes[i];
    final positional = i < oldNodes.length ? oldNodes[i] : null;
    if (incoming is web.Element) {
      final key = incoming.getAttribute('data-block-id');
      final retained = key == null ? null : keyed[key];
      if (retained != null && _reconcileSemanticElement(retained, incoming)) {
        desired.add(retained);
      } else if (key == null &&
          positional is web.Element &&
          _reconcileSemanticElement(positional, incoming)) {
        desired.add(positional);
      } else {
        desired.add(incoming);
      }
    } else if (positional != null &&
        positional.nodeType == web.Node.TEXT_NODE &&
        incoming.nodeType == web.Node.TEXT_NODE) {
      positional.nodeValue = incoming.nodeValue;
      desired.add(positional);
    } else {
      desired.add(incoming);
    }
  }
  while (current.firstChild != null) {
    current.removeChild(current.firstChild!);
  }
  for (final node in desired) {
    current.appendChild(node);
  }
  return true;
}

void _reconcileAttributes(web.Element current, web.Element fresh) {
  final freshNames = <String>{};
  for (var i = 0; i < fresh.attributes.length; i++) {
    final attr = fresh.attributes.item(i);
    if (attr == null) continue;
    freshNames.add(attr.name);
    current.setAttribute(attr.name, attr.value);
  }
  final oldNames = <String>[];
  for (var i = 0; i < current.attributes.length; i++) {
    final attr = current.attributes.item(i);
    if (attr != null) oldNames.add(attr.name);
  }
  for (final name in oldNames) {
    if (!freshNames.contains(name)) current.removeAttribute(name);
  }
}

List<web.Node> _nodes(web.Element element) {
  final result = <web.Node>[];
  for (var i = 0; i < element.childNodes.length; i++) {
    final node = element.childNodes.item(i);
    if (node != null) result.add(node);
  }
  return result;
}
