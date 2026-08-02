library;

import 'dart:convert';
import 'dart:typed_data';

import 'encoding.dart';

class AwarenessChange {
  final Set<int> added;
  final Set<int> updated;
  final Set<int> removed;

  const AwarenessChange({
    this.added = const {},
    this.updated = const {},
    this.removed = const {},
  });
}

typedef AwarenessListener = void Function(AwarenessChange change);
typedef AwarenessSend = void Function(Uint8List update);

class _AwarenessEntry {
  final int clock;
  final Map<String, dynamic>? state;

  const _AwarenessEntry(this.clock, this.state);
}

/// Transport-neutral collaborative presence state.
///
/// Awareness clocks are independent from CRDT item clocks. Updates with an
/// older or equal clock are ignored, and a null state is a tombstone removing
/// a peer. The JSON envelope is deterministic and can be carried by any
/// websocket/provider without coupling the core to a transport.
class YAwareness {
  final int clientId;
  final Map<int, _AwarenessEntry> _states = {};
  final List<AwarenessListener> _listeners = [];
  int _localClock = 0;

  YAwareness({required this.clientId});

  int get localClock => _localClock;

  Map<int, Map<String, dynamic>> get states => {
        for (final entry in _states.entries)
          if (entry.value.state != null)
            entry.key: _cloneMap(entry.value.state!),
      };

  Map<String, dynamic>? get localState {
    final state = _states[clientId]?.state;
    return state == null ? null : _cloneMap(state);
  }

  void observe(AwarenessListener listener) => _listeners.add(listener);
  void unobserve(AwarenessListener listener) => _listeners.remove(listener);

  Uint8List setLocalState(Map<String, dynamic>? state) {
    _localClock++;
    final change =
        _apply(clientId, _localClock, state == null ? null : _cloneMap(state));
    _notify(change);
    return encodeUpdate([clientId]);
  }

  Uint8List setLocalStateField(String key, dynamic value) {
    final next = localState ?? <String, dynamic>{};
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = _cloneValue(value);
    }
    return setLocalState(next);
  }

  Uint8List removeLocalState() => setLocalState(null);

  /// Applies a deterministic awareness envelope and returns the changed IDs.
  AwarenessChange applyUpdate(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) throw FormatException('Invalid awareness update');
    final added = <int>{};
    final updated = <int>{};
    final removed = <int>{};
    for (final raw in decoded) {
      if (raw is! Map || raw['client'] is! int || raw['clock'] is! int) {
        throw FormatException('Invalid awareness entry');
      }
      final client = raw['client'] as int;
      final clock = raw['clock'] as int;
      final state = raw['state'];
      if (state != null && state is! Map) {
        throw FormatException('Invalid awareness state');
      }
      final change = _apply(client, clock,
          state == null ? null : _cloneMap(Map<String, dynamic>.from(state)));
      added.addAll(change.added);
      updated.addAll(change.updated);
      removed.addAll(change.removed);
    }
    final change = AwarenessChange(
        added: Set.unmodifiable(added),
        updated: Set.unmodifiable(updated),
        removed: Set.unmodifiable(removed));
    _notify(change);
    return change;
  }

  Uint8List encodeUpdate([Iterable<int>? clients]) {
    final selected = clients == null ? _states.keys : clients;
    final entries = <Map<String, dynamic>>[];
    for (final client in selected.toSet().toList()..sort()) {
      final entry = _states[client];
      if (entry == null) continue;
      entries.add({
        'client': client,
        'clock': entry.clock,
        'state': entry.state == null ? null : _cloneMap(entry.state!),
      });
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(entries)));
  }

  /// Encodes the standard awareness wire payload used by Yjs providers:
  /// count, client ID, clock, and a JSON state string per entry.
  Uint8List encodeBinaryUpdate([Iterable<int>? clients]) {
    final selected = clients == null ? _states.keys : clients;
    final entries = <MapEntry<int, _AwarenessEntry>>[];
    for (final client in selected.toSet().toList()..sort()) {
      final entry = _states[client];
      if (entry != null) entries.add(MapEntry(client, entry));
    }
    final encoder = YEncoder()..writeVarUint(entries.length);
    for (final entry in entries) {
      encoder
        ..writeVarUint(entry.key)
        ..writeVarUint(entry.value.clock)
        ..writeString(jsonEncode(entry.value.state));
    }
    return Uint8List.fromList(encoder.toBytes());
  }

  AwarenessChange applyBinaryUpdate(Iterable<int> bytes) {
    final decoder = YDecoder(bytes);
    final count = decoder.readVarUint();
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final client = decoder.readVarUint();
      final clock = decoder.readVarUint();
      final rawState = jsonDecode(decoder.readString());
      entries.add({'client': client, 'clock': clock, 'state': rawState});
    }
    if (!decoder.isDone) throw FormatException('Trailing awareness bytes');
    return applyUpdate(utf8.encode(jsonEncode(entries)));
  }

  AwarenessChange _apply(int client, int clock, Map<String, dynamic>? state) {
    final previous = _states[client];
    if (previous != null && clock <= previous.clock) {
      return const AwarenessChange();
    }
    _states[client] = _AwarenessEntry(clock, state);
    if (state == null) {
      return AwarenessChange(
          removed: previous?.state == null ? const {} : {client});
    }
    return AwarenessChange(
        added: previous == null || previous.state == null ? {client} : const {},
        updated:
            previous != null && previous.state != null ? {client} : const {});
  }

  void _notify(AwarenessChange change) {
    if (change.added.isEmpty &&
        change.updated.isEmpty &&
        change.removed.isEmpty) return;
    for (final listener in List<AwarenessListener>.of(_listeners)) {
      listener(change);
    }
  }
}

