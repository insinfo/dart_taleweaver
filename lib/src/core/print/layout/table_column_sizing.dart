/// CSS Tables auto-layout intrinsic column distribution.
library;

class SpannedCellIntrinsic {
  final int gridCol;
  final int colSpan;
  final double min;
  final double max;
  const SpannedCellIntrinsic({
    required this.gridCol,
    required this.colSpan,
    required this.min,
    required this.max,
  });
}

class ColumnIntrinsics {
  final List<double> colMins;
  final List<double> colMaxes;
  const ColumnIntrinsics(this.colMins, this.colMaxes);
}

ColumnIntrinsics distributeColumnIntrinsics(
    List<SpannedCellIntrinsic> cells, int columnCount) {
  final mins = List<double>.filled(columnCount < 0 ? 0 : columnCount, 0);
  final maxes = List<double>.filled(columnCount < 0 ? 0 : columnCount, 0);
  for (final cell in cells) {
    if (cell.colSpan != 1 || cell.gridCol < 0 || cell.gridCol >= columnCount) {
      continue;
    }
    mins[cell.gridCol] = _max(mins[cell.gridCol], cell.min);
    maxes[cell.gridCol] = _max(maxes[cell.gridCol], cell.max);
  }
  final spanning = cells.where((cell) => cell.colSpan > 1).toList()
    ..sort((a, b) => a.colSpan.compareTo(b.colSpan));
  for (final cell in spanning) {
    final from = cell.gridCol.clamp(0, columnCount);
    final to = (cell.gridCol + cell.colSpan).clamp(0, columnCount);
    if (to <= from) continue;
    _distribute(mins, maxes, from, to, cell.min);
    _distribute(maxes, maxes, from, to, cell.max);
    for (var i = from; i < to; i++) {
      if (maxes[i] < mins[i]) maxes[i] = mins[i];
    }
  }
  return ColumnIntrinsics(mins, maxes);
}

double _max(double a, double b) => a > b ? a : b;

void _distribute(List<double> target, List<double> weights, int from, int to,
    double required) {
  var current = 0.0;
  for (var i = from; i < to; i++) current += target[i];
  final shortfall = required - current;
  if (shortfall <= 0) return;
  var weightSum = 0.0;
  for (var i = from; i < to; i++) weightSum += weights[i];
  final span = to - from;
  for (var i = from; i < to; i++) {
    final share =
        weightSum > 0 ? shortfall * (weights[i] / weightSum) : shortfall / span;
    target[i] += share;
  }
}
