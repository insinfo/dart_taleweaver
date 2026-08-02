library;

import 'dart:convert';

import 'encoding.dart';
import 'doc.dart';
import 'id.dart';
import 'ids.dart';
import 'structs.dart';

class YStructUpdate {
  final List<YStruct> structs;
  final YIdSet deleteSet;

  YStructUpdate({Iterable<YStruct>? structs, YIdSet? deleteSet})
      : structs = List<YStruct>.of(structs ?? const []),
        deleteSet = deleteSet ?? YIdSet();
}

/// Deterministic internal update codec for the Dart CRDT store.
///
/// This is deliberately versioned and self-contained. It is the local Dart
/// wire format used while the byte-compatible Yjs V1/V2 codecs are ported;
/// it must not be advertised as compatible with JavaScript Yjs updates yet.
class YStructUpdateCodec {
  static const _version = 1;

  static List<int> encode(YStructUpdate update) {
    final encoder = YEncoder()
      ..writeVarUint(_version)
      ..writeVarUint(update.structs.length);
    for (final struct in update.structs) {
      final kind = switch (struct) {
        YGC() => 0,
        YItem() => 1,
        YSkip() => 10,
        _ => throw StateError('Unsupported struct ${struct.runtimeType}'),
      };
      encoder
        ..writeVarUint(kind)
        ..writeVarUint(struct.id.client)
        ..writeVarUint(struct.id.clock)
        ..writeVarUint(struct.length);
      if (struct case YItem(:final content, :final isDeleted)) {
        final data = utf8.encode(jsonEncode(content));
        encoder
          ..writeVarUint(isDeleted ? 1 : 0)
          ..writeVarUint(data.length)
          ..writeBytes(data);
      }
    }
    final clients = update.deleteSet.clients.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    encoder.writeVarUint(clients.length);
    for (final entry in clients) {
      final ranges = entry.value;
      encoder
        ..writeVarUint(entry.key)
        ..writeVarUint(ranges.length);
      for (final range in ranges) {
        encoder
          ..writeVarUint(range.clock)
          ..writeVarUint(range.length);
      }
    }
    return encoder.toBytes();
  }

  static YStructUpdate decode(Iterable<int> bytes) {
    final decoder = YDecoder(bytes);
    if (decoder.readVarUint() != _version) {
      throw FormatException('Unsupported Dart update version');
    }
    final structCount = decoder.readVarUint();
    final structs = <YStruct>[];
    for (var i = 0; i < structCount; i++) {
      final kind = decoder.readVarUint();
      final id = YId(decoder.readVarUint(), decoder.readVarUint());
      final length = decoder.readVarUint();
      final struct = switch (kind) {
        0 => YGC(id, length),
        10 => YSkip(id, length),
        1 => _decodeItem(decoder, id, length),
        _ => throw FormatException('Unknown struct kind $kind'),
      };
      structs.add(struct);
    }
    final deleteClients = decoder.readVarUint();
    final deleteSet = YIdSet();
    for (var i = 0; i < deleteClients; i++) {
      final client = decoder.readVarUint();
      final count = decoder.readVarUint();
      for (var j = 0; j < count; j++) {
        deleteSet.add(client, decoder.readVarUint(), decoder.readVarUint());
      }
    }
    if (!decoder.isDone) throw FormatException('Trailing update bytes');
    return YStructUpdate(structs: structs, deleteSet: deleteSet);
  }

  static YItem _decodeItem(YDecoder decoder, YId id, int length) {
    final deleted = decoder.readVarUint() == 1;
    final dataLength = decoder.readVarUint();
    final data = utf8.decode(decoder.readBytes(dataLength));
    return YItem(id, length, jsonDecode(data), isDeleted: deleted);
  }

  static List<int> merge(Iterable<List<int>> updates) {
    final byId = <YId, YStruct>{};
    final deletes = YIdSet();
    for (final bytes in updates) {
      final update = decode(bytes);
      for (final struct in update.structs) {
        final old = byId[struct.id];
        if (old == null || struct.length > old.length) byId[struct.id] = struct;
      }
      for (final entry in update.deleteSet.clients.entries) {
        for (final range in entry.value) {
          deletes.add(entry.key, range.clock, range.length);
        }
      }
    }
    final structs = byId.values.toList()
      ..sort((a, b) {
        final client = a.id.client.compareTo(b.id.client);
        return client == 0 ? a.id.clock.compareTo(b.id.clock) : client;
      });
    return encode(YStructUpdate(structs: structs, deleteSet: deletes));
  }

  static void apply(YStructStore store, List<int> bytes) {
    final update = decode(bytes);
    for (final struct in update.structs) {
      final existing = _tryGet(store, struct.id);
      if (existing != null) {
        if (existing.id == struct.id && existing.length == struct.length)
          continue;
        throw StateError('Conflicting struct at ${struct.id}');
      }
      store.add(struct);
    }
    for (final entry in update.deleteSet.clients.entries) {
      for (final range in entry.value) {
        for (var clock = range.clock; clock < range.end; clock++) {
          final struct = _tryGet(store, YId(entry.key, clock));
          if (struct is YItem) struct.delete();
        }
      }
    }
  }

  static YStruct? _tryGet(YStructStore store, YId id) {
    final index = store.getIndex(id);
    if (index.index < 0) return null;
    return index.structs[index.index];
  }
}

List<int> encodeStateAsUpdate(YDoc doc) =>
    YStructUpdateCodec.encode(YStructUpdate(structs: [
      for (final structs in doc.store.clients.values) ...structs,
    ], deleteSet: doc.store.deleteSet));

void applyUpdate(YDoc doc, List<int> update, [Object? origin]) {
  YStructUpdateCodec.apply(doc.store, update);
}

List<int> mergeUpdates(Iterable<List<int>> updates) =>
    YStructUpdateCodec.merge(updates);
