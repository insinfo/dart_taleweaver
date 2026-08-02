/// Delete table column.
///
/// Port of `ops/delete-table-column.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_column_widths.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'remove_block.dart';
import 'set_block_attrs.dart';

class DeleteTableColumnPlan {
  final BlockId tableId;
  final List<RemoveBlockPlan> cellPlans;
  final ReadonlyAttrs? newTableAttrs;

  const DeleteTableColumnPlan({
    required this.tableId,
    required this.cellPlans,
    this.newTableAttrs,
  });
}

OperationResult deleteTableColumn(State state, TableContext ctx) {
  final plan = planDeleteTableColumn(state, ctx);
  return applyOperation(state, (doc) {
    deleteTableColumnInTx(doc, plan);
  });
}

DeleteTableColumnPlan planDeleteTableColumn(State state, TableContext ctx) {
  final colIndex = ctx.colIndex;
  final caretRowCells = ctx.cellIdsByRow[ctx.rowIndex];
  final colCount = caretRowCells.length;

  if (colCount <= 1) {
    throw StateError(
        'deleteTableColumn: last column must collapse the whole table');
  }

  final cellPlans = <RemoveBlockPlan>[];
  for (int r = 0; r < ctx.rowIds.length; r++) {
    final rowCells = ctx.cellIdsByRow[r];
    if (colIndex >= rowCells.length) {
      throw StateError('deleteTableColumn: cell missing');
    }
    cellPlans.add(planRemoveBlock(state, rowCells[colIndex]));
  }

  final table = getBlock(state, ctx.tableId);
  final cw = table?.attrs['columnWidths'];
  ReadonlyAttrs? newTableAttrs;

  if (table != null && isColumnWidths(cw)) {
    newTableAttrs = Map<String, dynamic>.of(table.attrs);
    newTableAttrs['columnWidths'] =
        removeColumnWidth(parseColumnWidths(cw), colIndex);
  }

  return DeleteTableColumnPlan(
    tableId: ctx.tableId,
    cellPlans: cellPlans,
    newTableAttrs: newTableAttrs,
  );
}

void deleteTableColumnInTx(TwDoc doc, DeleteTableColumnPlan plan) {
  for (final cellPlan in plan.cellPlans) {
    removeBlockInTx(doc, cellPlan);
  }

  if (plan.newTableAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.newTableAttrs!);
  }
}
