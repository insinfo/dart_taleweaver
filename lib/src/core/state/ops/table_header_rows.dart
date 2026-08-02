/// Table header rows logic.
///
/// Port of `ops/table-header-rows.ts`.
library;

import 'dart:math';
import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_grid_core.dart';

int largestCleanHeaderCount(TableGrid grid, int requested) {
  final rowCount = grid.occupancy.length;
  final clamped = max(0, min(requested, rowCount));
  for (int count = clamped; count > 0; count--) {
    final straddles = grid.cells.any(
      (cell) => cell.gridRow < count && cell.gridRow + cell.rowSpan > count,
    );
    if (!straddles) return count;
  }
  return 0;
}

enum RowEditOp { insert, delete }

int adjustHeaderRowCount(int count, RowEditOp op, int rowIndex) {
  if (op == RowEditOp.delete) {
    return rowIndex < count ? count - 1 : count;
  }
  return rowIndex < count ? count + 1 : count;
}

ReadonlyAttrs? headerRowAttrsAfterRowEdit(
  State state,
  BlockId tableId,
  RowEditOp op,
  int rowIndex,
) {
  final table = getBlock(state, tableId);
  if (table == null) return null;
  final current = readHeaderRowCount(table.attrs);
  final next = adjustHeaderRowCount(current, op, rowIndex);
  if (next == current) return null;
  return withHeaderRowCount(table.attrs, next);
}

int readHeaderRowCount(ReadonlyAttrs attrs) {
  final v = attrs['headerRowCount'];
  if (v is int && v > 0) return v;
  if (v is double && v.isFinite && v.truncateToDouble() == v && v > 0) return v.toInt();
  return 0;
}

ReadonlyAttrs withHeaderRowCount(ReadonlyAttrs attrs, int count) {
  final next = Map<String, dynamic>.of(attrs);
  if (count > 0) {
    next['headerRowCount'] = count;
  } else {
    next.remove('headerRowCount');
  }
  return next;
}
