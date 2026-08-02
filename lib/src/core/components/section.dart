/// Section component.
///
/// Port of `components/section.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class SectionComponent implements ContainerComponentDefinition {
  @override
  final String type = 'section';
  @override
  final String kind = 'container';

  const SectionComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    return createElementBox(
      view.id.value,
      const Style(display: Display.contents),
      childRenderNodes,
      LayoutBoxMetadata(
        blockType: 'section',
        pageInlineSize: view.attrs['pageInlineSize'],
        pageBlockSize: view.attrs['pageBlockSize'],
        pageMargins: view.attrs['pageMargins'],
        pageGap: view.attrs['pageGap'],
        headerBlockId: view.attrs['headerBlockId'],
        footerBlockId: view.attrs['footerBlockId'],
        columnCount: view.attrs['columnCount'],
        columnGap: view.attrs['columnGap'],
        columnRule: view.attrs['columnRule'],
      ),
    );
  }
}

const sectionComponent = SectionComponent();
