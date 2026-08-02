/// Shared table-cell span predicate.
///
/// Port of `table-cell-span.ts`.
library;

int? spanValue(dynamic v) {
  if (v is int && v > 1) return v;
  if (v is double && v.isFinite && v.truncateToDouble() == v && v > 1)
    return v.toInt();
  return null;
}

bool isSpan(dynamic v) {
  return spanValue(v) != null;
}
