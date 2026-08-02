library;

import 'id.dart';
import 'ids.dart';

abstract class YStruct {
  YId id;
  int length;
  YStruct(this.id, this.length) {
    if (length <= 0) throw ArgumentError.value(length, 'length');
  }

  bool get deleted;

  bool mergeWith(YStruct right) => false;

  YStruct splice(int offset) {
    if (offset <= 0 || offset >= length)
      throw ArgumentError.value(offset, 'offset');
    final remainder = copyWith(
        id: YId(id.client, id.clock + offset), length: length - offset);
    length = offset;
    return remainder;
  }

  YStruct copyWith({required YId id, required int length});
}

class YGC extends YStruct {
  YGC(super.id, super.length);
  @override
  bool get deleted => true;
  @override
  bool mergeWith(YStruct right) {
    if (right is! YGC || id.clock + length != right.id.clock) return false;
    length += right.length;
    return true;
  }

  @override
  YGC copyWith({required YId id, required int length}) => YGC(id, length);
}

class YSkip extends YStruct {
  YSkip(super.id, super.length);
  @override
  bool get deleted => false;
  @override
  bool mergeWith(YStruct right) {
    if (right is! YSkip || id.clock + length != right.id.clock) return false;
    length += right.length;
    return true;
  }

  @override
  YSkip copyWith({required YId id, required int length}) => YSkip(id, length);
}

/// Yjs ContentDeleted payload (content ref 1).
class YDeletedContent {
  final int length;
  const YDeletedContent(this.length);
}

class YBinaryContent {
  final List<int> bytes;
  const YBinaryContent(this.bytes);
}

class YEmbedContent {
  final dynamic value;
  const YEmbedContent(this.value);
}

class YFormatContent {
  final String key;
  final dynamic value;
  const YFormatContent(this.key, this.value);
}

class YTypeContent {
  final int typeRef;
  final String? key;
  const YTypeContent(this.typeRef, {this.key});

  @override
  bool operator ==(Object other) =>
      other is YTypeContent && other.typeRef == typeRef && other.key == key;

  @override
  int get hashCode => Object.hash(typeRef, key);
}

class YDocContent {
  final String guid;
  final dynamic options;
  const YDocContent(this.guid, this.options);
}

class YItem extends YStruct {
  dynamic content;
  bool isDeleted;
  final YId? origin;
  final YId? rightOrigin;
  final Object parent;
  final String? parentSub;

  YItem(
    super.id,
    super.length,
    this.content, {
    this.isDeleted = false,
    this.origin,
    this.rightOrigin,
    this.parent = '',
    this.parentSub,
  });

  @override
  bool get deleted => isDeleted;

  void delete() => isDeleted = true;

  @override
  bool mergeWith(YStruct right) {
    if (right is! YItem ||
        id.clock + length != right.id.clock ||
        isDeleted != right.isDeleted ||
        content is! String ||
        right.content is! String) {
      return false;
    }
    content = '$content${right.content}';
    length += right.length;
    return true;
  }

  @override
  YItem copyWith({required YId id, required int length}) =>
      YItem(id, length, content,
          isDeleted: isDeleted,
          origin: origin,
          rightOrigin: rightOrigin,
          parent: parent,
          parentSub: parentSub);
}

class YStructStore {
  final Map<int, List<YStruct>> clients = {};
  final YIdSet skips = YIdSet();
  final Map<int, List<YStruct>> pending = {};

  /// Delete ranges received before their corresponding structs.
  final YIdSet pendingDeletes = YIdSet();

  YIdSet get deleteSet {
    final result = YIdSet();
    for (final entry in clients.entries) {
      for (final struct in entry.value) {
        if (struct.deleted)
          result.add(entry.key, struct.id.clock, struct.length);
      }
    }
    for (final entry in pendingDeletes.clients.entries) {
      for (final range in entry.value) {
        result.add(entry.key, range.clock, range.length);
      }
    }
    return result;
  }

