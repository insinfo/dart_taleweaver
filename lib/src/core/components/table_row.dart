/// Table row component.
///
/// Port of `components/table-row.ts`.
library;

import '../render/block_view.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class TableRowComponent implements ContainerComponentDefinition {
  @override
  final String type = 'table-row';
  @override
  final String kind = 'container';

  const TableRowComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    return createElementBox(
      view.id.value,
      const Style(display: Display.tableRow),
      childRenderNodes,
    );
  }
}

const tableRowComponent = TableRowComponent();
