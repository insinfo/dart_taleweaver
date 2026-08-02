/// Delete table row.
///
/// Port of `ops/delete-table-row.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'remove_block.dart';
import 'set_block_attrs.dart';
import 'table_header_rows.dart';

class DeleteTableRowPlan {
  final BlockId tableId;
  final RemoveBlockPlan rowPlan;
  final ReadonlyAttrs? headerAttrs;

  const DeleteTableRowPlan({
    required this.tableId,
    required this.rowPlan,
    this.headerAttrs,
  });
}

OperationResult deleteTableRow(State state, TableContext ctx) {
  final plan = planDeleteTableRow(state, ctx);
  return applyOperation(state, (doc) {
    deleteTableRowInTx(doc, plan);
  });
}

DeleteTableRowPlan planDeleteTableRow(State state, TableContext ctx) {
  final rowPlan = planRemoveBlock(state, ctx.rowId);
  final headerAttrs = headerRowAttrsAfterRowEdit(
      state, ctx.tableId, RowEditOp.delete, ctx.rowIndex);
  return DeleteTableRowPlan(
      tableId: ctx.tableId, rowPlan: rowPlan, headerAttrs: headerAttrs);
}

void deleteTableRowInTx(TwDoc doc, DeleteTableRowPlan plan) {
  if (plan.headerAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.headerAttrs!);
  }
  removeBlockInTx(doc, plan.rowPlan);
}
