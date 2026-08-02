/// Footnote body component.
///
/// Port of `components/footnote-body.ts`.
library;

import '../render/block_view.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class FootnoteBodyComponent implements ContainerComponentDefinition {
  @override
  final String type = 'footnote-body';
  @override
  final String kind = 'container';

  const FootnoteBodyComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    final number = context.footnoteNumber(view.id);
    
    final style = Style(
      display: Display.block,
      whiteSpace: WhiteSpace.breakSpaces,
      overflowWrap: OverflowWrap.breakWord,
      orphans: 1,
      widows: 1,
      markerText: number,
    );
    
    return createElementBox(
      view.id.value,
      style,
      childRenderNodes,
    );
  }
}

const footnoteBodyComponent = FootnoteBodyComponent();
