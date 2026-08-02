import 'package:test/test.dart';
import 'package:taleweaver/src/core/print/layout/table_column_sizing.dart';
import 'package:taleweaver/src/core/print/layout/table_grid.dart';
import 'package:taleweaver/src/core/print/layout/table_layout.dart';
import 'package:taleweaver/src/core/render/layout_metadata.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/styles/writing_mode.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';

void main() {
  test('print table grid places row and column spans deterministically', () {
    final grid = assignPrintTableGrid([
      [
        const GridCellInput(BlockId('a'), LayoutBoxMetadata(colSpan: 2)),
        const GridCellInput(BlockId('b')),
      ],
      [
        const GridCellInput(BlockId('c')),
        const GridCellInput(BlockId('d')),
        const GridCellInput(BlockId('e')),
      ],
    ]);
    expect(grid.columnCount, 3);
    expect(grid.occupancy[0],
        [const BlockId('a'), const BlockId('a'), const BlockId('b')]);
    expect(grid.occupancy[1],
        [const BlockId('c'), const BlockId('d'), const BlockId('e')]);
    expect(
        grid.cells
            .singleWhere((cell) => cell.cellId == const BlockId('a'))
            .colSpan,
        2);
  });

  test('spanning intrinsic constraints distribute shortfall', () {
    final result = distributeColumnIntrinsics([
      const SpannedCellIntrinsic(gridCol: 0, colSpan: 1, min: 10, max: 20),
      const SpannedCellIntrinsic(gridCol: 1, colSpan: 1, min: 5, max: 10),
      const SpannedCellIntrinsic(gridCol: 0, colSpan: 2, min: 40, max: 60),
    ], 2);
    expect(result.colMins.reduce((a, b) => a + b), closeTo(40, 1e-9));
    expect(result.colMaxes.reduce((a, b) => a + b), closeTo(60, 1e-9));
    expect(result.colMaxes[0], greaterThanOrEqualTo(result.colMins[0]));
    expect(result.colMaxes[1], greaterThanOrEqualTo(result.colMins[1]));
  });

  test('table composition positions spanning cells and preserves children', () {
    const child = TextRunBox(
        key: 'text',
        inlineOffset: 0,
        blockOffset: 0,
        inlineSize: 20,
        blockSize: 10,
        x: 0,
        y: 0,
        width: 20,
        height: 10,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        text: 'x');
    final table = composeTableLayout(
        key: 'table',
        rows: [
          [
            const TableCellInput(
                BlockId('a'), child, LayoutBoxMetadata(colSpan: 2)),
          ],
          [
            const TableCellInput(BlockId('b'), child),
            const TableCellInput(BlockId('c'), child),
          ],
        ],
        inlineSize: 100,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr);
    expect(table.columnWidths, [50, 50]);
    expect(table.children, hasLength(2));
    final first =
        (table.children.first as TableRowBox).children.single as TableCellBox;
    expect(first.width, 100);
    expect(first.height, 10);
    expect(first.children.single, same(child));
  });
}