/// Small transport adapter for websocket/WebRTC/provider integrations. The
/// core owns encoding and clocks; the host owns delivery and lifecycle.
class YAwarenessProvider {
  final YAwareness awareness;
  final AwarenessSend send;

  YAwarenessProvider({required this.awareness, required this.send});

  Uint8List setLocalState(Map<String, dynamic>? state) {
    awareness.setLocalState(state);
    final update = awareness.encodeBinaryUpdate([awareness.clientId]);
    send(update);
    return update;
  }

  Uint8List setLocalStateField(String key, dynamic value) {
    awareness.setLocalStateField(key, value);
    final update = awareness.encodeBinaryUpdate([awareness.clientId]);
    send(update);
    return update;
  }

  Uint8List removeLocalState() {
    awareness.removeLocalState();
    final update = awareness.encodeBinaryUpdate([awareness.clientId]);
    send(update);
    return update;
  }

  AwarenessChange receive(List<int> update) =>
      awareness.applyBinaryUpdate(update);
}

/// Deterministic in-memory transport useful for tests and local multi-peer
/// integrations. Providers receive updates from every other connected peer.
class InMemoryAwarenessHub {
  final Set<YAwarenessProvider> _providers = {};

  void connect(YAwarenessProvider provider) {
    if (!_providers.add(provider)) return;
    // Exchange the complete current awareness view on join so late peers do
    // not wait for the next local heartbeat to learn existing presence.
    for (final other in List<YAwarenessProvider>.of(_providers)) {
      if (identical(other, provider)) continue;
      final toOther = provider.awareness.encodeBinaryUpdate();
      final toNew = other.awareness.encodeBinaryUpdate();
      provider.receive(toNew);
      other.receive(toOther);
    }
  }

  void disconnect(YAwarenessProvider provider) {
    if (!_providers.contains(provider)) return;
    provider.awareness.removeLocalState();
    final update =
        provider.awareness.encodeBinaryUpdate([provider.awareness.clientId]);
    _providers.remove(provider);
    for (final other in List<YAwarenessProvider>.of(_providers)) {
      other.receive(update);
    }
  }

  void broadcast(YAwarenessProvider source, Uint8List update) {
    for (final provider in List<YAwarenessProvider>.of(_providers)) {
      if (!identical(provider, source)) provider.receive(update);
    }
  }
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> value) => {
      for (final entry in value.entries) entry.key: _cloneValue(entry.value),
    };

dynamic _cloneValue(dynamic value) {
  if (value is Map) {
    return _cloneMap(Map<String, dynamic>.from(value));
  }
  if (value is List) return value.map(_cloneValue).toList(growable: false);
  return value;
}
