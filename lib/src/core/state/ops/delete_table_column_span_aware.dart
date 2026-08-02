/// Delete table column span aware.
///
/// Port of `ops/delete-table-column-span-aware.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_column_widths.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'remove_block.dart';
import 'set_block_attrs.dart';

class _DeleteTableColumnSpanAwareBump {
  final BlockId cellId;
  final ReadonlyAttrs newAttrs;

  const _DeleteTableColumnSpanAwareBump(this.cellId, this.newAttrs);
}

class _DeleteTableColumnSpanAwareRemovedCell {
  final BlockId rowId;
  final BlockId cellId;
  final BlockId? prevSiblingId;
  final BlockId? nextSiblingId;
  final bool removingFirstChild;
  final bool removingLastChild;

  const _DeleteTableColumnSpanAwareRemovedCell({
    required this.rowId,
    required this.cellId,
    this.prevSiblingId,
    this.nextSiblingId,
    required this.removingFirstChild,
    required this.removingLastChild,
  });
}

class DeleteTableColumnSpanAwarePlan {
  final BlockId tableId;
  final List<_DeleteTableColumnSpanAwareBump> spanBumps;
  final List<_DeleteTableColumnSpanAwareRemovedCell> removedCells;
  final Set<BlockId> blockIdsToDelete;
  final Set<BlockId> embedContentIdsToDelete;
  final ReadonlyAttrs? newTableAttrs;

  const DeleteTableColumnSpanAwarePlan({
    required this.tableId,
    required this.spanBumps,
    required this.removedCells,
    required this.blockIdsToDelete,
    required this.embedContentIdsToDelete,
    this.newTableAttrs,
  });
}

OperationResult deleteTableColumnSpanAware(State state, TableContext ctx) {
  final plan = planDeleteTableColumnSpanAware(state, ctx);
  if (plan == null) return OperationResult(state: state, dirtyIds: {});
  return applyOperation(state, (doc) {
    deleteTableColumnSpanAwareInTx(doc, plan);
  });
}

DeleteTableColumnSpanAwarePlan? planDeleteTableColumnSpanAware(State state, TableContext ctx) {
  final grid = buildTableGrid(state, ctx.tableId);
  if (grid == null) return null;
  final caretList = grid.cells.where((c) => c.cellId == ctx.cellId);
  if (caretList.isEmpty) return null;
  final caret = caretList.first;

  final columnCount = grid.columnCount;
  if (columnCount <= 1) return null;
  final gc = caret.gridCol;

  final spanBumps = <_DeleteTableColumnSpanAwareBump>[];
  final removedCells = <_DeleteTableColumnSpanAwareRemovedCell>[];
  final blockIdsToDelete = <BlockId>{};
  final embedContentIdsToDelete = <BlockId>{};

  for (final c in grid.cells) {
    if (c.gridCol < gc && c.gridCol + c.colSpan - 1 >= gc) {
      spanBumps.add(_DeleteTableColumnSpanAwareBump(c.cellId, _withColSpan(state, c.cellId, c.colSpan - 1)));
    } else if (c.gridCol == gc) {
      if (c.colSpan > 1) {
        spanBumps.add(_DeleteTableColumnSpanAwareBump(c.cellId, _withColSpan(state, c.cellId, c.colSpan - 1)));
      } else {
        final p = planRemoveBlock(state, c.cellId);
        removedCells.add(_DeleteTableColumnSpanAwareRemovedCell(
          rowId: p.parentId,
          cellId: c.cellId,
          prevSiblingId: p.prevSiblingId,
          nextSiblingId: p.nextSiblingId,
          removingFirstChild: p.removingFirstChild,
          removingLastChild: p.removingLastChild,
        ));
        blockIdsToDelete.addAll(p.subtreeIds);
        embedContentIdsToDelete.addAll(p.embedContentIds);
      }
    }
  }

  final table = getBlock(state, ctx.tableId);
  final cw = table?.attrs['columnWidths'];
  ReadonlyAttrs? newTableAttrs;
  if (table != null && isColumnWidths(cw)) {
    newTableAttrs = Map<String, dynamic>.of(table.attrs);
    newTableAttrs['columnWidths'] = removeColumnWidth(parseColumnWidths(cw), gc);
  }

  return DeleteTableColumnSpanAwarePlan(
    tableId: ctx.tableId,
    spanBumps: spanBumps,
    removedCells: removedCells,
    blockIdsToDelete: blockIdsToDelete,
    embedContentIdsToDelete: embedContentIdsToDelete,
    newTableAttrs: newTableAttrs,
  );
}

ReadonlyAttrs _withColSpan(State state, BlockId cellId, int n) {
  final block = getBlock(state, cellId);
  final next = Map<String, dynamic>.of(block?.attrs ?? {});
  if (n > 1) {
    next['colSpan'] = n;
  } else {
    next.remove('colSpan');
  }
  return next;
}

void deleteTableColumnSpanAwareInTx(TwDoc doc, DeleteTableColumnSpanAwarePlan plan) {
  for (final bump in plan.spanBumps) {
    setBlockAttrsInTx(doc, bump.cellId, bump.newAttrs);
  }

  for (final rc in plan.removedCells) {
    if (rc.prevSiblingId != null) {
      doc.getBlockMap(rc.prevSiblingId!.value)?['nextSiblingId'] = rc.nextSiblingId?.value;
      doc.markDirty(rc.prevSiblingId!.value);
    }
    if (rc.nextSiblingId != null) {
      doc.getBlockMap(rc.nextSiblingId!.value)?['prevSiblingId'] = rc.prevSiblingId?.value;
      doc.markDirty(rc.nextSiblingId!.value);
    }
    if (rc.removingFirstChild || rc.removingLastChild) {
      final yRow = doc.getBlockMap(rc.rowId.value);
      if (yRow != null) {
        if (rc.removingFirstChild) yRow['firstChildId'] = rc.nextSiblingId?.value;
        if (rc.removingLastChild) yRow['lastChildId'] = rc.prevSiblingId?.value;
        doc.markDirty(rc.rowId.value);
      }
    }
  }

  if (plan.embedContentIdsToDelete.isNotEmpty) {
    for (final id in plan.embedContentIdsToDelete) {
      doc.deleteEmbedContent(id.value);
    }
  }
  for (final id in plan.blockIdsToDelete) {
    doc.deleteBlock(id.value);
  }

  if (plan.newTableAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.newTableAttrs!);
  }
}
