/// Table of contents component.
///
/// Port of `components/table-of-contents.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class TableOfContentsComponent implements LeafComponentDefinition {
  @override
  final String type = 'table-of-contents';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'atomic';
  @override
  final String? splitFollowOnType = null;

  const TableOfContentsComponent();

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
        blockSize: Length.px(0),
      ),
      const [],
      const LayoutBoxMetadata(tableOfContents: true),
    );
  }
}

const tableOfContentsComponent = TableOfContentsComponent();
