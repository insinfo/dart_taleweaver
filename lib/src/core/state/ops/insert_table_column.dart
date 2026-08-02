/// Insert table column.
///
/// Port of `ops/insert-table-column.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../table_column_widths.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'set_block_attrs.dart';

enum ColumnPosition { left, right }

class _InsertTableColumnRow {
  final BlockId rowId;
  final BlockId cellId;
  final BlockId paragraphId;
  final BlockId? prevCellId;
  final BlockId? nextCellId;

  const _InsertTableColumnRow({
    required this.rowId,
    required this.cellId,
    required this.paragraphId,
    this.prevCellId,
    this.nextCellId,
  });
}

class InsertTableColumnPlan {
  final BlockId tableId;
  final int targetCol;
  final List<_InsertTableColumnRow> rows;
  final ReadonlyAttrs? newTableAttrs;

  const InsertTableColumnPlan({
    required this.tableId,
    required this.targetCol,
    required this.rows,
    this.newTableAttrs,
  });
}

OperationResult insertTableColumn(
  State state,
  TableContext ctx,
  ColumnPosition position,
  IdAllocator allocator,
) {
  final plan = planInsertTableColumn(state, ctx, position, allocator);
  return applyOperation(state, (doc) {
    insertTableColumnInTx(doc, plan);
  });
}

InsertTableColumnPlan planInsertTableColumn(
  State state,
  TableContext ctx,
  ColumnPosition position,
  IdAllocator allocator,
) {
  final targetCol = position == ColumnPosition.left ? ctx.colIndex : ctx.colIndex + 1;

  final rows = <_InsertTableColumnRow>[];
  for (int r = 0; r < ctx.rowIds.length; r++) {
    final rowId = ctx.rowIds[r];
    final cells = ctx.cellIdsByRow[r];
    final prevCellId = targetCol == 0 ? null : (targetCol - 1 < cells.length ? cells[targetCol - 1] : null);
    final nextCellId = targetCol < cells.length ? cells[targetCol] : null;
    
    rows.add(_InsertTableColumnRow(
      rowId: rowId,
      cellId: allocator.allocate(),
      paragraphId: allocator.allocate(),
      prevCellId: prevCellId,
      nextCellId: nextCellId,
    ));
  }

  final table = getBlock(state, ctx.tableId);
  final cw = table?.attrs['columnWidths'];
  ReadonlyAttrs? newTableAttrs;
  
  if (table != null && isColumnWidths(cw)) {
    newTableAttrs = Map<String, dynamic>.of(table.attrs);
    newTableAttrs['columnWidths'] = spliceColumnWidth(parseColumnWidths(cw), targetCol);
  }

  return InsertTableColumnPlan(
    tableId: ctx.tableId,
    targetCol: targetCol,
    rows: rows,
    newTableAttrs: newTableAttrs,
  );
}

void insertTableColumnInTx(TwDoc doc, InsertTableColumnPlan plan) {
  for (final r in plan.rows) {
    doc.setBlockMap(r.cellId.value, {
      BlockFields.type: 'table-cell',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: r.rowId.value,
      if (r.prevCellId != null) BlockFields.prevSiblingId: r.prevCellId!.value,
      if (r.nextCellId != null) BlockFields.nextSiblingId: r.nextCellId!.value,
      BlockFields.firstChildId: r.paragraphId.value,
      BlockFields.lastChildId: r.paragraphId.value,
    });
    
    doc.setBlockMap(r.paragraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: r.cellId.value,
      BlockFields.inlineContent: const InlineContent([]),
    });

    if (r.prevCellId != null) {
      doc.getBlockMap(r.prevCellId!.value)?[BlockFields.nextSiblingId] = r.cellId.value;
      doc.markDirty(r.prevCellId!.value);
    }
    if (r.nextCellId != null) {
      doc.getBlockMap(r.nextCellId!.value)?[BlockFields.prevSiblingId] = r.cellId.value;
      doc.markDirty(r.nextCellId!.value);
    }
    
    if (r.prevCellId == null || r.nextCellId == null) {
      final yRow = doc.getBlockMap(r.rowId.value);
      if (yRow != null) {
        if (r.prevCellId == null) yRow[BlockFields.firstChildId] = r.cellId.value;
        if (r.nextCellId == null) yRow[BlockFields.lastChildId] = r.cellId.value;
        doc.markDirty(r.rowId.value);
      }
    }
  }

  if (plan.newTableAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.newTableAttrs!);
  }
}