  void add(YStruct struct) {
    final structs = clients.putIfAbsent(struct.id.client, () => []);
    if (structs.isEmpty ||
        structs.last.id.clock + structs.last.length == struct.id.clock) {
      structs.add(struct);
      return;
    }

    final index = _findIndex(structs, struct.id.clock);
    if (index < 0) throw StateError('StructStore gap before ${struct.id}');
    final existing = structs[index];
    if (existing.id.clock > struct.id.clock ||
        struct.id.clock + struct.length > existing.id.clock + existing.length) {
      throw StateError('StructStore overlap at ${struct.id}');
    }
    final before = struct.id.clock - existing.id.clock;
    final after =
        existing.id.clock + existing.length - (struct.id.clock + struct.length);
    final replacement = <YStruct>[
      if (before > 0) _sliceStruct(existing, 0, before),
      struct,
      if (after > 0)
        _sliceStruct(existing,
            struct.id.clock + struct.length - existing.id.clock, after),
    ];
    structs
      ..removeAt(index)
      ..insertAll(index, replacement);
    skips.remove(struct.id.client, struct.id.clock, struct.length);
  }

  /// Integrates a remote struct when its causal predecessor is available;
  /// otherwise retains it until a later update fills the clock gap.
  List<YStruct> addOrPend(YStruct struct) {
    final existing = getIndex(struct.id);
    if (existing.index >= 0) {
      final value = existing.structs[existing.index];
      final existingEnd = value.id.clock + value.length;
      final incomingEnd = struct.id.clock + struct.length;
      if (incomingEnd <= existingEnd) {
        if (struct.id == value.id &&
            incomingEnd == existingEnd &&
            !_equivalent(value, struct)) {
          if (value is YItem &&
              struct is YItem &&
              struct.deleted &&
              !value.deleted &&
              _equivalentIgnoringDeleted(value, struct)) {
            value.delete();
            return [value];
          }
          throw StateError('Conflicting struct payload at ${struct.id}');
        }
        // A shorter prefix is already represented by the integrated struct;
        // its DeleteSet is applied separately below.
        return const [];
      }
      if (struct.id.clock >= value.id.clock) {
        final offset = existingEnd - struct.id.clock;
        return addOrPend(
            _sliceStruct(struct, offset, incomingEnd - existingEnd));
      }
      throw StateError('Conflicting struct at ${struct.id}');
    }
    if (getClock(struct.id.client) < struct.id.clock) {
      final queue = pending.putIfAbsent(struct.id.client, () => []);
      if (queue.any((value) => value.id == struct.id)) return const [];
      queue.add(struct);
      queue.sort((a, b) => a.id.clock.compareTo(b.id.clock));
      return const [];
    }
    if (getClock(struct.id.client) > struct.id.clock) {
      throw StateError('Overlapping struct at ${struct.id}');
    }
    final added = <YStruct>[struct];
    add(struct);
    final queue = pending[struct.id.client];
    while (queue != null &&
        queue.isNotEmpty &&
        queue.first.id.clock == getClock(struct.id.client)) {
      final next = queue.removeAt(0);
      add(next);
      added.add(next);
    }
    if (queue != null && queue.isEmpty) pending.remove(struct.id.client);
    return added;
  }

  /// Marks an arbitrary clock range as deleted, fragmenting the containing
  /// struct when the range only covers part of an item.
  void deleteRange(YId id, int length) {
    if (length <= 0) return;
    var clock = id.clock;
    var remaining = length;
    while (remaining > 0) {
      final entry = getIndex(YId(id.client, clock));
      if (entry.index < 0) throw StateError('Unknown clock $clock');
      final current = entry.structs[entry.index];
      final offset = clock - current.id.clock;
      final take = remaining.clamp(1, current.length - offset);
      final before = offset;
      final after = current.length - offset - take;
      final replacement = <YStruct>[
        if (before > 0) _sliceStruct(current, 0, before),
        _deletedSlice(current, offset, take),
        if (after > 0) _sliceStruct(current, offset + take, after),
      ];
      entry.structs
        ..removeAt(entry.index)
        ..insertAll(entry.index, replacement);
      clock += take;
      remaining -= take;
    }
  }

  static YStruct _deletedSlice(YStruct struct, int offset, int length) {
    if (struct is YGC)
      return YGC(YId(struct.id.client, struct.id.clock + offset), length);
    if (struct is YItem) {
      final sliced = _sliceStruct(struct, offset, length) as YItem;
      sliced.isDeleted = true;
      return sliced;
    }
    return YGC(YId(struct.id.client, struct.id.clock + offset), length);
  }

