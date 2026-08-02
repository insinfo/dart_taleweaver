/// Numbering compute counters.
///
/// Port of `numbering/compute-counters.ts`.
library;

import 'dart:math';

import '../state/list_defs.dart';
import '../state/block_id.dart';
import '../styles/format_counter.dart';
import 'types.dart';

const _defaultLevel = ListLevelConfig(
  style: 'decimal',
  start: 1,
  restart: 'after-break',
);

ListLevelConfig _levelConfig(ListDef? def, int level) {
  if (def == null || def.levels.isEmpty) return _defaultLevel;
  final clamped = min(level, def.levels.length - 1);
  return def.levels[clamped];
}

/// Pure render-time numbering engine.
Map<BlockId, CounterValue> computeCounters(
  List<CounterEvent> events,
  Map<String, ListDef> defs,
) {
  final result = <BlockId, CounterValue>{};
  final scopes = <String, List<int?>>{};

  for (final event in events) {
    final def = defs[event.scopeKey];
    final cfg = _levelConfig(def, event.level);

    var counters = scopes[event.scopeKey];
    if (counters == null || event.breakBefore) {
      counters = [];
      scopes[event.scopeKey] = counters;
    }

    // Ensure capacity up to event.level
    while (counters.length <= event.level) {
      counters.add(null);
    }

    int value;
    final prev = counters[event.level];
    if (event.override != null) {
      value = event.override!;
    } else if (prev == null) {
      value = cfg.start;
    } else {
      value = prev + 1;
    }

    counters[event.level] = value;

    // Clear deeper levels by truncating the list
    counters.length = event.level + 1;

    final style = cfg.style;
    result[event.blockId] = CounterValue(
      value: value,
      formatted: formatCounter(value, style),
    );
  }

  return result;
}
