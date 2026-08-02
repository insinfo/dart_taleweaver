/// Create table tree generation.
///
/// Port of `ops/create-table.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';
import 'split_block.dart';

class TableCellPlan {
  final BlockId cellId;
  final BlockId paragraphId;

  const TableCellPlan({required this.cellId, required this.paragraphId});
}

class TableRowPlan {
  final BlockId rowId;
  final List<TableCellPlan> cells;

  const TableRowPlan({required this.rowId, required this.cells});
}

class TableSubtreePlan {
  final BlockId tableId;
  final List<double> columnWidths;
  final List<TableRowPlan> rows;

  const TableSubtreePlan({
    required this.tableId,
    required this.columnWidths,
    required this.rows,
  });
}

class CreateTablePlan {
  final TableSubtreePlan subtree;
  final BlockId parentId;
  final BlockId? afterId;
  final BlockId? beforeId;
  final SplitBlockPlan? split;
  final Position caretInto;

  const CreateTablePlan({
    required this.subtree,
    required this.parentId,
    this.afterId,
    this.beforeId,
    this.split,
    required this.caretInto,
  });
}

TableSubtreePlan buildTableSubtreePlan(
  int rows,
  int cols,
  IdAllocator allocator,
) {
  if (rows < 1 || cols < 1) {
    throw ArgumentError('createTable: minimum 1x1, got ${rows}x$cols');
  }

  final tableId = allocator.allocate();
  final rowPlans = <TableRowPlan>[];
  for (int r = 0; r < rows; r++) {
    final rowId = allocator.allocate();
    final cells = <TableCellPlan>[];
    for (int c = 0; c < cols; c++) {
      cells.add(TableCellPlan(
        cellId: allocator.allocate(),
        paragraphId: allocator.allocate(),
      ));
    }
    rowPlans.add(TableRowPlan(rowId: rowId, cells: cells));
  }

  final width = 1.0 / cols;
  final columnWidths = List.generate(cols, (_) => width);

  return TableSubtreePlan(
    tableId: tableId,
    columnWidths: columnWidths,
    rows: rowPlans,
  );
}

class CreateTableResult {
  final OperationResult result;
  final BlockId newTableId;
  final Position caretInto;

  const CreateTableResult({
    required this.result,
    required this.newTableId,
    required this.caretInto,
  });
}

CreateTableResult createTable(
  State state,
  Position caretPosition,
  int rows,
  int cols,
  IdAllocator allocator,
) {
  final plan = planCreateTable(state, caretPosition, rows, cols, allocator);
  final result = applyOperation(state, (doc) {
    createTableInTx(doc, plan);
  });
  return CreateTableResult(
    result: result,
    newTableId: plan.subtree.tableId,
    caretInto: plan.caretInto,
  );
}

CreateTablePlan planCreateTable(
  State state,
  Position caretPosition,
  int rows,
  int cols,
  IdAllocator allocator,
) {
  final resolved = resolveBlock(state, caretPosition.blockId);
  if (resolved == null) {
    throw StateError('createTable: block "${caretPosition.blockId}" not found');
  }
  if (resolved.kind != ResolvedBlockKind.main) {
    throw StateError(
        'createTable: tables are supported in the main document body only');
  }

  final block = resolved.block;
  if (block.inlineContent == null || block.firstChildId != null) {
    throw StateError(
        'createTable: block "${caretPosition.blockId}" is a container, not a leaf');
  }
  if (block.parentId == null) {
    throw StateError(
        'createTable: block "${caretPosition.blockId}" is the root and has no parent');
  }

  final length = inlineContentLength(block.inlineContent!);

  SplitBlockPlan? split;
  BlockId? afterId;
  BlockId? beforeId;

  if (caretPosition.offset <= 0) {
    afterId = block.prevSiblingId;
    beforeId = caretPosition.blockId;
  } else if (caretPosition.offset >= length) {
    afterId = caretPosition.blockId;
    beforeId = block.nextSiblingId;
  } else {
    split = planSplitBlockAtPosition(state, caretPosition, allocator);
    afterId = caretPosition.blockId;
    beforeId = split.newBlockId;
  }

  final subtree = buildTableSubtreePlan(rows, cols, allocator);
  final caretInto = Position(
    blockId: subtree.rows.first.cells.first.paragraphId,
    offset: 0,
  );

  return CreateTablePlan(
    subtree: subtree,
    parentId: block.parentId!,
    afterId: afterId,
    beforeId: beforeId,
    split: split,
    caretInto: caretInto,
  );
}

void createTableInTx(TwDoc doc, CreateTablePlan plan) {
  if (plan.split != null) {
    splitBlockAtPositionInTx(doc, plan.split!);
  }

  final tableId = plan.subtree.tableId;
  final columnWidths = plan.subtree.columnWidths;
  final rows = plan.subtree.rows;

  final lastRow = rows.length - 1;
  for (int r = 0; r < rows.length; r++) {
    final row = rows[r];
    final lastCell = row.cells.length - 1;

    for (int c = 0; c < row.cells.length; c++) {
      final cell = row.cells[c];
      final prevCell = c == 0 ? null : row.cells[c - 1];
      final nextCell = c == lastCell ? null : row.cells[c + 1];

      doc.setBlockMap(cell.cellId.value, {
        BlockFields.type: 'table-cell',
        BlockFields.attrs: <String, dynamic>{},
        BlockFields.parentId: row.rowId.value,
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

    final prevRow = r == 0 ? null : rows[r - 1];
    final nextRow = r == lastRow ? null : rows[r + 1];
    doc.setBlockMap(row.rowId.value, {
      BlockFields.type: 'table-row',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: tableId.value,
      if (prevRow != null) BlockFields.prevSiblingId: prevRow.rowId.value,
      if (nextRow != null) BlockFields.nextSiblingId: nextRow.rowId.value,
      BlockFields.firstChildId: row.cells.first.cellId.value,
      BlockFields.lastChildId: row.cells.last.cellId.value,
    });
  }

  doc.setBlockMap(tableId.value, {
    BlockFields.type: 'table',
    BlockFields.attrs: <String, dynamic>{
      'columnWidths': [...columnWidths]
    },
    BlockFields.parentId: plan.parentId.value,
    if (plan.afterId != null) BlockFields.prevSiblingId: plan.afterId!.value,
    if (plan.beforeId != null) BlockFields.nextSiblingId: plan.beforeId!.value,
    BlockFields.firstChildId: rows.first.rowId.value,
    BlockFields.lastChildId: rows.last.rowId.value,
  });

  if (plan.afterId != null) {
    doc.getBlockMap(plan.afterId!.value)?[BlockFields.nextSiblingId] =
        tableId.value;
    doc.markDirty(plan.afterId!.value);
  } else {
    doc.getBlockMap(plan.parentId.value)?[BlockFields.firstChildId] =
        tableId.value;
  }

  if (plan.beforeId != null) {
    doc.getBlockMap(plan.beforeId!.value)?[BlockFields.prevSiblingId] =
        tableId.value;
    doc.markDirty(plan.beforeId!.value);
  } else {
    doc.getBlockMap(plan.parentId.value)?[BlockFields.lastChildId] =
        tableId.value;
  }
  doc.markDirty(plan.parentId.value);
}
