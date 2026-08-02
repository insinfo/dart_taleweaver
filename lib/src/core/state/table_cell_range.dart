/// Cell range.
library;

import 'block_id.dart';

class CellRange {
  final BlockId tableId;
  final int minRow;
  final int maxRow;
  final int minCol;
  final int maxCol;

  const CellRange({
    required this.tableId,
    required this.minRow,
    required this.maxRow,
    required this.minCol,
    required this.maxCol,
  });
}
