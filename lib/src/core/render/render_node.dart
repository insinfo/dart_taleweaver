/// Render tree nodes.
///
/// Port of `render/render-node.ts`.
library;

import '../styles/computed_style.dart';
import '../styles/style.dart';
import 'layout_metadata.dart';

abstract class RenderNode {
  String get type;
  String get key;
  Style get style;
  ComputedStyle? get computedStyle;
}

class ElementBox implements RenderNode {
  @override
  final String type = 'element';
  @override
  final String key;
  @override
  final Style style;
  @override
  final ComputedStyle? computedStyle;
  
  final LayoutBoxMetadata? metadata;
  final List<RenderNode> children;

  const ElementBox({
    required this.key,
    required this.style,
    required this.children,
    this.computedStyle,
    this.metadata,
  });
  
  ElementBox copyWith({
    ComputedStyle? computedStyle,
    List<RenderNode>? children,
  }) {
    return ElementBox(
      key: key,
      style: style,
      children: children ?? this.children,
      computedStyle: computedStyle ?? this.computedStyle,
      metadata: metadata,
    );
  }
}

class TextBox implements RenderNode {
  @override
  final String type = 'text';
  @override
  final String key;
  @override
  final Style style;
  @override
  final ComputedStyle? computedStyle;
  
  final String text;
  final String? link;

  const TextBox({
    required this.key,
    required this.style,
    required this.text,
    this.computedStyle,
    this.link,
  });
  
  TextBox copyWith({
    ComputedStyle? computedStyle,
  }) {
    return TextBox(
      key: key,
      style: style,
      text: text,
      computedStyle: computedStyle ?? this.computedStyle,
      link: link,
    );
  }
}

ElementBox createElementBox(
  String key,
  Style style,
  List<RenderNode> children, [
  LayoutBoxMetadata? metadata,
]) {
  return ElementBox(
    key: key,
    style: style,
    children: List.unmodifiable(children),
    metadata: metadata,
  );
}

TextBox createTextBox(
  String key,
  Style style,
  String text, [
  String? link,
]) {
  return TextBox(
    key: key,
    style: style,
    text: text,
    link: link,
  );
}
