/// Table context logic.
///
/// Port of `table-context.ts`.
library;

import 'block_id.dart';
import 'block_traversal.dart';
import 'state.dart';
import 'table_cell_span.dart';
import 'table_grid_core.dart';

class TableContext {
  final BlockId tableId;
  final BlockId rowId;
  final BlockId cellId;
  final int rowIndex;
  final int colIndex;
  final List<BlockId> rowIds;
  final List<List<BlockId>> cellIdsByRow;
  final bool spanned;
  final bool ragged;
  final bool hasSpans;
  final TableGrid? grid;

  const TableContext({
    required this.tableId,
    required this.rowId,
    required this.cellId,
    required this.rowIndex,
    required this.colIndex,
    required this.rowIds,
    required this.cellIdsByRow,
    required this.spanned,
    required this.ragged,
    required this.hasSpans,
    this.grid,
  });
}

List<BlockId> getChildIds(State state, BlockId parentId) {
  final parent = getBlock(state, parentId);
  if (parent == null) return const [];
  final out = <BlockId>[];
  final maxSteps = blockCount(state) + 1;
  int steps = 0;
  var cur = parent.firstChildId;
  while (cur != null) {
    if (++steps > maxSteps) {
      throw StateError('getChildIds: cycle');
    }
    final child = getBlock(state, cur);
    if (child == null) break;
    out.add(cur);
    cur = child.nextSiblingId;
  }
  return out;
}

TableContext? resolveTableContext(State state, BlockId blockId) {
  BlockId? cellId;
  for (final id in ancestorChain(state, getBlock(state, blockId)!).map((b) => b.id)) {
    if (getBlock(state, id)?.type == 'table-cell') {
      cellId = id;
      break;
    }
  }
  if (cellId == null) return null;

  final cell = getBlock(state, cellId);
  final rowId = cell?.parentId;
  if (rowId == null || getBlock(state, rowId)?.type != 'table-row') return null;

  final tableId = getBlock(state, rowId)?.parentId;
  if (tableId == null || getBlock(state, tableId)?.type != 'table') return null;

  final rowIds = getChildIds(state, tableId)
      .where((id) => getBlock(state, id)?.type == 'table-row')
      .toList();
  final cellIdsByRow = rowIds.map((rid) {
    return getChildIds(state, rid)
        .where((id) => getBlock(state, id)?.type == 'table-cell')
        .toList();
  }).toList();

  final rowIndex = rowIds.indexOf(rowId);
  final caretRowCells = rowIndex >= 0 ? cellIdsByRow[rowIndex] : null;
  final colIndex = caretRowCells != null ? caretRowCells.indexOf(cellId) : -1;
  if (rowIndex < 0 || colIndex < 0 || caretRowCells == null) return null;

  final spanned = cellIdsByRow.any((cells) => cells.any((cid) {
    final c = getBlock(state, cid);
    return c != null && (isSpan(c.attrs['rowSpan']) || isSpan(c.attrs['colSpan']));
  }));

  final grid = buildTableGrid(state, tableId);
  final ragged = grid == null
      ? cellIdsByRow.any((cells) => cells.length != caretRowCells.length)
      : grid.occupancy.any((row) => row.any((slot) => slot == null));

  return TableContext(
    tableId: tableId,
    rowId: rowId,
    cellId: cellId,
    rowIndex: rowIndex,
    colIndex: colIndex,
    rowIds: rowIds,
    cellIdsByRow: cellIdsByRow,
    spanned: spanned,
    ragged: ragged,
    hasSpans: ragged || spanned,
    grid: grid,
  );
}

TableGrid? buildTableGrid(State state, BlockId tableId) {
  if (getBlock(state, tableId)?.type != 'table') return null;
  final rows = getChildIds(state, tableId)
      .where((rid) => getBlock(state, rid)?.type == 'table-row')
      .map((rid) => getChildIds(state, rid)
          .where((cid) => getBlock(state, cid)?.type == 'table-cell')
          .map((cid) {
            final attrs = getBlock(state, cid)?.attrs ?? const {};
            return GridCell(
              cellId: cid,
              rowSpan: spanValue(attrs['rowSpan']) ?? 1,
              colSpan: spanValue(attrs['colSpan']) ?? 1,
            );
          }).toList())
      .toList();
  return assignTableGrid(rows);
}
