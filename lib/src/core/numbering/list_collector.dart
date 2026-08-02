/// Numbering list collector.
///
/// Port of `numbering/list-collector.ts`.
library;

import '../state/state.dart';
import '../state/block_traversal.dart';
import '../state/block_id.dart';
import 'types.dart';

/// Walk the BODY tree in document order and emit a CounterEvent per `list-item`.
List<CounterEvent> collectListEvents(State state) {
  final events = <CounterEvent>[];
  String? prevListId;

  for (final block in iterateBlocksInDocumentOrder(state)) {
    if (block.type != 'list-item') {
      prevListId = null;
      continue;
    }

    final listIdRaw = block.attrs['listId'];
    final listId = listIdRaw is String ? listIdRaw : '';

    final levelRaw = block.attrs['listLevel'];
    final level = levelRaw is num ? levelRaw.toInt() : 0;

    final overrideRaw = block.attrs['listCounterOverride'];
    final override = overrideRaw is num ? overrideRaw.toInt() : null;

    final breakBefore = prevListId != listId;

    events.add(CounterEvent(
      blockId: block.id,
      scopeKey: listId,
      level: level,
      breakBefore: breakBefore,
      override: override,
    ));

    prevListId = listId;
  }

  return events;
}

/// Blocks whose computed number differs (value or presence) between two maps.
Set<BlockId> listCounterRenumberedBlocks(
  Map<BlockId, CounterValue> next,
  Map<BlockId, CounterValue> prev,
) {
  final changed = <BlockId>{};
  for (final entry in next.entries) {
    final id = entry.key;
    final v = entry.value;
    final p = prev[id];
    if (p == null || p.value != v.value || p.formatted != v.formatted) {
      changed.add(id);
    }
  }
  for (final id in prev.keys) {
    if (!next.containsKey(id)) {
      changed.add(id);
    }
  }
  return changed;
}
