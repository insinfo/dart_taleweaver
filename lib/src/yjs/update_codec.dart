library;

import 'dart:convert';

import 'compression.dart';
import 'doc.dart';
import 'encoding.dart';
import 'id.dart';
import 'ids.dart';
import 'structs.dart';

abstract class YUpdateEncoder {
  YEncoder get restEncoder;
  void writeLeftId(YId id);
  void writeRightId(YId id);
  void writeClient(int client);
  void writeInfo(int info);
  void writeString(String value);
  void writeParentInfo(bool isYKey);
  void writeLen(int length);
  void writeAny(dynamic value);
  void writeJson(dynamic value);
  void resetDeleteSetClock();
  void writeDeleteSetClock(int clock);
  void writeDeleteSetLength(int length);
  List<int> toBytes();
}

/// The uncompressed update encoder used by Yjs' UpdateEncoderV1.
class UpdateEncoderV1 implements YUpdateEncoder {
  @override
  final YEncoder restEncoder = YEncoder();

  void writeLeftId(YId id) => restEncoder
    ..writeVarUint(id.client)
    ..writeVarUint(id.clock);
  void writeRightId(YId id) => writeLeftId(id);
  void writeClient(int client) => restEncoder.writeVarUint(client);
  void writeInfo(int info) => restEncoder.writeUint8(info);
  void writeString(String value) => restEncoder.writeString(value);
  void writeParentInfo(bool isYKey) => restEncoder.writeVarUint(isYKey ? 1 : 0);
  void writeLen(int length) => restEncoder.writeVarUint(length);
  void writeAny(dynamic value) => restEncoder.writeAny(value);
  void writeJson(dynamic value) => restEncoder.writeString(jsonEncode(value));
  @override
  void resetDeleteSetClock() {}
  @override
  void writeDeleteSetClock(int clock) => restEncoder.writeVarUint(clock);
  @override
  void writeDeleteSetLength(int length) => restEncoder.writeVarUint(length);
  @override
  List<int> toBytes() => restEncoder.toBytes();
}

abstract class YUpdateDecoder {
  YDecoder get restDecoder;
  YId readLeftId();
  YId readRightId();
  int readClient();
  int readInfo();
  String readString();
  bool readParentInfo();
  int readLen();
  dynamic readAny();
  dynamic readJson();
  void resetDeleteSetClock();
  int readDeleteSetClock();
  int readDeleteSetLength();
}

/// The uncompressed update decoder used by Yjs' UpdateDecoderV1.
class UpdateDecoderV1 implements YUpdateDecoder {
  @override
  final YDecoder restDecoder;
  UpdateDecoderV1(Iterable<int> bytes) : restDecoder = YDecoder(bytes);

  YId readLeftId() => YId(restDecoder.readVarUint(), restDecoder.readVarUint());
  YId readRightId() => readLeftId();
  int readClient() => restDecoder.readVarUint();
  int readInfo() => restDecoder.readUint8();
  String readString() => restDecoder.readString();
  bool readParentInfo() => restDecoder.readVarUint() == 1;
  int readLen() => restDecoder.readVarUint();
  dynamic readAny() => restDecoder.readAny();
  dynamic readJson() {
    final value = restDecoder.readString();
    return value == 'undefined' ? null : jsonDecode(value);
  }

  @override
  void resetDeleteSetClock() {}
  @override
  int readDeleteSetClock() => restDecoder.readVarUint();
  @override
  int readDeleteSetLength() => restDecoder.readVarUint();
}

/// Channel-compressed encoder used by Yjs updates V2.
class UpdateEncoderV2 implements YUpdateEncoder {
  @override
  final YEncoder restEncoder = YEncoder();
  final YIntDiffOptRleEncoder _keyClock = YIntDiffOptRleEncoder();
  final YUintOptRleEncoder _client = YUintOptRleEncoder();
  final YIntDiffOptRleEncoder _leftClock = YIntDiffOptRleEncoder();
  final YIntDiffOptRleEncoder _rightClock = YIntDiffOptRleEncoder();
  final YRleByteEncoder _info = YRleByteEncoder();
  final YStringEncoder _string = YStringEncoder();
  final YRleByteEncoder _parentInfo = YRleByteEncoder();
  final YUintOptRleEncoder _typeRef = YUintOptRleEncoder();
  final YUintOptRleEncoder _length = YUintOptRleEncoder();
  int _deleteSetClock = 0;

  @override
  void writeLeftId(YId id) {
    _client.write(id.client);
    _leftClock.write(id.clock);
  }

  @override
  void writeRightId(YId id) {
    _client.write(id.client);
    _rightClock.write(id.clock);
  }

