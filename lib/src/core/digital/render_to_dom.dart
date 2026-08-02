library;

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
import '../render/render_pipeline.dart';
import '../render/render_node.dart';
import '../state/state.dart';
import '../state/block_id.dart';
import '../state/suggestions.dart';
import 'computed_style_to_css.dart';

web.Node? renderNodeToDom(RenderNode node, web.Document document,
    {bool stampBlockIds = false}) {
  if (node is TextBox) {
    final text = document.createTextNode(node.text);
    if (node.link == null) return text;
    final anchor = document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = node.link!;
    anchor.appendChild(text);
    return anchor;
  }
  if (node is! ElementBox) return null;

  final display = node.computedStyle?.display.value ?? 'block';
  if (display == 'none') return null;
  final metadata = node.metadata;
  final tag = metadata?.headingLevel != null
      ? 'h${metadata!.headingLevel}'
      : metadata?.horizontalLine == true
          ? 'hr'
          : metadata?.image != null
              ? 'img'
              : display == 'list-item'
                  ? 'li'
                  : display == 'table'
                      ? 'table'
                      : display == 'table-row'
                          ? 'tr'
                          : display == 'table-cell'
                              ? 'td'
                              : display == 'inline' || display == 'inline-block'
                                  ? 'span'
                                  : 'div';
  final element = document.createElement(tag);
  final css = node.computedStyle == null
      ? ''
      : computedStyleToInlineStyle(node.computedStyle!);
  if (css.isNotEmpty) element.setAttribute('style', css);
  if (stampBlockIds &&
      display != 'inline' &&
      display != 'inline-block' &&
      metadata?.embedType == null) {
    element.setAttribute('data-block-id', node.key);
  }
  if (metadata?.embedType != null)
    element.setAttribute('data-inline-embed', '');
  if (metadata?.image != null) {
    final image = metadata!.image!;
    element.setAttribute('src', image.src);
    element.setAttribute('width', '${image.width}');
    element.setAttribute('height', '${image.height}');
    element.setAttribute('alt', image.alt ?? '');
  }
  if (metadata?.list != null && node.computedStyle?.markerText != null) {
    final marker = document.createElement('span');
    marker.setAttribute('data-tw-marker', '');
    marker.textContent = node.computedStyle!.markerText!;
    element.appendChild(marker);
  }
  for (final child in _groupListChildren(node.children, document)) {
    final childNode = renderNodeToDom(child, document,
        stampBlockIds:
            stampBlockIds && display != 'inline' && display != 'inline-block');
    if (childNode != null) element.appendChild(childNode);
  }
  if (tag != 'img' &&
      tag != 'hr' &&
      element.textContent == '' &&
      (display == 'block' ||
          display == 'list-item' ||
          display == 'table-cell')) {
    element.appendChild(document.createElement('br'));
  }
  return element;
}

List<RenderNode> _groupListChildren(
    List<RenderNode> children, web.Document document) {
  final result = <RenderNode>[];
  // DOM list grouping is handled at the element boundary in the full browser
  // reconciler; retaining the original children here keeps keys stable and
  // avoids inventing render nodes that cannot carry engine metadata.
  result.addAll(children);
  return result;
}

/// Render a complete State through the styled render tree into browser-flowed
/// DOM. This is the digital backend entry point; it performs no geometry.
web.Element renderDocumentToDom(
  State state,
  ComponentRegistry components,
  AttrRegistry attrs,
  web.Document document, {
  SuggestionView suggestionView = SuggestionView.suggesting,
  Map<BlockId, int>? pageNumbers,
}) {
  // `renderCascadedState` currently uses the default attr registry internally;
  // keep the explicit parameter for API parity and future registry injection.
  final _ = attrs;
  final root = renderCascadedState(state, components,
      suggestionView: suggestionView, pageNumbers: pageNumbers);
  final node = renderNodeToDom(root, document, stampBlockIds: true);
  if (node is web.Element) return node;
  final wrapper = document.createElement('div');
  if (node != null) wrapper.appendChild(node);
  return wrapper;
}
