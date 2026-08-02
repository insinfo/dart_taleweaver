/// Lightweight performance tracing for the Taleweaver engine.
///
/// Usage:
/// ```dart
/// setPerfTraceEnabled(true);
/// final t = markStart('renderPass');
/// // ... work ...
/// markEnd('renderPass', t);
/// final r = report();
/// ```
library;

bool _enabled = false;
final _counts = <String, int>{};
final _totals = <String, double>{};

void setPerfTraceEnabled(bool value) {
  _enabled = value;
}

bool isPerfTraceEnabled() => _enabled;

/// Start a measurement region. Returns a microsecond timestamp token.
/// Returns 0 when tracing is disabled.
double markStart(String label) {
  if (!_enabled) return 0;
  return _nowMs();
}

/// End a measurement region. [startToken] must come from a paired [markStart].
void markEnd(String label, double startToken) {
  if (!_enabled) return;
  final elapsed = _nowMs() - startToken;
  _counts[label] = (_counts[label] ?? 0) + 1;
  _totals[label] = (_totals[label] ?? 0) + elapsed;
}

/// Record a pre-measured duration. Useful for callbacks that already provide
/// elapsed ms.
void recordSample(String label, double ms) {
  if (!_enabled) return;
  _counts[label] = (_counts[label] ?? 0) + 1;
  _totals[label] = (_totals[label] ?? 0) + ms;
}

/// A single entry in a [PerfReport].
class PerfEntry {
  final String label;
  final int count;
  final double totalMs;
  final double avgMs;

  const PerfEntry({
    required this.label,
    required this.count,
    required this.totalMs,
    required this.avgMs,
  });

  @override
  String toString() =>
      'PerfEntry($label: count=$count, total=${totalMs.toStringAsFixed(2)}ms, '
      'avg=${avgMs.toStringAsFixed(2)}ms)';
}

/// Accumulated performance measurements snapshot.
class PerfReport {
  final List<PerfEntry> entries;
  const PerfReport(this.entries);
}

/// Snapshot the current accumulated measurements.
PerfReport report() {
  final entries = <PerfEntry>[];
  for (final label in _totals.keys) {
    final total = _totals[label]!;
    final count = _counts[label] ?? 0;
    entries.add(PerfEntry(
      label: label,
      count: count,
      totalMs: total,
      avgMs: count > 0 ? total / count : 0,
    ));
  }
  entries.sort((a, b) => b.totalMs.compareTo(a.totalMs));
  return PerfReport(entries);
}

/// Reset all measurements (useful between scenarios).
void resetPerfTrace() {
  _counts.clear();
  _totals.clear();
}

/// Get current time in milliseconds.
double _nowMs() {
  // Using Stopwatch for high-resolution timing in Dart.
  return DateTime.now().microsecondsSinceEpoch / 1000.0;
}