  @override
  void writeClient(int client) => _client.write(client);
  @override
  void writeInfo(int info) => _info.write(info);
  @override
  void writeString(String value) => _string.write(value);
  @override
  void writeParentInfo(bool isYKey) => _parentInfo.write(isYKey ? 1 : 0);
  void writeTypeRef(int ref) => _typeRef.write(ref);
  @override
  void writeLen(int length) => _length.write(length);
  @override
  void writeAny(dynamic value) => restEncoder.writeAny(value);
  @override
  void writeJson(dynamic value) => restEncoder.writeAny(value);
  @override
  void resetDeleteSetClock() => _deleteSetClock = 0;
  @override
  void writeDeleteSetClock(int clock) {
    restEncoder.writeVarUint(clock - _deleteSetClock);
    _deleteSetClock = clock;
  }

  @override
  void writeDeleteSetLength(int length) {
    if (length == 0) throw StateError('Empty delete-set range');
    restEncoder.writeVarUint(length - 1);
    _deleteSetClock += length;
  }

  @override
  List<int> toBytes() {
    final result = YEncoder()..writeVarUint(0);
    for (final channel in [
      _keyClock.toBytes(),
      _client.toBytes(),
      _leftClock.toBytes(),
      _rightClock.toBytes(),
      _info.toBytes(),
      _string.toBytes(),
      _parentInfo.toBytes(),
      _typeRef.toBytes(),
      _length.toBytes(),
    ]) {
      result
        ..writeVarUint(channel.length)
        ..writeBytes(channel);
    }
    result.writeBytes(restEncoder.toBytes());
    return result.toBytes();
  }
}

/// Channel-compressed decoder used by Yjs updates V2.
class UpdateDecoderV2 implements YUpdateDecoder {
  @override
  late final YDecoder restDecoder;
  late final YIntDiffOptRleDecoder _keyClock;
  late final YUintOptRleDecoder _client;
  late final YIntDiffOptRleDecoder _leftClock;
  late final YIntDiffOptRleDecoder _rightClock;
  late final YRleByteDecoder _info;
  late final YStringDecoder _string;
  late final YRleByteDecoder _parentInfo;
  late final YUintOptRleDecoder _typeRef;
  late final YUintOptRleDecoder _length;
  int _deleteSetClock = 0;
  final List<String> _keys = [];

  UpdateDecoderV2(Iterable<int> bytes) {
    final decoder = YDecoder(bytes);
    decoder.readVarUint(); // reserved feature flags
    List<int> channel() => decoder.readBytes(decoder.readVarUint());
    _keyClock = YIntDiffOptRleDecoder(channel());
    _client = YUintOptRleDecoder(channel());
    _leftClock = YIntDiffOptRleDecoder(channel());
    _rightClock = YIntDiffOptRleDecoder(channel());
    _info = YRleByteDecoder(channel());
    _string = YStringDecoder(channel());
    _parentInfo = YRleByteDecoder(channel());
    _typeRef = YUintOptRleDecoder(channel());
    _length = YUintOptRleDecoder(channel());
    restDecoder = YDecoder(decoder.readTail());
  }

  @override
  YId readLeftId() => YId(_client.read(), _leftClock.read());
  @override
  YId readRightId() => YId(_client.read(), _rightClock.read());
  @override
  int readClient() => _client.read();
  @override
  int readInfo() => _info.read();
  @override
  String readString() => _string.read();
  @override
  bool readParentInfo() => _parentInfo.read() == 1;
  int readTypeRef() => _typeRef.read();
  String readKey() {
    final clock = _keyClock.read();
    if (clock < _keys.length) return _keys[clock];
    final key = _string.read();
    _keys.add(key);
    return key;
  }

  @override
  int readLen() => _length.read();
  @override
  dynamic readAny() => restDecoder.readAny();
  @override
  dynamic readJson() => restDecoder.readAny();
  @override
  void resetDeleteSetClock() => _deleteSetClock = 0;
  @override
  int readDeleteSetClock() {
    _deleteSetClock += restDecoder.readVarUint();
    return _deleteSetClock;
  }

  @override
  int readDeleteSetLength() {
    final length = restDecoder.readVarUint() + 1;
    _deleteSetClock += length;
    return length;
  }
}

class YStructUpdate {
  final List<YStruct> structs;
  final YIdSet deleteSet;

  YStructUpdate({Iterable<YStruct>? structs, YIdSet? deleteSet})
      : structs = List<YStruct>.of(structs ?? const []),
        deleteSet = deleteSet ?? YIdSet();
}

