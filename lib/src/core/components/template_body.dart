/// Template body component.
///
/// Port of `components/template-body.ts`.
library;

import '../render/block_view.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class TemplateBodyComponent implements ContainerComponentDefinition {
  @override
  final String type = 'template-body';
  @override
  final String kind = 'container';

  const TemplateBodyComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    return createElementBox(
      view.id.value,
      const Style(
        display: Display.block,
        whiteSpace: WhiteSpace.breakSpaces,
        overflowWrap: OverflowWrap.breakWord,
      ),
      childRenderNodes,
    );
  }
}

const templateBodyComponent = TemplateBodyComponent();
