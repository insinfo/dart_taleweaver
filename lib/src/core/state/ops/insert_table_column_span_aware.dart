/// Insert table column span aware.
///
/// Port of `ops/insert-table-column-span-aware.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../table_column_widths.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'insert_table_column.dart'; // for ColumnPosition
import 'set_block_attrs.dart';

class _InsertTableColumnSpanAwareNewCell {
  final BlockId rowId;
  final BlockId cellId;
  final BlockId paragraphId;
  final BlockId? prevCellId;
  final BlockId? nextCellId;

  const _InsertTableColumnSpanAwareNewCell({
    required this.rowId,
    required this.cellId,
    required this.paragraphId,
    this.prevCellId,
    this.nextCellId,
  });
}

class _InsertTableColumnSpanAwareBump {
  final BlockId cellId;
  final ReadonlyAttrs newAttrs;

  const _InsertTableColumnSpanAwareBump(this.cellId, this.newAttrs);
}

class InsertTableColumnSpanAwarePlan {
  final BlockId tableId;
  final List<_InsertTableColumnSpanAwareNewCell> newCells;
  final List<_InsertTableColumnSpanAwareBump> crossingBumps;
  final ReadonlyAttrs? newTableAttrs;

  const InsertTableColumnSpanAwarePlan({
    required this.tableId,
    required this.newCells,
    required this.crossingBumps,
    this.newTableAttrs,
  });
}

OperationResult insertTableColumnSpanAware(
  State state,
  TableContext ctx,
  ColumnPosition position,
  IdAllocator allocator,
) {
  final plan = planInsertTableColumnSpanAware(state, ctx, position, allocator);
  if (plan == null) return OperationResult(state: state, dirtyIds: {});
  return applyOperation(state, (doc) {
    insertTableColumnSpanAwareInTx(doc, plan);
  });
}

InsertTableColumnSpanAwarePlan? planInsertTableColumnSpanAware(
  State state,
  TableContext ctx,
  ColumnPosition position,
  IdAllocator allocator,
) {
  final grid = buildTableGrid(state, ctx.tableId);
  if (grid == null) return null;
  final caretList = grid.cells.where((c) => c.cellId == ctx.cellId);
  if (caretList.isEmpty) return null;
  final caret = caretList.first;

  final rowCount = grid.occupancy.length;
  final gc = position == ColumnPosition.left
      ? caret.gridCol
      : caret.gridCol + caret.colSpan;

  final crossingIds = <BlockId>{};
  final uncoveredRows = <int>[];

  for (int r = 0; r < rowCount; r++) {
    final left = gc - 1 >= 0
        ? (gc - 1 < grid.occupancy[r].length ? grid.occupancy[r][gc - 1] : null)
        : null;
    final right = gc < grid.columnCount
        ? (gc < grid.occupancy[r].length ? grid.occupancy[r][gc] : null)
        : null;
    if (left != null && left == right) {
      crossingIds.add(left);
    } else {
      uncoveredRows.add(r);
    }
  }

  final crossingBumps = crossingIds.map((cellId) {
    final cell = grid.cells.firstWhere((c) => c.cellId == cellId);
    final block = getBlock(state, cellId);
    if (block == null) {
      throw StateError(
          'insertTableColumnSpanAware: crossing cell "$cellId" not found in state');
    }
    final newAttrs = Map<String, dynamic>.of(block.attrs);
    newAttrs['colSpan'] = cell.colSpan + 1;
    return _InsertTableColumnSpanAwareBump(cellId, newAttrs);
  }).toList();

  final newCells = uncoveredRows.map((r) {
    final originating = grid.cells.where((c) => c.gridRow == r).toList();
    originating.sort((a, b) => a.gridCol.compareTo(b.gridCol));

    BlockId? prevCellId;
    for (final c in originating) {
      if (c.gridCol < gc) prevCellId = c.cellId;
    }
    BlockId? nextCellId;
    for (final c in originating) {
      if (c.gridCol >= gc) {
        nextCellId = c.cellId;
        break;
      }
    }
    if (r >= ctx.rowIds.length) {
      throw StateError('insertTableColumnSpanAware: row id missing');
    }
    return _InsertTableColumnSpanAwareNewCell(
      rowId: ctx.rowIds[r],
      cellId: allocator.allocate(),
      paragraphId: allocator.allocate(),
      prevCellId: prevCellId,
      nextCellId: nextCellId,
    );
  }).toList();

  final table = getBlock(state, ctx.tableId);
  final cw = table?.attrs['columnWidths'];
  ReadonlyAttrs? newTableAttrs;
  if (table != null && isColumnWidths(cw)) {
    newTableAttrs = Map<String, dynamic>.of(table.attrs);
    newTableAttrs['columnWidths'] =
        spliceColumnWidth(parseColumnWidths(cw), gc);
  }

  return InsertTableColumnSpanAwarePlan(
    tableId: ctx.tableId,
    newCells: newCells,
    crossingBumps: crossingBumps,
    newTableAttrs: newTableAttrs,
  );
}

void insertTableColumnSpanAwareInTx(
    TwDoc doc, InsertTableColumnSpanAwarePlan plan) {
  for (final bump in plan.crossingBumps) {
    setBlockAttrsInTx(doc, bump.cellId, bump.newAttrs);
  }

  for (final nc in plan.newCells) {
    doc.setBlockMap(nc.cellId.value, {
      BlockFields.type: 'table-cell',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: nc.rowId.value,
      if (nc.prevCellId != null)
        BlockFields.prevSiblingId: nc.prevCellId!.value,
      if (nc.nextCellId != null)
        BlockFields.nextSiblingId: nc.nextCellId!.value,
      BlockFields.firstChildId: nc.paragraphId.value,
      BlockFields.lastChildId: nc.paragraphId.value,
    });

    doc.setBlockMap(nc.paragraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: nc.cellId.value,
      BlockFields.inlineContent: const InlineContent([]),
    });

    if (nc.prevCellId != null) {
      doc.getBlockMap(nc.prevCellId!.value)?[BlockFields.nextSiblingId] =
          nc.cellId.value;
      doc.markDirty(nc.prevCellId!.value);
    }
    if (nc.nextCellId != null) {
      doc.getBlockMap(nc.nextCellId!.value)?[BlockFields.prevSiblingId] =
          nc.cellId.value;
      doc.markDirty(nc.nextCellId!.value);
    }
    if (nc.prevCellId == null || nc.nextCellId == null) {
      final yRow = doc.getBlockMap(nc.rowId.value);
      if (yRow != null) {
        if (nc.prevCellId == null)
          yRow[BlockFields.firstChildId] = nc.cellId.value;
        if (nc.nextCellId == null)
          yRow[BlockFields.lastChildId] = nc.cellId.value;
        doc.markDirty(nc.rowId.value);
      }
    }
  }

  if (plan.newTableAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.newTableAttrs!);
  }
}
