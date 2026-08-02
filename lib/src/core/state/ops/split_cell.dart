/// Split cell.
///
/// Port of `ops/split-cell.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../table_context.dart';
import '../tw_doc.dart';
import 'set_block_attrs.dart';

class _NewCell {
  final BlockId cellId;
  final BlockId paragraphId;

  const _NewCell({required this.cellId, required this.paragraphId});
}

class _SplitCellRow {
  final BlockId rowId;
  final BlockId? prevCellId;
  final BlockId? nextCellId;
  final List<_NewCell> newCells;

  const _SplitCellRow({
    required this.rowId,
    this.prevCellId,
    this.nextCellId,
    required this.newCells,
  });
}

class SplitCellPlan {
  final BlockId cellId;
  final ReadonlyAttrs survivorAttrs;
  final List<_SplitCellRow> rows;

  const SplitCellPlan({
    required this.cellId,
    required this.survivorAttrs,
    required this.rows,
  });
}

OperationResult splitCell(
  State state,
  TableContext ctx,
  IdAllocator allocator,
) {
  final plan = planSplitCell(state, ctx, allocator);
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }
  return applyOperation(state, (doc) {
    splitCellInTx(doc, plan);
  });
}

SplitCellPlan? planSplitCell(
  State state,
  TableContext ctx,
  IdAllocator allocator,
) {
  final grid = buildTableGrid(state, ctx.tableId);
  if (grid == null) return null;
  final targetIdx = grid.cells.indexWhere((c) => c.cellId == ctx.cellId);
  if (targetIdx == -1) return null;
  final target = grid.cells[targetIdx];
  if (target.rowSpan == 1 && target.colSpan == 1) return null;

  final r0 = target.gridRow;
  final c0 = target.gridCol;
  final lastRow = r0 + target.rowSpan - 1;
  final lastCol = c0 + target.colSpan - 1;

  final cell = getBlock(state, ctx.cellId);
  if (cell == null) return null;
  final survivorAttrs = _dropSpanAttrs(cell.attrs);

  final rows = <_SplitCellRow>[];
  for (var r = r0; r <= lastRow; r++) {
    final startCol = r == r0 ? c0 + 1 : c0;
    if (startCol > lastCol) continue;

    final originating = grid.cells.where((c) => c.gridRow == r).toList()
      ..sort((a, b) => a.gridCol.compareTo(b.gridCol));

    BlockId? prevCellId;
    for (final c in originating) {
      if (c.gridCol < startCol) prevCellId = c.cellId;
    }

    BlockId? nextCellId;
    for (final c in originating) {
      if (c.gridCol > lastCol) {
        nextCellId = c.cellId;
        break;
      }
    }

    final newCells = <_NewCell>[];
    for (var col = startCol; col <= lastCol; col++) {
      newCells.add(_NewCell(
        cellId: allocator.allocate(),
        paragraphId: allocator.allocate(),
      ));
    }

    final rowId = ctx.rowIds[r];
    rows.add(_SplitCellRow(
      rowId: rowId,
      prevCellId: prevCellId,
      nextCellId: nextCellId,
      newCells: newCells,
    ));
  }

  return SplitCellPlan(
    cellId: ctx.cellId,
    survivorAttrs: survivorAttrs,
    rows: rows,
  );
}

ReadonlyAttrs _dropSpanAttrs(ReadonlyAttrs attrs) {
  final next = Map<String, dynamic>.of(attrs);
  next.remove('rowSpan');
  next.remove('colSpan');
  return next;
}

void splitCellInTx(TwDoc doc, SplitCellPlan plan) {
  setBlockAttrsInTx(doc, plan.cellId, plan.survivorAttrs);

  for (final row in plan.rows) {
    final seq = row.newCells;
    for (var i = 0; i < seq.length; i++) {
      final nc = seq[i];
      final prevCell = i > 0 ? seq[i - 1] : null;
      final nextCell = i < seq.length - 1 ? seq[i + 1] : null;
      final prev = i == 0 ? row.prevCellId : prevCell?.cellId;
      final next = i == seq.length - 1 ? row.nextCellId : nextCell?.cellId;
      
      doc.setBlockMap(nc.cellId.value, {
        BlockFields.type: 'table-cell',
        BlockFields.attrs: <String, dynamic>{},
        BlockFields.parentId: row.rowId.value,
        BlockFields.prevSiblingId: prev?.value,
        BlockFields.nextSiblingId: next?.value,
        BlockFields.firstChildId: nc.paragraphId.value,
        BlockFields.lastChildId: nc.paragraphId.value,
        BlockFields.inlineContent: null,
      });
      
      doc.setBlockMap(nc.paragraphId.value, {
        BlockFields.type: 'paragraph',
        BlockFields.attrs: <String, dynamic>{},
        BlockFields.parentId: nc.cellId.value,
        BlockFields.prevSiblingId: null,
        BlockFields.nextSiblingId: null,
        BlockFields.firstChildId: null,
        BlockFields.lastChildId: null,
        BlockFields.inlineContent: const InlineContent([]),
      });
    }

    final first = seq.first.cellId;
    final last = seq.last.cellId;
    
    if (row.prevCellId != null) {
      final yPrev = doc.getBlockMap(row.prevCellId!.value);
      if (yPrev != null) {
        yPrev['nextSiblingId'] = first.value;
        doc.markDirty(row.prevCellId!.value);
      }
    }
    
    if (row.nextCellId != null) {
      final yNext = doc.getBlockMap(row.nextCellId!.value);
      if (yNext != null) {
        yNext['prevSiblingId'] = last.value;
        doc.markDirty(row.nextCellId!.value);
      }
    }
    
    if (row.prevCellId == null || row.nextCellId == null) {
      final yRow = doc.getBlockMap(row.rowId.value);
      if (yRow != null) {
        if (row.prevCellId == null) yRow['firstChildId'] = first.value;
        if (row.nextCellId == null) yRow['lastChildId'] = last.value;
        doc.markDirty(row.rowId.value);
      }
    }
  }
}