/// Byte-compatible implementation of the Yjs update V1 container format.
///
/// The Dart store currently models GC, Skip, ContentString and ContentAny.
/// Other Yjs item content references are rejected instead of being silently
/// encoded using a private format.
class YStructUpdateCodec {
  static List<int> encode(YStructUpdate update) =>
      _encodeWith(update, UpdateEncoderV1());

  static List<int> encodeV2(YStructUpdate update) =>
      _encodeWith(update, UpdateEncoderV2());

  static List<int> _encodeWith(YStructUpdate update, YUpdateEncoder encoder) {
    final byClient = <int, List<YStruct>>{};
    for (final struct in update.structs) {
      byClient.putIfAbsent(struct.id.client, () => []).add(struct);
    }
    final clients = byClient.keys.toList()..sort((a, b) => b.compareTo(a));
    encoder.restEncoder.writeVarUint(clients.length);
    for (final client in clients) {
      final structs = byClient[client]!..sort(_compareStructs);
      _validateContiguous(structs);
      encoder.restEncoder.writeVarUint(structs.length);
      encoder.writeClient(client);
      encoder.restEncoder.writeVarUint(structs.first.id.clock);
      for (final struct in structs) _writeStruct(encoder, struct);
    }
    _writeDeleteSet(encoder, update.deleteSet);
    return encoder.toBytes();
  }

  static YStructUpdate decode(Iterable<int> bytes) =>
      _decodeWith(UpdateDecoderV1(bytes));

  static YStructUpdate decodeV2(Iterable<int> bytes) =>
      _decodeWith(UpdateDecoderV2(bytes));

  static YStructUpdate _decodeWith(YUpdateDecoder decoder) {
    final numberOfClients = decoder.restDecoder.readVarUint();
    final structs = <YStruct>[];
    for (var clientIndex = 0; clientIndex < numberOfClients; clientIndex++) {
      final numberOfStructs = decoder.restDecoder.readVarUint();
      final client = decoder.readClient();
      var clock = decoder.restDecoder.readVarUint();
      for (var structIndex = 0; structIndex < numberOfStructs; structIndex++) {
        final info = decoder.readInfo();
        final struct = _readStruct(decoder, YId(client, clock), info);
        structs.add(struct);
        clock += struct.length;
      }
    }
    final deleteSet = _readDeleteSet(decoder);
    for (final struct in structs) {
      if (struct is YItem &&
          deleteSet.covers(struct.id.client, struct.id.clock, struct.length)) {
        struct.delete();
      }
    }
    if (!decoder.restDecoder.isDone) {
      throw FormatException('Trailing Yjs V1 update bytes');
    }
    return YStructUpdate(structs: structs, deleteSet: deleteSet);
  }

  static void _writeStruct(YUpdateEncoder encoder, YStruct struct) {
    switch (struct) {
      case YGC():
        encoder
          ..writeInfo(0)
          ..writeLen(struct.length);
      case YSkip():
        encoder.writeInfo(10);
        encoder.restEncoder.writeVarUint(struct.length);
      case YItem():
        final contentRef = switch (struct.content) {
          YDeletedContent() => 1,
          String() => 4,
          List() => 8,
          _ => throw StateError(
              'Unsupported Yjs item content ${struct.content.runtimeType}'),
        };
        final info = contentRef |
            (struct.origin == null ? 0 : 0x80) |
            (struct.rightOrigin == null ? 0 : 0x40) |
            (struct.parentSub == null ? 0 : 0x20);
        encoder.writeInfo(info);
        if (struct.origin != null) encoder.writeLeftId(struct.origin!);
        if (struct.rightOrigin != null)
          encoder.writeRightId(struct.rightOrigin!);
        if (struct.origin == null && struct.rightOrigin == null) {
          final parent = struct.parent;
          if (parent is String) {
            encoder
              ..writeParentInfo(true)
              ..writeString(parent);
          } else if (parent is YId) {
            encoder
              ..writeParentInfo(false)
              ..writeLeftId(parent);
          } else {
            throw StateError('YItem parent must be a root key or YId');
          }
          if (struct.parentSub != null) encoder.writeString(struct.parentSub!);
        }
        if (struct.content case YDeletedContent(:final length)) {
          if (length != struct.length) {
            throw StateError(
                'ContentDeleted length does not match item length');
          }
          encoder.writeLen(length);
        } else if (struct.content case String value) {
          if (value.length != struct.length) {
            throw StateError('ContentString length does not match item length');
          }
          encoder.writeString(value);
        } else if (struct.content case List values) {
          if (values.length != struct.length) {
            throw StateError('ContentAny length does not match item length');
          }
          encoder.writeLen(values.length);
          for (final value in values) encoder.writeAny(value);
        }
      default:
        throw StateError('Unsupported struct ${struct.runtimeType}');
    }
  }

