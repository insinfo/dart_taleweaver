/// Merge cells.
///
/// Port of `ops/merge-cells.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';
import '../table_cell_range.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'set_block_attrs.dart';

class _RowChain {
  final BlockId rowId;
  final List<BlockId> cellIds;

  const _RowChain(this.rowId, this.cellIds);
}

class MergeCellsPlan {
  final BlockId survivorId;
  final ReadonlyAttrs survivorAttrs;
  final BlockId? survivorOrigLastChildId;
  final List<BlockId> migratedChildIds;
  final List<_RowChain> rowChains;
  final List<BlockId> donorCellIds;
  final List<BlockId> deletedChildIds;

  const MergeCellsPlan({
    required this.survivorId,
    required this.survivorAttrs,
    required this.survivorOrigLastChildId,
    required this.migratedChildIds,
    required this.rowChains,
    required this.donorCellIds,
    required this.deletedChildIds,
  });
}

OperationResult mergeCells(State state, CellRange range) {
  final plan = planMergeCells(state, range);
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }
  return applyOperation(state, (doc) {
    mergeCellsInTx(doc, plan);
  });
}

MergeCellsPlan? planMergeCells(State state, CellRange range) {
  final grid = buildTableGrid(state, range.tableId);
  if (grid == null) return null;

  bool inRange(int gridRow, int gridCol) {
    return gridRow >= range.minRow &&
        gridRow <= range.maxRow &&
        gridCol >= range.minCol &&
        gridCol <= range.maxCol;
  }

  final survivorIdx = grid.cells.indexWhere(
      (c) => c.gridRow == range.minRow && c.gridCol == range.minCol);
  if (survivorIdx == -1) return null;
  final survivor = grid.cells[survivorIdx];

  final donors = grid.cells
      .where(
          (c) => c.cellId != survivor.cellId && inRange(c.gridRow, c.gridCol))
      .toList();
  donors.sort((a, b) {
    final dr = a.gridRow.compareTo(b.gridRow);
    if (dr != 0) return dr;
    return a.gridCol.compareTo(b.gridCol);
  });

  if (donors.isEmpty) return null;

  final survivorBlock = getBlock(state, survivor.cellId);
  if (survivorBlock == null) return null;

  final newRowSpan = range.maxRow - range.minRow + 1;
  final newColSpan = range.maxCol - range.minCol + 1;
  final survivorAttrs = _withSpan(survivorBlock.attrs, newRowSpan, newColSpan);

  final migratedChildIds = <BlockId>[];
  final deletedChildIds = <BlockId>[];
  final donorCellIds = <BlockId>[];

  for (final donor in donors) {
    donorCellIds.add(donor.cellId);
    final children = getChildIds(state, donor.cellId);
    if (_isSingleEmptyParagraph(state, children)) {
      deletedChildIds.addAll(children);
    } else {
      migratedChildIds.addAll(children);
    }
  }

  final rowIds = getChildIds(state, range.tableId)
      .where((id) => getBlock(state, id)?.type == 'table-row')
      .toList();

  final donorIdSet = donorCellIds.toSet();
  final rowChains = <_RowChain>[];

  for (var r = range.minRow; r <= range.maxRow; r++) {
    if (r >= rowIds.length) continue;
    final rowId = rowIds[r];

    final remaining = grid.cells
        .where((c) => c.gridRow == r && !donorIdSet.contains(c.cellId))
        .toList()
      ..sort((a, b) => a.gridCol.compareTo(b.gridCol));

    rowChains.add(_RowChain(rowId, remaining.map((c) => c.cellId).toList()));
  }

  return MergeCellsPlan(
    survivorId: survivor.cellId,
    survivorAttrs: survivorAttrs,
    survivorOrigLastChildId: survivorBlock.lastChildId,
    migratedChildIds: migratedChildIds,
    rowChains: rowChains,
    donorCellIds: donorCellIds,
    deletedChildIds: deletedChildIds,
  );
}

ReadonlyAttrs _withSpan(ReadonlyAttrs attrs, int rowSpan, int colSpan) {
  final next = Map<String, dynamic>.of(attrs);
  next.remove('rowSpan');
  next.remove('colSpan');
  if (rowSpan > 1) next['rowSpan'] = rowSpan;
  if (colSpan > 1) next['colSpan'] = colSpan;
  return next;
}

bool _isSingleEmptyParagraph(State state, List<BlockId> childIds) {
  if (childIds.length != 1) return false;
  final onlyChildId = childIds.first;
  final only = getBlock(state, onlyChildId);
  if (only == null || only.inlineContent == null) return false;
  return only.inlineContent!.items.isEmpty;
}

void mergeCellsInTx(TwDoc doc, MergeCellsPlan plan) {
  setBlockAttrsInTx(doc, plan.survivorId, plan.survivorAttrs);

  final migrated = plan.migratedChildIds;
  for (var i = 0; i < migrated.length; i++) {
    final childId = migrated[i];
    final yChild = doc.getBlockMap(childId.value);
    if (yChild != null) {
      yChild['parentId'] = plan.survivorId.value;
      yChild['prevSiblingId'] =
          i == 0 ? plan.survivorOrigLastChildId?.value : migrated[i - 1].value;
      yChild['nextSiblingId'] =
          i == migrated.length - 1 ? null : migrated[i + 1].value;
      doc.markDirty(childId.value);
    }
  }

  if (migrated.isNotEmpty) {
    final firstMigrated = migrated.first;
    final lastMigrated = migrated.last;
    final ySurvivor = doc.getBlockMap(plan.survivorId.value);

    if (plan.survivorOrigLastChildId != null) {
      final yOrigLast = doc.getBlockMap(plan.survivorOrigLastChildId!.value);
      if (yOrigLast != null) {
        yOrigLast['nextSiblingId'] = firstMigrated.value;
        doc.markDirty(plan.survivorOrigLastChildId!.value);
      }
    } else if (ySurvivor != null) {
      ySurvivor['firstChildId'] = firstMigrated.value;
    }

    if (ySurvivor != null) {
      ySurvivor['lastChildId'] = lastMigrated.value;
      doc.markDirty(plan.survivorId.value);
    }
  }

  for (final chain in plan.rowChains) {
    final yRow = doc.getBlockMap(chain.rowId.value);
    for (var i = 0; i < chain.cellIds.length; i++) {
      final cellId = chain.cellIds[i];
      final yCell = doc.getBlockMap(cellId.value);
      if (yCell != null) {
        yCell['prevSiblingId'] = i == 0 ? null : chain.cellIds[i - 1].value;
        yCell['nextSiblingId'] =
            i == chain.cellIds.length - 1 ? null : chain.cellIds[i + 1].value;
        doc.markDirty(cellId.value);
      }
    }
    if (yRow != null) {
      yRow['firstChildId'] =
          chain.cellIds.isEmpty ? null : chain.cellIds.first.value;
      yRow['lastChildId'] =
          chain.cellIds.isEmpty ? null : chain.cellIds.last.value;
      doc.markDirty(chain.rowId.value);
    }
  }

  for (final id in plan.donorCellIds) doc.deleteBlock(id.value);
  for (final id in plan.deletedChildIds) doc.deleteBlock(id.value);
}
