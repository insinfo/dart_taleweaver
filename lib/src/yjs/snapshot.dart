library;

import 'doc.dart';
import 'encoding.dart';
import 'id.dart';
import 'ids.dart';
import 'structs.dart';
import 'types.dart';
import 'update_codec.dart';

/// Immutable CRDT snapshot boundary: a state vector plus the deletion set
/// visible at that boundary. It is sufficient to decide whether an item was
/// present without copying shared-type materializations.
class YSnapshot {
  final YStateVector stateVector;
  final YIdSet deleteSet;
  final Map<String, dynamic>? materialized;

  YSnapshot({
    required YStateVector stateVector,
    required YIdSet deleteSet,
    Map<String, dynamic>? materialized,
  })  : stateVector = YStateVector(stateVector.clocks),
        deleteSet = deleteSet.copy(),
        materialized = materialized == null ? null : _cloneMap(materialized);

  bool contains(YId id) {
    final clock = stateVector[id.client];
    return id.clock < clock && !deleteSet.covers(id.client, id.clock, 1);
  }

  /// Returns whether every clock occupied by [struct] belongs to this
  /// snapshot and has not been deleted at that boundary. This mirrors Yjs'
  /// `snapshotContainsUpdate` predicate for a single decoded struct.
  bool containsStruct(YStruct struct) {
    for (var offset = 0; offset < struct.length; offset++) {
      if (!contains(YId(struct.id.client, struct.id.clock + offset))) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'stateVector': stateVector.clocks.map((k, v) => MapEntry('$k', v)),
        'deleteSet': {
          for (final entry in deleteSet.clients.entries)
            '${entry.key}': [
              for (final range in entry.value)
                {'clock': range.clock, 'length': range.length}
            ]
        },
        if (materialized != null) 'materialized': _cloneMap(materialized!),
      };

  static YSnapshot? fromJson(Map<String, dynamic> json) {
    final rawVector = json['stateVector'];
    final rawDelete = json['deleteSet'];
    if (rawVector is! Map || rawDelete is! Map) return null;
    final vector = <int, int>{};
    for (final entry in rawVector.entries) {
      final client = int.tryParse('${entry.key}');
      if (client == null || entry.value is! int) return null;
      vector[client] = entry.value as int;
    }
    final deleted = YIdSet();
    for (final entry in rawDelete.entries) {
      final client = int.tryParse('${entry.key}');
      final ranges = entry.value;
      if (client == null || ranges is! List) return null;
      for (final value in ranges) {
        if (value is! Map || value['clock'] is! int || value['length'] is! int)
          return null;
        deleted.add(client, value['clock'] as int, value['length'] as int);
      }
    }
    final rawMaterialized = json['materialized'];
    final materialized = rawMaterialized is Map
        ? _cloneMap(Map<String, dynamic>.from(rawMaterialized))
        : null;
    return YSnapshot(
        stateVector: YStateVector(vector),
        deleteSet: deleted,
        materialized: materialized);
  }
}

/// Empty causal snapshot, equivalent to Yjs' `emptySnapshot`.
final YSnapshot emptySnapshot = YSnapshot(
  stateVector: YStateVector(),
  deleteSet: YIdSet(),
);

/// Encodes a snapshot using Yjs' V1 snapshot framing: DeleteSet followed by
/// StateVector. Materialized values are intentionally not part of the wire
/// format and remain available through [YSnapshot.toJson].
List<int> encodeSnapshot(YSnapshot snapshot) {
  final encoder = YEncoder();
  final clients = snapshot.deleteSet.clients.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  encoder.writeVarUint(clients.length);
  for (final entry in clients) {
    encoder
      ..writeVarUint(entry.key)
      ..writeVarUint(entry.value.length);
    for (final range in entry.value) {
      encoder
        ..writeVarUint(range.clock)
        ..writeVarUint(range.length);
    }
  }
  encoder.writeBytes(snapshot.stateVector.encode());
  return encoder.toBytes();
}

/// Encodes the same snapshot framing through Yjs' IdSet V2 differential
/// clock encoding (this is distinct from the update V2 channel container).
List<int> encodeSnapshotV2(YSnapshot snapshot) {
  final encoder = YEncoder();
  final clients = snapshot.deleteSet.clients.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  encoder.writeVarUint(clients.length);
  for (final entry in clients) {
    encoder
      ..writeVarUint(entry.key)
      ..writeVarUint(entry.value.length);
    var current = 0;
    for (final range in entry.value) {
      encoder.writeVarUint(range.clock - current);
      encoder.writeVarUint(range.length - 1);
      current = range.end;
    }
  }
  encoder.writeBytes(snapshot.stateVector.encode());
  return encoder.toBytes();
}

/// Decodes the V1 binary representation produced by [encodeSnapshot].
YSnapshot decodeSnapshot(Iterable<int> bytes) {
  final decoder = YDecoder(bytes);
  final deleteSet = YIdSet();
  final clients = decoder.readVarUint();
  for (var i = 0; i < clients; i++) {
    final client = decoder.readVarUint();
    final ranges = decoder.readVarUint();
    for (var j = 0; j < ranges; j++) {
      deleteSet.add(client, decoder.readVarUint(), decoder.readVarUint());
    }
  }
  final vector = YStateVector.decode(decoder.readBytes(decoder.remaining));
  return YSnapshot(stateVector: vector, deleteSet: deleteSet);
}

/// Decodes a V2 IdSet differential snapshot.
YSnapshot decodeSnapshotV2(Iterable<int> bytes) {
  final decoder = YDecoder(bytes);
  final deleteSet = YIdSet();
  final clients = decoder.readVarUint();
  for (var i = 0; i < clients; i++) {
    final client = decoder.readVarUint();
    final ranges = decoder.readVarUint();
    var current = 0;
    for (var j = 0; j < ranges; j++) {
      current += decoder.readVarUint();
      final length = decoder.readVarUint() + 1;
      deleteSet.add(client, current, length);
      current += length;
    }
  }
  final vector = YStateVector.decode(decoder.readTail());
  return YSnapshot(stateVector: vector, deleteSet: deleteSet);
}

YSnapshot createSnapshot(YDoc doc) => YSnapshot(
    stateVector: doc.store.stateVector,
    deleteSet: doc.store.deleteSet,
    materialized: doc.toJson());

/// Compares the causal boundary and deletion set of two snapshots.
bool equalSnapshots(YSnapshot left, YSnapshot right) =>
    left.stateVector.clocks.length == right.stateVector.clocks.length &&
    left.stateVector.clocks.entries
        .every((entry) => right.stateVector[entry.key] == entry.value) &&
    left.deleteSet == right.deleteSet;

/// Returns whether an update is entirely contained by [snapshot]. Accepts a
/// decoded [YStructUpdate] or encoded V1/V2 bytes via [v2].
bool snapshotContainsUpdate(YSnapshot snapshot, dynamic update,
    {bool v2 = false}) {
  final decoded = update is YStructUpdate
      ? update
      : update is List<int>
          ? (v2
              ? YStructUpdateCodec.decodeV2(update)
              : YStructUpdateCodec.decode(update))
          : (throw ArgumentError.value(update, 'update'));
  // Containment is causal, not visibility-based: structs deleted at the
  // snapshot boundary still belong to its state vector and must count.
  if (!decoded.structs.every((struct) =>
      struct.id.clock + struct.length <=
      snapshot.stateVector[struct.id.client])) {
    return false;
  }
  final merged = snapshot.deleteSet.copy();
  for (final entry in decoded.deleteSet.clients.entries) {
    for (final range in entry.value) {
      merged.add(entry.key, range.clock, range.length);
    }
  }
  return merged == snapshot.deleteSet;
}

bool snapshotContainsUpdateV1(YSnapshot snapshot, List<int> update) =>
    snapshotContainsUpdate(snapshot, update);

bool snapshotContainsUpdateV2(YSnapshot snapshot, List<int> update) =>
    snapshotContainsUpdate(snapshot, update, v2: true);

/// Materializes a new document at [snapshot]'s causal boundary. Structs after
/// the state vector or deleted at that boundary are omitted; visible structs
/// are replayed through the same remote-materialization path used by updates,
/// so the returned document is independent from [source].
YDoc createDocFromSnapshot(YDoc source, YSnapshot snapshot, {int? clientId}) {
  final target = YDoc(clientId: clientId);
  // Root type declarations are not represented by update structs. Recreate
  // them first so a nested ContentType whose parent is a root name is attached
  // to the correct YMap/YArray/YText rather than guessed as YMap.
  for (final entry in source.sharedTypes) {
    final type = entry.value;
    if (type is YText) {
      target.getText(entry.key);
    } else if (type is YArray) {
      target.getArray(entry.key);
    } else if (type is YMap) {
      target.getMap(entry.key);
    }
  }
  for (final structs in source.store.clients.values) {
    for (final struct in structs) {
      if (!snapshot.containsStruct(struct)) continue;
      final restored = struct is YItem
          ? YItem(struct.id, struct.length, _cloneCrdtValue(struct.content),
              origin: struct.origin,
              rightOrigin: struct.rightOrigin,
              parent: struct.parent,
              parentSub: struct.parentSub)
          : struct.copyWith(id: struct.id, length: struct.length);
      target.store.add(restored);
      if (restored is YItem) target.applyRemoteItem(restored);
    }
  }
  return target;
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> value) => {
      for (final entry in value.entries) entry.key: _cloneJson(entry.value),
    };

dynamic _cloneJson(dynamic value) {
  if (value is Map) {
    return _cloneMap(Map<String, dynamic>.from(value));
  }
  if (value is List) return value.map(_cloneJson).toList(growable: false);
  return value;
}

dynamic _cloneCrdtValue(dynamic value) {
  if (value is YMap) {
    final result = YMap();
    for (final entry in value.entries) {
      result.set(entry.key, _cloneCrdtValue(entry.value));
    }
    return result;
  }
  if (value is YArray) {
    final result = YArray();
    result.insert(0, value.toArray().map(_cloneCrdtValue));
    return result;
  }
  if (value is YText) {
    final result = YText();
    var offset = 0;
    for (final run in value.toDelta()) {
      final text = run['insert'];
      if (text is! String || text.isEmpty) continue;
      result.insert(offset, text);
      final attrs = run['attributes'];
      if (attrs is Map && attrs.isNotEmpty) {
        result.format(offset, text.length, Map<String, dynamic>.from(attrs));
      }
      offset += text.length;
    }
    return result;
  }
  if (value is List) return value.map(_cloneCrdtValue).toList(growable: false);
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _cloneCrdtValue(entry.value),
    };
  }
  return value;
}
