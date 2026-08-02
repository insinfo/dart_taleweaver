/// Horizontal line component.
///
/// Port of `components/horizontal-line.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class HorizontalLineComponent implements LeafComponentDefinition {
  @override
  final String type = 'horizontal-line';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'atomic';
  @override
  final String? splitFollowOnType = null;

  const HorizontalLineComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    return createElementBox(
      view.id.value,
      const Style(
        display: Display.block,
        blockSize: Length.px(16),
      ),
      const [],
      const LayoutBoxMetadata(horizontalLine: true),
    );
  }
}

const horizontalLineComponent = HorizontalLineComponent();
