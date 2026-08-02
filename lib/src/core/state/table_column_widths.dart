/// Column widths logic.
///
/// Port of `table-column-widths.ts`.
library;

import 'dart:math';

List<double> _normalize(List<double> widths) {
  final n = widths.length;
  if (n == 0) return const [];
  final sum = widths.fold<double>(0.0, (s, w) => s + w);
  if (sum <= 0) return List.generate(n, (_) => 1.0 / n);
  return widths.map((w) => w / sum).toList();
}

List<double> spliceColumnWidth(List<double> widths, int at) {
  final n = widths.length;
  if (n == 0) return [1.0];
  final clamped = max(0, min(at, n));
  final scaled = widths.map((w) => w * (n / (n + 1))).toList();
  final inserted = <double>[
    ...scaled.sublist(0, clamped),
    1.0 / (n + 1),
    ...scaled.sublist(clamped)
  ];
  return _normalize(inserted);
}

List<double> removeColumnWidth(List<double> widths, int at) {
  final n = widths.length;
  if (at < 0 || at >= n) return _normalize(widths);
  final filtered = <double>[];
  for (int i = 0; i < n; i++) {
    if (i != at) filtered.add(widths[i]);
  }
  return _normalize(filtered);
}

bool isColumnWidths(dynamic v) {
  if (v is! List) return false;
  return v.every((n) => n is num);
}

List<double> parseColumnWidths(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<num>().map((e) => e.toDouble()).toList();
}
