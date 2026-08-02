/// Insert table row span aware.
///
/// Port of `ops/insert-table-row-span-aware.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'insert_table_row.dart'; // for RowPosition
import 'set_block_attrs.dart';
import 'table_header_rows.dart';

class _InsertTableRowSpanAwareCell {
  final BlockId cellId;
  final BlockId paragraphId;
  const _InsertTableRowSpanAwareCell(this.cellId, this.paragraphId);
}

class _InsertTableRowSpanAwareBump {
  final BlockId cellId;
  final ReadonlyAttrs newAttrs;
  const _InsertTableRowSpanAwareBump(this.cellId, this.newAttrs);
}

class InsertTableRowSpanAwarePlan {
  final BlockId tableId;
  final BlockId newRowId;
  final BlockId? prevRowId;
  final BlockId? nextRowId;
  final List<_InsertTableRowSpanAwareCell> newCells;
  final List<_InsertTableRowSpanAwareBump> crossingBumps;
  final ReadonlyAttrs? headerAttrs;

  const InsertTableRowSpanAwarePlan({
    required this.tableId,
    required this.newRowId,
    this.prevRowId,
    this.nextRowId,
    required this.newCells,
    required this.crossingBumps,
    this.headerAttrs,
  });
}

OperationResult insertTableRowSpanAware(
  State state,
  TableContext ctx,
  RowPosition position,
  IdAllocator allocator,
) {
  final plan = planInsertTableRowSpanAware(state, ctx, position, allocator);
  if (plan == null) return OperationResult(state: state, dirtyIds: {});
  return applyOperation(state, (doc) {
    insertTableRowSpanAwareInTx(doc, plan);
  });
}

InsertTableRowSpanAwarePlan? planInsertTableRowSpanAware(
  State state,
  TableContext ctx,
  RowPosition position,
  IdAllocator allocator,
) {
  final grid = buildTableGrid(state, ctx.tableId);
  if (grid == null) return null;
  final caretList = grid.cells.where((c) => c.cellId == ctx.cellId);
  if (caretList.isEmpty) return null;
  final caret = caretList.first;

  final rowCount = grid.occupancy.length;
  final gr = position == RowPosition.above
      ? caret.gridRow
      : caret.gridRow + caret.rowSpan;

  final crossingIds = <BlockId>{};
  final newColumns = <int>[];

  for (int c = 0; c < grid.columnCount; c++) {
    final above = gr - 1 >= 0
        ? (c < grid.occupancy[gr - 1].length ? grid.occupancy[gr - 1][c] : null)
        : null;
    final below = gr < rowCount
        ? (c < grid.occupancy[gr].length ? grid.occupancy[gr][c] : null)
        : null;
    if (above != null && above == below) {
      crossingIds.add(above);
    } else {
      newColumns.add(c);
    }
  }

  final crossingBumps = crossingIds.map((cellId) {
    final cell = grid.cells.firstWhere((c) => c.cellId == cellId);
    final block = getBlock(state, cellId);
    if (block == null) {
      throw StateError(
          'insertTableRowSpanAware: crossing cell "$cellId" not found in state');
    }
    final newAttrs = Map<String, dynamic>.of(block.attrs);
    newAttrs['rowSpan'] = cell.rowSpan + 1;
    return _InsertTableRowSpanAwareBump(cellId, newAttrs);
  }).toList();

  final newCells = newColumns
      .map((_) => _InsertTableRowSpanAwareCell(
            allocator.allocate(),
            allocator.allocate(),
          ))
      .toList();

  final prevRowId = gr - 1 >= 0
      ? (gr - 1 < ctx.rowIds.length ? ctx.rowIds[gr - 1] : null)
      : null;
  final nextRowId =
      gr < rowCount ? (gr < ctx.rowIds.length ? ctx.rowIds[gr] : null) : null;

  final headerAttrs =
      headerRowAttrsAfterRowEdit(state, ctx.tableId, RowEditOp.insert, gr);

  return InsertTableRowSpanAwarePlan(
    tableId: ctx.tableId,
    newRowId: allocator.allocate(),
    prevRowId: prevRowId,
    nextRowId: nextRowId,
    newCells: newCells,
    crossingBumps: crossingBumps,
    headerAttrs: headerAttrs,
  );
}

void insertTableRowSpanAwareInTx(TwDoc doc, InsertTableRowSpanAwarePlan plan) {
  for (final bump in plan.crossingBumps) {
    setBlockAttrsInTx(doc, bump.cellId, bump.newAttrs);
  }

  final cells = plan.newCells;
  final lastCell = cells.isEmpty ? -1 : cells.length - 1;

  for (int i = 0; i < cells.length; i++) {
    final cell = cells[i];
    final prevCell = i == 0 ? null : cells[i - 1];
    final nextCell = i == lastCell ? null : cells[i + 1];

    doc.setBlockMap(cell.cellId.value, {
      BlockFields.type: 'table-cell',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: plan.newRowId.value,
      if (prevCell != null) BlockFields.prevSiblingId: prevCell.cellId.value,
      if (nextCell != null) BlockFields.nextSiblingId: nextCell.cellId.value,
      BlockFields.firstChildId: cell.paragraphId.value,
      BlockFields.lastChildId: cell.paragraphId.value,
    });

    doc.setBlockMap(cell.paragraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: cell.cellId.value,
      BlockFields.inlineContent: const InlineContent([]),
    });
  }

  doc.setBlockMap(plan.newRowId.value, {
    BlockFields.type: 'table-row',
    BlockFields.attrs: <String, dynamic>{},
    BlockFields.parentId: plan.tableId.value,
    if (plan.prevRowId != null)
      BlockFields.prevSiblingId: plan.prevRowId!.value,
    if (plan.nextRowId != null)
      BlockFields.nextSiblingId: plan.nextRowId!.value,
    if (cells.isNotEmpty) BlockFields.firstChildId: cells.first.cellId.value,
    if (cells.isNotEmpty) BlockFields.lastChildId: cells.last.cellId.value,
  });

  if (plan.prevRowId != null) {
    doc.getBlockMap(plan.prevRowId!.value)?[BlockFields.nextSiblingId] =
        plan.newRowId.value;
    doc.markDirty(plan.prevRowId!.value);
  }
  if (plan.nextRowId != null) {
    doc.getBlockMap(plan.nextRowId!.value)?[BlockFields.prevSiblingId] =
        plan.newRowId.value;
    doc.markDirty(plan.nextRowId!.value);
  }
  if (plan.prevRowId == null || plan.nextRowId == null) {
    final yTable = doc.getBlockMap(plan.tableId.value);
    if (yTable != null) {
      if (plan.prevRowId == null)
        yTable[BlockFields.firstChildId] = plan.newRowId.value;
      if (plan.nextRowId == null)
        yTable[BlockFields.lastChildId] = plan.newRowId.value;
      doc.markDirty(plan.tableId.value);
    }
  }

  if (plan.headerAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.headerAttrs!);
  }
}
