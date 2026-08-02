/// Set table header rows.
///
/// Port of `ops/set-table-header-rows.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'table_header_rows.dart';

class SetTableHeaderRowsPlan {
  final BlockId tableId;
  final ReadonlyAttrs newAttrs;
  final bool unchanged;

  const SetTableHeaderRowsPlan({
    required this.tableId,
    required this.newAttrs,
    required this.unchanged,
  });
}

OperationResult setTableHeaderRows(
  State state,
  BlockId tableId,
  int count,
) {
  final plan = planSetTableHeaderRows(state, tableId, count);
  return applyOperation(state, (doc) {
    setTableHeaderRowsInTx(doc, plan);
  });
}

SetTableHeaderRowsPlan planSetTableHeaderRows(
  State state,
  BlockId tableId,
  int count,
) {
  final resolved = resolveBlock(state, tableId);
  if (resolved == null) {
    throw StateError('setTableHeaderRows: block "$tableId" not found');
  }
  if (resolved.kind != ResolvedBlockKind.main || resolved.block.type != 'table') {
    throw StateError('setTableHeaderRows: block "$tableId" is not a table');
  }
  final table = resolved.block;

  final childIds = getChildIds(state, tableId);
  final rowCount = childIds.where((id) {
    final r = resolveBlock(state, id);
    return r?.block.type == 'table-row';
  }).length;

  int inRange = count;
  if (inRange < 0) inRange = 0;
  if (inRange > rowCount) inRange = rowCount;

  int clamped = inRange;
  if (inRange > 0) {
    final grid = buildTableGrid(state, tableId);
    clamped = grid == null ? 0 : largestCleanHeaderCount(grid, inRange);
  }

  final current = readHeaderRowCount(table.attrs);
  final unchanged = clamped == current;

  final newAttrs = withHeaderRowCount(table.attrs, clamped);
  return SetTableHeaderRowsPlan(
    tableId: tableId,
    newAttrs: newAttrs,
    unchanged: unchanged,
  );
}

void setTableHeaderRowsInTx(TwDoc doc, SetTableHeaderRowsPlan plan) {
  if (plan.unchanged) return;
  final yBlock = doc.getBlockMap(plan.tableId.value);
  if (yBlock != null) {
    yBlock['attrs'] = plan.newAttrs;
    doc.markDirty(plan.tableId.value);
  }
}
