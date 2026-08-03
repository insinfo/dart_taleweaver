/// Editable text-box and simple-shape components.
///
/// The document model persists only normal leaf blocks plus JSON primitives.
/// Shapes that accept labels reuse the standard inline-content pipeline, so
/// they remain editable through the same selection, formatting and history
/// paths as paragraphs.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../state/drawing.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

({LengthOrAuto start, LengthOrAuto end}) _drawingMargins(
  DrawingAlignment alignment,
) =>
    switch (alignment) {
      DrawingAlignment.inlineStart => (
          start: LengthOrAuto.length(const Length.px(0)),
          end: const LengthOrAuto.auto(),
        ),
      DrawingAlignment.center => (
          start: const LengthOrAuto.auto(),
          end: const LengthOrAuto.auto(),
        ),
      DrawingAlignment.inlineEnd => (
          start: const LengthOrAuto.auto(),
          end: LengthOrAuto.length(const Length.px(0)),
        ),
    };

Style _drawingStyle(
  DrawingProperties properties, {
  required bool isLine,
  dynamic textAlign,
}) {
  final margins = _drawingMargins(properties.alignment);
  final borderStyle = isLine ? BorderStyle.none : BorderStyle.solid;
  final borderWidth = isLine ? 0.0 : properties.outlineWidth;
  return Style(
    display: Display.block,
    inlineSize: Length.px(properties.width),
    blockSize: Length.px(properties.height),
    boxSizing: BoxSizing.borderBox,
    marginBlockStart: LengthOrAuto.length(const Length.px(4)),
    marginBlockEnd: LengthOrAuto.length(const Length.px(8)),
    marginInlineStart: margins.start,
    marginInlineEnd: margins.end,
    paddingBlockStart: isLine ? null : const Length.px(6),
    paddingBlockEnd: isLine ? null : const Length.px(6),
    paddingInlineStart: isLine ? null : const Length.px(8),
    paddingInlineEnd: isLine ? null : const Length.px(8),
    borderBlockStartWidth: borderWidth,
    borderBlockEndWidth: borderWidth,
    borderInlineStartWidth: borderWidth,
    borderInlineEndWidth: borderWidth,
    borderBlockStartStyle: borderStyle,
    borderBlockEndStyle: borderStyle,
    borderInlineStartStyle: borderStyle,
    borderInlineEndStyle: borderStyle,
    borderBlockStartColor: properties.outline,
    borderBlockEndColor: properties.outline,
    borderInlineStartColor: properties.outline,
    borderInlineEndColor: properties.outline,
    backgroundColor: isLine ? 'transparent' : properties.fill,
    whiteSpace: WhiteSpace.preWrap,
    overflowWrap: OverflowWrap.anywhere,
    textAlign: textAlign is TextAlign ? textAlign : null,
  );
}

class TextBoxComponent implements LeafComponentDefinition {
  @override
  final String type = 'text-box';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'inline-bearing';
  @override
  final String? splitFollowOnType = 'paragraph';

  const TextBoxComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final properties = DrawingProperties.fromAttrs(
      view.attrs,
      fallback: DrawingProperties.textBoxDefaults,
    );
    return createElementBox(
      view.id.value,
      _drawingStyle(
        properties,
        isLine: false,
        textAlign: textAlignFromAttrs(view.attrs['textAlign']),
      ),
      inlineRenderNodes,
      LayoutBoxMetadata(
        drawing: DrawingMetadata(
          kind: 'text-box',
          properties: properties,
          acceptsText: true,
        ),
      ),
    );
  }
}

class ShapeComponent implements LeafComponentDefinition {
  @override
  final String type = 'shape';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'inline-bearing';
  @override
  final String? splitFollowOnType = 'paragraph';

  const ShapeComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final shapeKind = DrawingShapeKind.fromValue(view.attrs['shapeKind']) ??
        DrawingShapeKind.rectangle;
    final properties = DrawingProperties.fromAttrs(
      view.attrs,
      fallback: DrawingProperties.defaultsFor(shapeKind),
    );
    final acceptsText = shapeKind != DrawingShapeKind.line;
    return createElementBox(
      view.id.value,
      _drawingStyle(
        properties,
        isLine: !acceptsText,
        textAlign: textAlignFromAttrs(view.attrs['textAlign']),
      ),
      acceptsText ? inlineRenderNodes : const <RenderNode>[],
      LayoutBoxMetadata(
        drawing: DrawingMetadata(
          kind: shapeKind.value,
          properties: properties,
          acceptsText: acceptsText,
        ),
      ),
    );
  }
}

const textBoxComponent = TextBoxComponent();
const shapeComponent = ShapeComponent();
