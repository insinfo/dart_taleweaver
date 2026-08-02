/// Table grid core algorithm.
///
/// Port of `table-grid-core.ts`.
library;

import 'dart:math';
import 'block_id.dart';

int clampSpan(num v) {
  if (v.isFinite && v >= 1) return v.floor();
  return 1;
}

class GridCell {
  final BlockId cellId;
  final int rowSpan;
  final int colSpan;

  const GridCell({
    required this.cellId,
    required this.rowSpan,
    required this.colSpan,
  });
}

class AssignedCell {
  final BlockId cellId;
  final int gridRow;
  final int gridCol;
  final int rowSpan;
  final int colSpan;

  const AssignedCell({
    required this.cellId,
    required this.gridRow,
    required this.gridCol,
    required this.rowSpan,
    required this.colSpan,
  });
}

class TableGrid {
  final List<AssignedCell> cells;
  final int columnCount;
  final List<List<BlockId?>> occupancy;

  const TableGrid({
    required this.cells,
    required this.columnCount,
    required this.occupancy,
  });
}

TableGrid assignTableGrid(List<List<GridCell>> rows) {
  final rowCount = rows.length;
  final cells = <AssignedCell>[];
  final occ = List.generate(rowCount, (_) => <BlockId?>[]);
  final freeAtRow = <int>[];
  int columnCount = 0;

  for (int r = 0; r < rowCount; r++) {
    int c = 0;
    for (final cell in rows[r]) {
      while ((c < freeAtRow.length ? freeAtRow[c] : 0) > r) {
        c++;
      }

      final colSpan = clampSpan(cell.colSpan);
      final rawRowSpan = clampSpan(cell.rowSpan);
      final rowSpan = min(rawRowSpan, rowCount - r);

      final topRow = occ[r];
      for (int dr = 0; dr < rowSpan; dr++) {
        final rowArr = occ[r + dr];
        for (int dc = 0; dc < colSpan; dc++) {
          final cc = c + dc;

          while (rowArr.length <= cc) rowArr.add(null);

          if (rowArr[cc] != null) {
            continue;
          }
          rowArr[cc] = cell.cellId;
        }
      }

      for (int dc = 0; dc < colSpan; dc++) {
        final cc = c + dc;
        if (topRow.length > cc && topRow[cc] == cell.cellId) {
          while (freeAtRow.length <= cc) freeAtRow.add(0);
          freeAtRow[cc] = max(freeAtRow[cc], r + rowSpan);
        }
      }

      cells.add(AssignedCell(
        cellId: cell.cellId,
        gridRow: r,
        gridCol: c,
        rowSpan: rowSpan,
        colSpan: colSpan,
      ));

      c += colSpan;
      if (c > columnCount) columnCount = c;
    }
  }

  for (int r = 0; r < rowCount; r++) {
    while (occ[r].length < columnCount) occ[r].add(null);
  }

  return TableGrid(cells: cells, columnCount: columnCount, occupancy: occ);
}
