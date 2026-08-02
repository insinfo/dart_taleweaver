/// Numbering types.
///
/// Port of `numbering/types.ts`.
library;

import '../state/block_id.dart';

/// A counter scope: all events sharing a scopeKey form one numbering sequence.
typedef CounterScopeKey = String;

/// Restart behavior for a level within a scope.
typedef CounterRestart = String; // "always" | "never" | "after-break"

/// One numbering event in document order.
class CounterEvent {
  final BlockId blockId;
  final CounterScopeKey scopeKey;
  final int level;
  final bool breakBefore;
  final int? override;

  const CounterEvent({
    required this.blockId,
    required this.scopeKey,
    required this.level,
    required this.breakBefore,
    this.override,
  });
}

/// The computed number for one event.
class CounterValue {
  final int value;
  final String formatted;

  const CounterValue({
    required this.value,
    required this.formatted,
  });
}

// Note: CounterLevelDef and CounterDef are represented by ListLevelConfig and ListDef in our port.
