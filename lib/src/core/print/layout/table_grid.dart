/// Print-layer table grid adapter.
///
/// Structural span resolution lives in the neutral core; this adapter reads
/// the metadata stamped by the table-cell component and exposes the same API
/// used by the print table formatting context.
library;

import '../../render/layout_metadata.dart';
import '../../state/block_id.dart';
import '../../state/table_grid_core.dart';

({int rowSpan, int colSpan}) cellSpan(LayoutBoxMetadata? metadata) => (
      rowSpan: _span(metadata?.rowSpan),
      colSpan: _span(metadata?.colSpan),
    );

int _span(int? value) => value != null && value >= 1 ? value : 1;

class GridCellInput {
  final BlockId key;
  final LayoutBoxMetadata? metadata;
  const GridCellInput(this.key, [this.metadata]);
}

TableGrid assignPrintTableGrid(List<List<GridCellInput>> rows) =>
    assignTableGrid([
      for (final row in rows)
        [
          for (final input in row)
            (() {
              final span = cellSpan(input.metadata);
              return GridCell(
                  cellId: input.key,
                  rowSpan: span.rowSpan,
                  colSpan: span.colSpan);
            })(),
        ],
    ]);