  static YStruct _sliceStruct(YStruct struct, int offset, int length) {
    final id = YId(struct.id.client, struct.id.clock + offset);
    if (struct is YGC) return YGC(id, length);
    if (struct is YSkip) return YSkip(id, length);
    if (struct is YItem) {
      final content = switch (struct.content) {
        String value => value.substring(offset, offset + length),
        List value => value.sublist(offset, offset + length),
        YBinaryContent value =>
          YBinaryContent(value.bytes.sublist(offset, offset + length)),
        YDeletedContent() => YDeletedContent(length),
        _ => throw StateError('Cannot split ${struct.content.runtimeType}'),
      };
      return YItem(id, length, content,
          isDeleted: struct.isDeleted,
          origin: struct.origin,
          rightOrigin: struct.rightOrigin,
          parent: struct.parent,
          parentSub: struct.parentSub);
    }
    throw StateError('Cannot split ${struct.runtimeType}');
  }

  static bool _equivalent(YStruct left, YStruct right) {
    if (left.runtimeType != right.runtimeType || left.length != right.length)
      return false;
    if (left is YGC && right is YGC || left is YSkip && right is YSkip) {
      return true;
    }
    if (left is YItem && right is YItem) {
      return left.isDeleted == right.isDeleted &&
          left.parent == right.parent &&
          left.parentSub == right.parentSub &&
          left.origin == right.origin &&
          left.rightOrigin == right.rightOrigin &&
          _deepEqual(left.content, right.content);
    }
    return false;
  }

  static bool _equivalentIgnoringDeleted(YItem left, YItem right) =>
      left.parent == right.parent &&
      left.parentSub == right.parentSub &&
      left.origin == right.origin &&
      left.rightOrigin == right.rightOrigin &&
      _deepEqual(left.content, right.content);

  static bool _deepEqual(dynamic left, dynamic right) {
    if (left is List && right is List) {
      return left.length == right.length &&
          List.generate(left.length, (i) => _deepEqual(left[i], right[i]))
              .every((value) => value);
    }
    if (left is YDeletedContent && right is YDeletedContent)
      return left.length == right.length;
    if (left is YBinaryContent && right is YBinaryContent)
      return _deepEqual(left.bytes, right.bytes);
    if (left is YEmbedContent && right is YEmbedContent)
      return _deepEqual(left.value, right.value);
    return left == right;
  }

  /// Slices a struct for state-vector diff encoding.
  static YStruct sliceForCodec(YStruct struct, int offset, int length) =>
      _sliceStruct(struct, offset, length);

  YStruct get(YId id) {
    final structs = clients[id.client];
    if (structs == null) throw StateError('Unknown client ${id.client}');
    final index = _findIndex(structs, id.clock);
    if (index < 0) throw StateError('Unknown clock ${id.clock}');
    return structs[index];
  }

  int getClock(int client) {
    final structs = clients[client];
    if (structs == null || structs.isEmpty) return 0;
    final last = structs.last;
    return last.id.clock + last.length;
  }

  ({List<YStruct> structs, int index}) getIndex(YId id) {
    final structs = clients[id.client] ?? const <YStruct>[];
    return (structs: structs, index: _findIndex(structs, id.clock));
  }

  YStateVector get stateVector {
    final vector = YStateVector();
    for (final entry in clients.entries) {
      if (entry.value.isNotEmpty)
        vector[entry.key] = entry.value.last.id.clock + entry.value.last.length;
    }
    for (final entry in skips.clients.entries) {
      final ranges = entry.value;
      if (ranges.isNotEmpty) vector[entry.key] = ranges.first.clock;
    }
    return vector;
  }

  void checkIntegrity() {
    for (final structs in clients.values) {
      for (var i = 1; i < structs.length; i++) {
        if (structs[i - 1].id.clock + structs[i - 1].length !=
            structs[i].id.clock) {
          throw StateError('StructStore failed integrity check');
        }
      }
    }
  }

  int _findIndex(List<YStruct> structs, int clock) {
    var low = 0;
    var high = structs.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final value = structs[mid];
      if (clock < value.id.clock) {
        high = mid - 1;
      } else if (clock >= value.id.clock + value.length) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return -1;
  }
}
