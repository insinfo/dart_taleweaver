/// Document component.
///
/// Port of `components/document.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

class DocumentComponent implements ContainerComponentDefinition {
  @override
  final String type = 'document';
  @override
  final String kind = 'container';

  const DocumentComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    final writingMode = writingModeFromAttrs(view.attrs['writingMode']);
    final language = langFromAttrs(view.attrs['lang']);

    final style = Style(
      display: Display.block,
      whiteSpace: WhiteSpace.breakSpaces,
      overflowWrap: OverflowWrap.breakWord,
      writingMode: writingMode,
      language: language,
    );

    return createElementBox(
      view.id.value,
      style,
      childRenderNodes,
      LayoutBoxMetadata(
        headerBlockId: view.attrs['headerBlockId'],
        footerBlockId: view.attrs['footerBlockId'],
        columnCount: view.attrs['columnCount'],
        columnGap: view.attrs['columnGap'],
        columnRule: view.attrs['columnRule'],
      ),
    );
  }
}

const documentComponent = DocumentComponent();
