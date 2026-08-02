/// Per-section multi-column configuration vocabulary.
///
/// Port of `styles/column-config.ts`.
library;

import 'color.dart';
import 'style.dart';

class ColumnRule {
  final double width;
  final BorderStyle style;
  final Color color;

  const ColumnRule({
    required this.width,
    required this.style,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnRule &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          style == other.style &&
          color == other.color;

  @override
  int get hashCode => width.hashCode ^ style.hashCode ^ color.hashCode;
}

class ColumnConfig {
  final int columnCount;
  final double columnGap;
  final ColumnRule? columnRule;

  const ColumnConfig({
    required this.columnCount,
    required this.columnGap,
    this.columnRule,
  });
}

const double defaultColumnGap = 48.0;

const defaultColumnConfig = ColumnConfig(
  columnCount: 1,
  columnGap: defaultColumnGap,
  columnRule: null,
);

bool columnRulesEqual(ColumnRule? a, ColumnRule? b) {
  if (a == null || b == null) {
    return identical(a, b);
  }
  return a == b;
}

bool columnConfigsEqual(ColumnConfig a, ColumnConfig b) {
  return a.columnCount == b.columnCount &&
      a.columnGap == b.columnGap &&
      columnRulesEqual(a.columnRule, b.columnRule);
}
