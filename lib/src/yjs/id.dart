library;

import 'encoding.dart';

class YId {
  final int client;
  final int clock;
  const YId(this.client, this.clock);

  @override
  bool operator ==(Object other) =>
      other is YId && other.client == client && other.clock == clock;

  @override
  int get hashCode => Object.hash(client, clock);

  @override
  String toString() => 'YId($client, $clock)';
}

/// The per-client clock frontier used to request only missing structs.
class YStateVector {
  final Map<int, int> clocks;

  YStateVector([Map<int, int>? clocks]) : clocks = {...?clocks};

  int operator [](int client) => clocks[client] ?? 0;
  void operator []=(int client, int clock) {
    if (clock < 0) throw ArgumentError.value(clock, 'clock');
    if (clock == 0) {
      clocks.remove(client);
    } else {
      clocks[client] = clock;
    }
  }

  List<int> encode() {
    final encoder = YEncoder()..writeVarUint(clocks.length);
    final entries = clocks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      encoder
        ..writeVarUint(entry.key)
        ..writeVarUint(entry.value);
    }
    return encoder.toBytes();
  }

  static YStateVector decode(Iterable<int> bytes) {
    final decoder = YDecoder(bytes);
    final count = decoder.readVarUint();
    final vector = YStateVector();
    for (var i = 0; i < count; i++) {
      vector[decoder.readVarUint()] = decoder.readVarUint();
    }
    if (!decoder.isDone) throw FormatException('Trailing state-vector bytes');
    return vector;
  }

  @override
  bool operator ==(Object other) =>
      other is YStateVector && _mapsEqual(clocks, other.clocks);

  @override
  int get hashCode =>
      clocks.entries.fold(0, (hash, e) => hash ^ Object.hash(e.key, e.value));
}

bool _mapsEqual(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  return a.entries.every((entry) => b[entry.key] == entry.value);
}
