library;

class YIdRange {
  final int clock;
  final int length;
  const YIdRange(this.clock, this.length);
  int get end => clock + length;
}

class YMaybeIdRange extends YIdRange {
  final bool exists;
  const YMaybeIdRange(super.clock, super.length, this.exists);
}

/// A normalized set of client-clock intervals used by Yjs updates and delete sets.
class YIdSet {
  final Map<int, List<YIdRange>> clients = {};

  bool get isEmpty => clients.values.every((ranges) => ranges.isEmpty);

  void add(int client, int clock, int length) {
    if (length <= 0) return;
    final ranges = clients.putIfAbsent(client, () => []);
    ranges.add(YIdRange(clock, length));
    _normalize(ranges);
  }

  void remove(int client, int clock, int length) {
    if (length <= 0) return;
    final ranges = clients[client];
    if (ranges == null) return;
    final end = clock + length;
    final result = <YIdRange>[];
    for (final range in ranges) {
      if (range.end <= clock || range.clock >= end) {
        result.add(range);
        continue;
      }
      if (range.clock < clock) {
        result.add(YIdRange(range.clock, clock - range.clock));
      }
      if (range.end > end) {
        result.add(YIdRange(end, range.end - end));
      }
    }
    if (result.isEmpty) {
      clients.remove(client);
    } else {
      clients[client] = result;
    }
  }

  bool has(int client, int clock) => _find(client, clock) != null;

  bool intersects(int client, int clock, int length) {
    if (length <= 0) return false;
    final range = _find(client, clock);
    if (range != null) return true;
    final ranges = clients[client];
    if (ranges == null) return false;
    return ranges
        .any((value) => value.clock >= clock && value.clock < clock + length);
  }

  bool covers(int client, int clock, int length) {
    if (length < 0) return false;
    final range = _find(client, clock);
    return range != null && clock + length <= range.end;
  }

  int coveredLength(int client, int clock, int length) {
    if (length <= 0) return 0;
    final end = clock + length;
    var covered = 0;
    for (final range in clients[client] ?? const <YIdRange>[]) {
      final from = range.clock < clock ? clock : range.clock;
      final to = range.end > end ? end : range.end;
      if (to > from) covered += to - from;
      if (range.clock >= end) break;
    }
    return covered;
  }

  List<YMaybeIdRange> slice(int client, int clock, int length) {
    if (length <= 0) return const [];
    final end = clock + length;
    final result = <YMaybeIdRange>[];
    var cursor = clock;
    for (final range in clients[client] ?? const <YIdRange>[]) {
      if (range.end <= clock) continue;
      if (range.clock >= end) break;
      final from = range.clock < clock ? clock : range.clock;
      if (from > cursor)
        result.add(YMaybeIdRange(cursor, from - cursor, false));
      final to = range.end > end ? end : range.end;
      if (to > from) {
        result.add(YMaybeIdRange(from, to - from, true));
        cursor = to;
      }
    }
    if (cursor < end) result.add(YMaybeIdRange(cursor, end - cursor, false));
    return result;
  }

  YIdSet copy() {
    final result = YIdSet();
    for (final entry in clients.entries) {
      result.clients[entry.key] = List<YIdRange>.of(entry.value);
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (other is! YIdSet || clients.length != other.clients.length)
      return false;
    for (final entry in clients.entries) {
      final theirs = other.clients[entry.key];
      if (theirs == null || entry.value.length != theirs.length) return false;
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i].clock != theirs[i].clock ||
            entry.value[i].length != theirs[i].length) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      clients.entries.fold(0, (hash, entry) => hash ^ entry.key);

  YIdRange? _find(int client, int clock) {
    for (final range in clients[client] ?? const <YIdRange>[]) {
      if (clock < range.clock) return null;
      if (clock < range.end) return range;
    }
    return null;
  }

  static void _normalize(List<YIdRange> ranges) {
    ranges.sort((a, b) => a.clock.compareTo(b.clock));
    final merged = <YIdRange>[];
    for (final range in ranges) {
      if (range.length <= 0) continue;
      if (merged.isEmpty || range.clock > merged.last.end) {
        merged.add(range);
      } else if (range.end > merged.last.end) {
        final last = merged.removeLast();
        merged.add(YIdRange(last.clock, range.end - last.clock));
      }
    }
    ranges
      ..clear()
      ..addAll(merged);
  }
}
