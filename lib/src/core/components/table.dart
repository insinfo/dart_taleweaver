/// Table component.
///
/// Port of `components/table.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/style.dart';
import 'component_definition.dart';

bool _isNumberArray(dynamic v) {
  if (v is List) {
    for (final x in v) {
      if (x is! num) return false;
    }
    return true;
  }
  return false;
}

bool _isNonNegativeInteger(dynamic v) {
  return v is int && v >= 0;
}

class TableComponent implements ContainerComponentDefinition {
  @override
  final String type = 'table';
  @override
  final String kind = 'container';

  const TableComponent();

  @override
  RenderNode render(
    covariant ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  ) {
    final cwRaw = view.attrs['columnWidths'];
    final hrcRaw = view.attrs['headerRowCount'];

    final cw = _isNumberArray(cwRaw)
        ? (cwRaw as List)
            .map((e) => (e as num).toDouble())
            .toList(growable: false)
        : null;
    final hrc = _isNonNegativeInteger(hrcRaw) ? hrcRaw as int : null;

    final hasMetadata = cw != null || hrc != null;

    return createElementBox(
      view.id.value,
      const Style(display: Display.table),
      childRenderNodes,
      hasMetadata
          ? LayoutBoxMetadata(columnWidths: cw, headerRowCount: hrc)
          : null,
    );
  }
}

const tableComponent = TableComponent();