  static YStruct _readStruct(YUpdateDecoder decoder, YId id, int info) {
    if (info == 10) return YSkip(id, decoder.restDecoder.readVarUint());
    final ref = info & 0x1f;
    if (ref == 0) return YGC(id, decoder.readLen());
    final origin = (info & 0x80) == 0 ? null : decoder.readLeftId();
    final rightOrigin = (info & 0x40) == 0 ? null : decoder.readRightId();
    Object parent = '';
    String? parentSub;
    if (origin == null && rightOrigin == null) {
      parent = decoder.readParentInfo()
          ? decoder.readString()
          : decoder.readLeftId();
      if ((info & 0x20) != 0) parentSub = decoder.readString();
    }
    final content = switch (ref) {
      1 => YDeletedContent(decoder.readLen()),
      2 => _readJsonContent(decoder),
      4 => decoder.readString(),
      8 => _readAnyContent(decoder),
      _ => throw FormatException('Unsupported Yjs item content ref $ref'),
    };
    final length = switch (content) {
      YDeletedContent(:final length) => length,
      String() => content.length,
      List() => content.length,
      _ => throw FormatException('Unsupported decoded content'),
    };
    return YItem(id, length, content,
        origin: origin,
        rightOrigin: rightOrigin,
        parent: parent,
        parentSub: parentSub);
  }

  static List<dynamic> _readAnyContent(YUpdateDecoder decoder) =>
      List<dynamic>.generate(decoder.readLen(), (_) => decoder.readAny());

  static List<dynamic> _readJsonContent(YUpdateDecoder decoder) =>
      List<dynamic>.generate(decoder.readLen(), (_) {
        return decoder.readJson();
      });

  static void _writeDeleteSet(YUpdateEncoder encoder, YIdSet deleteSet) {
    final clients = deleteSet.clients.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    encoder.restEncoder.writeVarUint(clients.length);
    for (final entry in clients) {
      encoder.restEncoder
        ..writeVarUint(entry.key)
        ..writeVarUint(entry.value.length);
      encoder.resetDeleteSetClock();
      for (final range in entry.value) {
        encoder.writeDeleteSetClock(range.clock);
        encoder.writeDeleteSetLength(range.length);
      }
    }
  }

  static YIdSet _readDeleteSet(YUpdateDecoder decoder) {
    final result = YIdSet();
    final clients = decoder.restDecoder.readVarUint();
    for (var i = 0; i < clients; i++) {
      final client = decoder.restDecoder.readVarUint();
      final ranges = decoder.restDecoder.readVarUint();
      decoder.resetDeleteSetClock();
      for (var j = 0; j < ranges; j++) {
        result.add(client, decoder.readDeleteSetClock(),
            decoder.readDeleteSetLength());
      }
    }
    return result;
  }

  static int _compareStructs(YStruct left, YStruct right) =>
      left.id.clock.compareTo(right.id.clock);

  static void _validateContiguous(List<YStruct> structs) {
    for (var i = 1; i < structs.length; i++) {
      if (structs[i - 1].id.clock + structs[i - 1].length !=
          structs[i].id.clock) {
        throw StateError('Yjs V1 client struct ranges must be contiguous');
      }
    }
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
        final client = b.id.client.compareTo(a.id.client);
        return client == 0 ? a.id.clock.compareTo(b.id.clock) : client;
      });
    return encode(YStructUpdate(structs: structs, deleteSet: deletes));
  }

  static void apply(YStructStore store, List<int> bytes) {
    _applyDecoded(store, decode(bytes));
  }

  static void applyV2(YStructStore store, List<int> bytes) {
    _applyDecoded(store, decodeV2(bytes));
  }

  static void _applyDecoded(YStructStore store, YStructUpdate update) {
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

List<int> encodeStateAsUpdateV2(YDoc doc) =>
    YStructUpdateCodec.encodeV2(YStructUpdate(structs: [
      for (final structs in doc.store.clients.values) ...structs,
    ], deleteSet: doc.store.deleteSet));

void applyUpdate(YDoc doc, List<int> update, [Object? origin]) {
  YStructUpdateCodec.apply(doc.store, update);
}

void applyUpdateV2(YDoc doc, List<int> update, [Object? origin]) {
  YStructUpdateCodec.applyV2(doc.store, update);
}

List<int> mergeUpdates(Iterable<List<int>> updates) =>
    YStructUpdateCodec.merge(updates);
