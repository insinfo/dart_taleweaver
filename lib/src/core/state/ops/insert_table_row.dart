/// Insert table row.
///
/// Port of `ops/insert-table-row.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'set_block_attrs.dart';
import 'table_header_rows.dart';

enum RowPosition { above, below }

class _InsertTableRowCell {
  final BlockId cellId;
  final BlockId paragraphId;
  const _InsertTableRowCell(this.cellId, this.paragraphId);
}

class InsertTableRowPlan {
  final BlockId tableId;
  final BlockId rowId;
  final BlockId? prevRowId;
  final BlockId? nextRowId;
  final List<_InsertTableRowCell> cells;
  final ReadonlyAttrs? headerAttrs;

  const InsertTableRowPlan({
    required this.tableId,
    required this.rowId,
    this.prevRowId,
    this.nextRowId,
    required this.cells,
    this.headerAttrs,
  });
}

class InsertTableRowResult {
  final OperationResult result;
  final BlockId newRowId;

  const InsertTableRowResult(this.result, this.newRowId);
}

InsertTableRowResult insertTableRow(
  State state,
  TableContext ctx,
  RowPosition position,
  IdAllocator allocator,
) {
  final plan = planInsertTableRow(state, ctx, position, allocator);
  final result = applyOperation(state, (doc) {
    insertTableRowInTx(doc, plan);
  });
  return InsertTableRowResult(result, plan.rowId);
}

InsertTableRowPlan planInsertTableRow(
  State state,
  TableContext ctx,
  RowPosition position,
  IdAllocator allocator,
) {
  final caretRowCells = ctx.cellIdsByRow[ctx.rowIndex];
  final colCount = caretRowCells.length;
  if (colCount == 0) {
    throw StateError('insertTableRow: caret row has no cells');
  }

  final prevRowId = position == RowPosition.above
      ? (ctx.rowIndex - 1 >= 0 ? ctx.rowIds[ctx.rowIndex - 1] : null)
      : ctx.rowId;
  
  final nextRowId = position == RowPosition.above
      ? ctx.rowId
      : (ctx.rowIndex + 1 < ctx.rowIds.length ? ctx.rowIds[ctx.rowIndex + 1] : null);

  final rowId = allocator.allocate();
  final cells = List.generate(colCount, (_) => _InsertTableRowCell(
    allocator.allocate(),
    allocator.allocate(),
  ));

  final destIndex = position == RowPosition.above ? ctx.rowIndex : ctx.rowIndex + 1;
  final headerAttrs = headerRowAttrsAfterRowEdit(state, ctx.tableId, RowEditOp.insert, destIndex);

  return InsertTableRowPlan(
    tableId: ctx.tableId,
    rowId: rowId,
    prevRowId: prevRowId,
    nextRowId: nextRowId,
    cells: cells,
    headerAttrs: headerAttrs,
  );
}

void insertTableRowInTx(TwDoc doc, InsertTableRowPlan plan) {
  final lastCell = plan.cells.length - 1;
  for (int i = 0; i < plan.cells.length; i++) {
    final cell = plan.cells[i];
    final prevCell = i == 0 ? null : plan.cells[i - 1];
    final nextCell = i == lastCell ? null : plan.cells[i + 1];

    doc.setBlockMap(cell.cellId.value, {
      BlockFields.type: 'table-cell',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: plan.rowId.value,
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

  final firstCell = plan.cells.first;
  final lastCellEntry = plan.cells.last;

  doc.setBlockMap(plan.rowId.value, {
    BlockFields.type: 'table-row',
    BlockFields.attrs: <String, dynamic>{},
    BlockFields.parentId: plan.tableId.value,
    if (plan.prevRowId != null) BlockFields.prevSiblingId: plan.prevRowId!.value,
    if (plan.nextRowId != null) BlockFields.nextSiblingId: plan.nextRowId!.value,
    BlockFields.firstChildId: firstCell.cellId.value,
    BlockFields.lastChildId: lastCellEntry.cellId.value,
  });

  if (plan.prevRowId != null) {
    doc.getBlockMap(plan.prevRowId!.value)?[BlockFields.nextSiblingId] = plan.rowId.value;
    doc.markDirty(plan.prevRowId!.value);
  }
  if (plan.nextRowId != null) {
    doc.getBlockMap(plan.nextRowId!.value)?[BlockFields.prevSiblingId] = plan.rowId.value;
    doc.markDirty(plan.nextRowId!.value);
  }
  
  if (plan.prevRowId == null || plan.nextRowId == null) {
    final yTable = doc.getBlockMap(plan.tableId.value);
    if (yTable != null) {
      if (plan.prevRowId == null) yTable[BlockFields.firstChildId] = plan.rowId.value;
      if (plan.nextRowId == null) yTable[BlockFields.lastChildId] = plan.rowId.value;
      doc.markDirty(plan.tableId.value);
    }
  }

  if (plan.headerAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.headerAttrs!);
  }
}
