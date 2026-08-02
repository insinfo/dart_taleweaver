/// Delete table row span aware.
///
/// Port of `ops/delete-table-row-span-aware.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'remove_block.dart';
import 'set_block_attrs.dart';
import 'table_header_rows.dart';

class _DeleteTableRowSpanAwareBump {
  final BlockId cellId;
  final ReadonlyAttrs newAttrs;
  const _DeleteTableRowSpanAwareBump(this.cellId, this.newAttrs);
}

class _DeleteTableRowSpanAwareReHomeRow {
  final BlockId rowId;
  final List<BlockId> cellIds;
  const _DeleteTableRowSpanAwareReHomeRow(this.rowId, this.cellIds);
}

class DeleteTableRowSpanAwarePlan {
  final BlockId tableId;
  final BlockId deletedRowId;
  final BlockId? prevRowId;
  final BlockId? nextRowId;
  final bool removingFirstRow;
  final bool removingLastRow;
  final Set<BlockId> blockIdsToDelete;
  final Set<BlockId> embedContentIdsToDelete;
  final List<_DeleteTableRowSpanAwareBump> coveringBumps;
  final List<_DeleteTableRowSpanAwareBump> rehomed;
  final _DeleteTableRowSpanAwareReHomeRow? reHomeRow;
  final ReadonlyAttrs? headerAttrs;

  const DeleteTableRowSpanAwarePlan({
    required this.tableId,
    required this.deletedRowId,
    this.prevRowId,
    this.nextRowId,
    required this.removingFirstRow,
    required this.removingLastRow,
    required this.blockIdsToDelete,
    required this.embedContentIdsToDelete,
    required this.coveringBumps,
    required this.rehomed,
    this.reHomeRow,
    this.headerAttrs,
  });
}

OperationResult deleteTableRowSpanAware(State state, TableContext ctx) {
  final plan = planDeleteTableRowSpanAware(state, ctx);
  if (plan == null) return OperationResult(state: state, dirtyIds: {});
  return applyOperation(state, (doc) {
    deleteTableRowSpanAwareInTx(doc, plan);
  });
}

DeleteTableRowSpanAwarePlan? planDeleteTableRowSpanAware(
    State state, TableContext ctx) {
  final grid = buildTableGrid(state, ctx.tableId);
  if (grid == null) return null;
  final caretList = grid.cells.where((c) => c.cellId == ctx.cellId);
  if (caretList.isEmpty) return null;
  final caret = caretList.first;

  final rowCount = grid.occupancy.length;
  if (rowCount <= 1) return null;
  final gr = caret.gridRow;

  if (gr >= ctx.rowIds.length) return null;
  final deletedRowId = ctx.rowIds[gr];
  final deletedRow = getBlock(state, deletedRowId);
  if (deletedRow == null) return null;

  final coveringBumps = <_DeleteTableRowSpanAwareBump>[];
  final rehomed = <_DeleteTableRowSpanAwareBump>[];
  final removedCells = <BlockId>[];

  for (final c in grid.cells) {
    if (c.gridRow < gr && c.gridRow + c.rowSpan - 1 >= gr) {
      coveringBumps.add(_DeleteTableRowSpanAwareBump(
          c.cellId, _withRowSpan(state, c.cellId, c.rowSpan - 1)));
    } else if (c.gridRow == gr) {
      if (c.rowSpan > 1) {
        rehomed.add(_DeleteTableRowSpanAwareBump(
            c.cellId, _withRowSpan(state, c.cellId, c.rowSpan - 1)));
      } else {
        removedCells.add(c.cellId);
      }
    }
  }

  final blockIdsToDelete = <BlockId>{deletedRowId};
  final embedContentIdsToDelete = <BlockId>{};

  for (final cellId in removedCells) {
    final p = planRemoveBlock(state, cellId);
    blockIdsToDelete.addAll(p.subtreeIds);
    embedContentIdsToDelete.addAll(p.embedContentIds);
  }

  _DeleteTableRowSpanAwareReHomeRow? reHomeRow;
  if (rehomed.isNotEmpty) {
    if (gr + 1 >= ctx.rowIds.length) return null;
    final reHomeRowId = ctx.rowIds[gr + 1];
    final rehomedIds = rehomed.map((r) => r.cellId).toSet();
    final mergedCells = grid.cells
        .where((c) => c.gridRow == gr + 1 || rehomedIds.contains(c.cellId))
        .toList();
    mergedCells.sort((a, b) => a.gridCol.compareTo(b.gridCol));
    reHomeRow = _DeleteTableRowSpanAwareReHomeRow(
        reHomeRowId, mergedCells.map((c) => c.cellId).toList());
  }

  final table = getBlock(state, ctx.tableId);
  final headerAttrs =
      headerRowAttrsAfterRowEdit(state, ctx.tableId, RowEditOp.delete, gr);

  return DeleteTableRowSpanAwarePlan(
    tableId: ctx.tableId,
    deletedRowId: deletedRowId,
    prevRowId: deletedRow.prevSiblingId,
    nextRowId: deletedRow.nextSiblingId,
    removingFirstRow: table?.firstChildId == deletedRowId,
    removingLastRow: table?.lastChildId == deletedRowId,
    blockIdsToDelete: blockIdsToDelete,
    embedContentIdsToDelete: embedContentIdsToDelete,
    coveringBumps: coveringBumps,
    rehomed: rehomed,
    reHomeRow: reHomeRow,
    headerAttrs: headerAttrs,
  );
}

