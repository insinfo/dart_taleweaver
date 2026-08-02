library;

import 'package:web/web.dart' as web;

import '../render/render_node.dart';
import 'computed_style_to_css.dart';

web.Node? renderNodeToDom(RenderNode node, web.Document document,
    {bool stampBlockIds = false}) {
  if (node is TextBox) return document.createTextNode(node.text);
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
  for (final child in node.children) {
    final childNode = renderNodeToDom(child, document,
        stampBlockIds:
            stampBlockIds && display != 'inline' && display != 'inline-block');
    if (childNode != null) element.appendChild(childNode);
  }
  if (element.textContent == '' &&
      (display == 'block' ||
          display == 'list-item' ||
          display == 'table-cell')) {
    element.appendChild(document.createElement('br'));
  }
  return element;
}
