/// Geometry composition for the print table formatting context.
library;

import '../../render/layout_metadata.dart';
import '../../state/block_id.dart';
import '../../styles/writing_mode.dart';
import 'layout_box.dart';
import 'table_grid.dart';

class TableCellInput {
  final BlockId key;
  final LayoutBox box;
  final LayoutBoxMetadata? metadata;
  const TableCellInput(this.key, this.box, [this.metadata]);
}

TableBox composeTableLayout({
  required String key,
  required List<List<TableCellInput>> rows,
  required double inlineSize,
  required WritingMode writingMode,
  required Direction direction,
  List<double>? columnWidths,
  int headerRowCount = 0,
  dynamic computedStyle,
  dynamic usedStyle,
}) {
  final grid = assignPrintTableGrid([
    for (final row in rows)
      [for (final cell in row) GridCellInput(cell.key, cell.metadata)],
  ]);
  final widths = _normalizeWidths(columnWidths, grid.columnCount, inlineSize);
  final heights = List<double>.filled(rows.length, 0);
  final byId = <BlockId, TableCellInput>{
    for (final row in rows)
      for (final cell in row) cell.key: cell,
  };
  for (final placement in grid.cells) {
    final input = byId[placement.cellId];
    if (input == null) continue;
    final perRow = input.box.blockSize / placement.rowSpan;
    for (var row = placement.gridRow;
        row < placement.gridRow + placement.rowSpan && row < heights.length;
        row++) {
      if (perRow > heights[row]) heights[row] = perRow;
    }
  }
  final xOffsets = _offsets(widths);
  final yOffsets = _offsets(heights);
  final cellsByRow = List.generate(rows.length, (_) => <LayoutBox>[]);
  for (final placement in grid.cells) {
    final input = byId[placement.cellId];
    if (input == null) continue;
    final cellWidth = _sum(widths, placement.gridCol, placement.colSpan);
    final cellHeight = _sum(heights, placement.gridRow, placement.rowSpan);
    cellsByRow[placement.gridRow].add(TableCellBox(
        key: input.box.key,
        inlineOffset: xOffsets[placement.gridCol],
        blockOffset: yOffsets[placement.gridRow],
        inlineSize: cellWidth,
        blockSize: cellHeight,
        x: xOffsets[placement.gridCol],
        y: yOffsets[placement.gridRow],
        width: cellWidth,
        height: cellHeight,
        writingMode: writingMode,
        direction: direction,
        computedStyle: input.box.computedStyle,
        usedStyle: input.box.usedStyle,
        children: input.box is BlockBox
            ? (input.box as BlockBox).children
            : [input.box],
        rowSpan: placement.rowSpan,
        colSpan: placement.colSpan));
  }
  final rowBoxes = <LayoutBox>[];
  for (var row = 0; row < rows.length; row++) {
    rowBoxes.add(TableRowBox(
        key: '$key-row-$row',
        inlineOffset: 0,
        blockOffset: yOffsets[row],
        inlineSize: inlineSize,
        blockSize: heights[row],
        x: 0,
        y: yOffsets[row],
        width: inlineSize,
        height: heights[row],
        writingMode: writingMode,
        direction: direction,
        children: cellsByRow[row]));
  }
  return TableBox(
      key: key,
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: inlineSize,
      blockSize: _sum(heights, 0, heights.length),
      x: 0,
      y: 0,
      width: inlineSize,
      height: _sum(heights, 0, heights.length),
      writingMode: writingMode,
      direction: direction,
      computedStyle: computedStyle,
      usedStyle: usedStyle,
      children: rowBoxes,
      columnWidths: widths,
      rowHeights: heights,
      headerRowCount: headerRowCount);
}

List<double> _normalizeWidths(List<double>? input, int count, double total) {
  if (count <= 0) return const [];
  final widths = List<double>.generate(
      count, (i) => input != null && i < input.length ? input[i] : 0);
  final specified = widths.fold(0.0, (sum, value) => sum + value);
  final missing = widths.where((value) => value <= 0).length;
  final remainder = (total - specified).clamp(0, double.infinity).toDouble();
  final fallback = missing > 0 ? remainder / missing : 0.0;
  for (var i = 0; i < widths.length; i++) {
    if (widths[i] <= 0) widths[i] = fallback;
  }
  if (widths.every((value) => value == 0)) {
    final equal = total / count;
    for (var i = 0; i < widths.length; i++) widths[i] = equal;
  }
  return widths;
}

List<double> _offsets(List<double> values) {
  final result = List<double>.filled(values.length, 0);
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    result[i] = sum;
    sum += values[i];
  }
  return result;
}

double _sum(List<double> values, int start, int span) {
  var result = 0.0;
  for (var i = start; i < start + span && i < values.length; i++) {
    result += values[i];
  }
  return result;
}
