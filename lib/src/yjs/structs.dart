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

class YItem extends YStruct {
  dynamic content;
  bool isDeleted;

  YItem(super.id, super.length, this.content, {this.isDeleted = false});

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
      YItem(id, length, content, isDeleted: isDeleted);
}

class YStructStore {
  final Map<int, List<YStruct>> clients = {};
  final YIdSet skips = YIdSet();

  YIdSet get deleteSet {
    final result = YIdSet();
    for (final entry in clients.entries) {
      for (final struct in entry.value) {
        if (struct.deleted)
          result.add(entry.key, struct.id.clock, struct.length);
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
      if (before > 0) existing.copyWith(id: existing.id, length: before),
      struct,
      if (after > 0)
        existing.copyWith(
          id: YId(struct.id.client, struct.id.clock + struct.length),
          length: after,
        ),
    ];
    structs
      ..removeAt(index)
      ..insertAll(index, replacement);
    skips.remove(struct.id.client, struct.id.clock, struct.length);
  }

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
