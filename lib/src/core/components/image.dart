/// Image component.
///
/// Port of `components/image.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

double _numAttr(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

String _strAttr(dynamic value, String fallback) {
  if (value is String) return value;
  return fallback;
}

class ImageComponent implements LeafComponentDefinition {
  @override
  final String type = 'image';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'atomic';
  @override
  final String? splitFollowOnType = null;

  const ImageComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final src = _strAttr(view.attrs['src'], '');
    final alt = _strAttr(view.attrs['alt'], '');

    final widthAttr = view.attrs['width'];
    final heightAttr = view.attrs['height'];

    final inlineSize = widthAttr != null ? _numAttr(widthAttr, 0.0) : 'auto';
    final blockSize = heightAttr != null ? _numAttr(heightAttr, 0.0) : 'auto';

    final width = _numAttr(widthAttr, 0.0);
    final height = _numAttr(heightAttr, 0.0);

    final direction =
        view.computedStyle.direction; // never null in Dart ComputedStyle
    final float = imageWrapFloat(view.attrs['wrap'], direction);

    final style = Style(
      display: Display.block,
      inlineSize: inlineSize,
      blockSize: blockSize,
      float: float,
    );

    return createElementBox(
      view.id.value,
      style,
      const [], // empty inline items for atomic
      LayoutBoxMetadata(
        image: ImageMetadata(src: src, width: width, height: height, alt: alt),
      ),
    );
  }
}

const imageComponent = ImageComponent();
