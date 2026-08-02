/// Table cell component.
///
/// Port of `components/table-cell.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../state/table_cell_span.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';

class TableCellComponent implements ContainerComponentDefinition {
  @override
  final String type = 'table-cell';
  @override
  final String kind = 'container';

  const TableCellComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    final rowSpan = spanValue(view.attrs['rowSpan']);
    final colSpan = spanValue(view.attrs['colSpan']);

    final metadata = (rowSpan != null || colSpan != null)
        ? LayoutBoxMetadata(rowSpan: rowSpan, colSpan: colSpan)
        : null;

    return createElementBox(
      view.id.value,
      const Style(
        display: Display.tableCell,
        borderBlockStartWidth: 1.0,
        borderBlockEndWidth: 1.0,
        borderInlineStartWidth: 1.0,
        borderInlineEndWidth: 1.0,
        borderBlockStartStyle: BorderStyle.solid,
        borderBlockEndStyle: BorderStyle.solid,
        borderInlineStartStyle: BorderStyle.solid,
        borderInlineEndStyle: BorderStyle.solid,
        borderBlockStartColor: '#dadce0',
        borderBlockEndColor: '#dadce0',
        borderInlineStartColor: '#dadce0',
        borderInlineEndColor: '#dadce0',
        paddingBlockStart: Length.px(4),
        paddingBlockEnd: Length.px(4),
        paddingInlineStart: Length.px(8),
        paddingInlineEnd: Length.px(8),
      ),
      childRenderNodes,
      metadata,
    );
  }
}

const tableCellComponent = TableCellComponent();
