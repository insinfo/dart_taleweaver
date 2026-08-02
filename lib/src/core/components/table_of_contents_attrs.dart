/// Table of contents attrs helpers.
///
/// Port of `components/table-of-contents-attrs.ts`.
library;

import '../styles/tab_stops.dart';

class TocAttrs {
  final List<int> levels;
  final LeaderStyle leader;
  final bool showPageNumbers;
  final double indentStep;

  const TocAttrs({
    required this.levels,
    required this.leader,
    required this.showPageNumbers,
    required this.indentStep,
  });
}

const defaultTocAttrs = TocAttrs(
  levels: [1, 2, 3, 4, 5, 6],
  leader: LeaderStyle.dot,
  showPageNumbers: true,
  indentStep: 18.0,
);

List<int> tocLevelsFromAttrs(dynamic value) {
  if (value is! List) return [1, 2, 3, 4, 5, 6];
  final out = <int>[];
  for (final n in value) {
    if (n is int && n >= 1 && n <= 6) {
      out.add(n);
    }
  }
  return out.isNotEmpty ? out : [1, 2, 3, 4, 5, 6];
}

LeaderStyle tocLeaderFromAttrs(dynamic value) {
  if (value == 'dot') return LeaderStyle.dot;
  if (value == 'dash') return LeaderStyle.dash;
  if (value == 'line') return LeaderStyle.line;
  if (value == 'none') return LeaderStyle.none;
  return LeaderStyle.dot;
}

bool tocShowPageNumbersFromAttrs(dynamic value) {
  return value is bool ? value : true;
}

double tocIndentStepFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value > 0) return value.toDouble();
  return 18.0;
}