ReadonlyAttrs _withRowSpan(State state, BlockId cellId, int n) {
  final block = getBlock(state, cellId);
  final next = Map<String, dynamic>.of(block?.attrs ?? {});
  if (n > 1) {
    next['rowSpan'] = n;
  } else {
    next.remove('rowSpan');
  }
  return next;
}

void deleteTableRowSpanAwareInTx(TwDoc doc, DeleteTableRowSpanAwarePlan plan) {
  for (final bump in plan.coveringBumps) {
    setBlockAttrsInTx(doc, bump.cellId, bump.newAttrs);
  }

  for (final rh in plan.rehomed) {
    setBlockAttrsInTx(doc, rh.cellId, rh.newAttrs);
    if (plan.reHomeRow != null) {
      doc.getBlockMap(rh.cellId.value)?['parentId'] =
          plan.reHomeRow!.rowId.value;
      doc.markDirty(rh.cellId.value);
    }
  }

  if (plan.reHomeRow != null) {
    final rowId = plan.reHomeRow!.rowId;
    final cellIds = plan.reHomeRow!.cellIds;
    for (int i = 0; i < cellIds.length; i++) {
      final cellId = cellIds[i];
      final yCell = doc.getBlockMap(cellId.value);
      if (yCell != null) {
        yCell['prevSiblingId'] = i == 0 ? null : cellIds[i - 1].value;
        yCell['nextSiblingId'] =
            i == cellIds.length - 1 ? null : cellIds[i + 1].value;
        doc.markDirty(cellId.value);
      }
    }
    final yRow = doc.getBlockMap(rowId.value);
    if (yRow != null) {
      yRow['firstChildId'] = cellIds.isEmpty ? null : cellIds.first.value;
      yRow['lastChildId'] = cellIds.isEmpty ? null : cellIds.last.value;
      doc.markDirty(rowId.value);
    }
  }

  if (plan.prevRowId != null) {
    doc.getBlockMap(plan.prevRowId!.value)?['nextSiblingId'] =
        plan.nextRowId?.value;
    doc.markDirty(plan.prevRowId!.value);
  }
  if (plan.nextRowId != null) {
    doc.getBlockMap(plan.nextRowId!.value)?['prevSiblingId'] =
        plan.prevRowId?.value;
    doc.markDirty(plan.nextRowId!.value);
  }
  if (plan.removingFirstRow || plan.removingLastRow) {
    final yTable = doc.getBlockMap(plan.tableId.value);
    if (yTable != null) {
      if (plan.removingFirstRow) yTable['firstChildId'] = plan.nextRowId?.value;
      if (plan.removingLastRow) yTable['lastChildId'] = plan.prevRowId?.value;
      doc.markDirty(plan.tableId.value);
    }
  }

  if (plan.headerAttrs != null) {
    setBlockAttrsInTx(doc, plan.tableId, plan.headerAttrs!);
  }

  if (plan.embedContentIdsToDelete.isNotEmpty) {
    for (final id in plan.embedContentIdsToDelete) {
      doc.deleteEmbedContent(id.value);
    }
  }
  for (final id in plan.blockIdsToDelete) {
    doc.deleteBlock(id.value);
  }
}
