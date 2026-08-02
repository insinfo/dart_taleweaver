library;

import 'doc.dart';
import 'events.dart';
import 'id.dart';
import 'structs.dart';

abstract class YType {
  YDoc? _doc;
  YType? _parent;
  String? _parentKey;
  final List<YObserver> _observers = [];
  final List<YDeepObserver> _deepObservers = [];

  YDoc? get doc => _doc;
  YType? get parent => _parent;
  String? get parentKey => _parentKey;

  /// Causal item that owns this nested shared type, when integrated.
  YId? get parentItemId => _parentItemId;

  YId? get _parentItemId {
    final owner = _parent;
    if (owner is YMap && _parentKey != null) {
      return owner._itemIds[_parentKey];
    }
    if (owner is YArray) return owner._itemIdForValue(this);
    return null;
  }

  void integrate(YDoc doc, YType? parent, String? parentKey) {
    if (_doc != null && !identical(_doc, doc)) {
      throw StateError('A YType cannot be integrated into two documents');
    }
    _doc = doc;
    _parent = parent;
    _parentKey = parentKey;
    if (this is YMap) {
      for (final value in (this as YMap)._values.values) {
        if (value is YType) value.integrate(doc, this, null);
      }
    } else if (this is YArray) {
      for (final value in (this as YArray)._values) {
        if (value is YType) value.integrate(doc, this, null);
      }
    }
  }

  /// Emits the materialized content that existed before this type was
  /// integrated into a parent item. The parent item id must already be known,
  /// otherwise nested structs would lose their causal parent on the wire.
  void emitInitialStructs(YId parentId) {
    final currentDoc = _doc;
    if (currentDoc == null) return;
    if (this is YText) {
      final text = (this as YText)._text;
      if (text.isEmpty) return;
      final id = currentDoc.recordStruct(
          length: text.length, content: text, parent: parentId);
      (this as YText)
        .._segments[id] = (start: 0, length: text.length)
        .._causal[id] = (origin: null, rightOrigin: null);
      final attributes = this as YText;
      final active = <String, dynamic>{};
      for (var offset = 0; offset <= text.length; offset++) {
        final next = offset < attributes._attributes.length
            ? attributes._attributes[offset]
            : const <String, dynamic>{};
        final keys = <String>{...active.keys, ...next.keys};
        for (final key in keys) {
          final before = active[key];
          final after = next[key];
          if (before == after) continue;
          final origin =
              offset == 0 ? null : YId(id.client, id.clock + offset - 1);
          final right =
              offset == text.length ? null : YId(id.client, id.clock + offset);
          currentDoc.recordStruct(
              length: 1,
              content: YFormatContent(key, after),
              parent: parentId,
              origin: origin,
              rightOrigin: right);
          if (after == null) {
            active.remove(key);
          } else {
            active[key] = after;
          }
        }
      }
      return;
    }
    if (this is YMap) {
      final map = this as YMap;
      for (final entry in map._values.entries) {
        final value = entry.value;
        final content = value is YType
            ? YMap._typeContent(value, key: entry.key)
            : <dynamic>[value];
        final id = currentDoc.recordStruct(
            length: 1,
            content: content,
            parent: parentId,
            parentSub: entry.key);
        map._itemIds[entry.key] = id;
        if (value is YType) value.emitInitialStructs(id);
      }
      return;
    }
    if (this is YArray) {
      final array = this as YArray;
      var index = 0;
      while (index < array._values.length) {
        final value = array._values[index];
        if (value is YType) {
          final id = currentDoc.recordStruct(
              length: 1, content: YMap._typeContent(value), parent: parentId);
          array._segments[id] = (start: index, length: 1);
          array._causal[id] = (origin: null, rightOrigin: null);
          value.emitInitialStructs(id);
          index++;
          continue;
        }
        final start = index;
        while (index < array._values.length && array._values[index] is! YType) {
          index++;
        }
        final values = array._values.sublist(start, index);
        final id = currentDoc.recordStruct(
            length: values.length, content: values, parent: parentId);
        array._segments[id] = (start: start, length: values.length);
        array._causal[id] = (origin: null, rightOrigin: null);
      }
    }
  }

  void observe(YObserver observer) => _observers.add(observer);
  void unobserve(YObserver observer) => _observers.remove(observer);
  void observeDeep(YDeepObserver observer) => _deepObservers.add(observer);
  void unobserveDeep(YDeepObserver observer) => _deepObservers.remove(observer);

  void _changed({String? key}) {
    final event = YEvent(target: this, keysChanged: {
      if (key != null) key,
    });
    final currentDoc = _doc;
    if (currentDoc == null) return;
    currentDoc.recordChange(event);
  }

  dynamic toJson();

  void notifyTransaction(List<YEvent> events, Set<YType> deepNotified) {
    final own = events.where((event) => identical(event.target, this)).toList();
    for (final event in own) {
      for (final observer in List<YObserver>.of(_observers)) {
        observer(event);
      }
    }
    if (events.isNotEmpty && deepNotified.add(this)) {
      for (final observer in List<YDeepObserver>.of(_deepObservers)) {
        observer(events);
      }
    }
    _parent?.notifyTransaction(events, deepNotified);
  }
}

class YMap extends YType {
  final Map<String, dynamic> _values = {};
  final Map<String, YId> _itemIds = {};
  final Map<String, YId> _tombstones = {};

  dynamic get(String key) => _values[key];
  bool containsKey(String key) => _values.containsKey(key);
  int get length => _values.length;
  Iterable<String> get keys => _values.keys;
  Iterable<dynamic> get values => _values.values;
  Iterable<MapEntry<String, dynamic>> get entries => _values.entries;

  /// Materialized values used by the document's typed history snapshots.
  Iterable<MapEntry<String, dynamic>> get rawEntries => _values.entries;

  dynamic set(String key, dynamic value) {
    if (doc != null && !doc!.inTransaction) {
      return doc!.transact(() => set(key, value));
    }
    _assertValue(value);
    final previous = _values[key];
    if (identical(previous, value) || previous == value) return previous;
    _detach(previous);
    _values[key] = value;
    if (value is YType && doc != null) value.integrate(doc!, this, key);
    final id = doc?.recordStruct(
        length: 1,
        content: value is YType ? _typeContent(value, key: key) : [value],
        parent: _parentItemId ?? parentKey ?? '',
        parentSub: key);
    if (id != null) {
      _itemIds[key] = id;
      if (value is YType) value.emitInitialStructs(id);
    }
    _tombstones.remove(key);
    _changed(key: key);
    return value;
  }

  static YTypeContent _typeContent(YType value, {String? key}) {
    if (value is YArray) return const YTypeContent(0);
    if (value is YMap) return const YTypeContent(1);
    if (value is YText) return YTypeContent(3, key: key ?? '');
    throw StateError('Unsupported nested YType ${value.runtimeType}');
  }

  dynamic remove(String key) {
    if (doc != null && !doc!.inTransaction) {
      return doc!.transact(() => remove(key));
    }
    if (!_values.containsKey(key)) return null;
    final old = _values.remove(key);
    _detach(old);
    final id = _itemIds.remove(key);
    if (id != null) {
      _tombstones[key] = id;
      doc?.store.deleteRange(id, 1);
    }
    _changed(key: key);
    return old;
  }

  /// Applies a remote ContentAny map item without creating a local struct.
  void applyRemote(String key, dynamic value, {YId? id}) {
    final previousId = _itemIds[key];
    final tombstone = _tombstones[key];
    if (id != null && tombstone != null && _compareIds(id, tombstone) <= 0) {
      return;
    }
    if (id != null && previousId != null && _compareIds(id, previousId) <= 0) {
      return;
    }
    _detach(_values[key]);
    _values[key] = value;
    if (value is YType && doc != null) value.integrate(doc!, this, key);
    if (id != null) _itemIds[key] = id;
    _tombstones.remove(key);
    _changed(key: key);
  }

  static int _compareIds(YId a, YId b) {
    final client = a.client.compareTo(b.client);
    return client != 0 ? client : a.clock.compareTo(b.clock);
  }

  void applyRemoteDelete(YId id, {String? key}) {
    key ??= _itemIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .firstOrNull;
    if (key == null) return;
    final currentId = _itemIds[key];
    if (currentId != null &&
        currentId != id &&
        _compareIds(id, currentId) < 0) {
      return;
    }
    final value = _values.remove(key);
    _itemIds.remove(key);
    final previousTombstone = _tombstones[key];
    if (previousTombstone == null || _compareIds(id, previousTombstone) > 0) {
      _tombstones[key] = id;
    }
    _detach(value);
    if (value != null || currentId != null) _changed(key: key);
  }

  void clear() {
    if (doc != null && !doc!.inTransaction) {
      doc!.transact(clear);
      return;
    }
    final changed = _values.keys.toSet();
    for (final id in _itemIds.values) {
      doc?.store.deleteRange(id, 1);
    }
    _itemIds.clear();
    for (final value in _values.values) _detach(value);
    _values.clear();
    if (changed.isNotEmpty) {
      _doc?.recordChange(YEvent(target: this, keysChanged: changed));
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        for (final entry in _values.entries) entry.key: _jsonValue(entry.value),
      };

  /// Internal history restore that does not allocate CRDT structs.
  void restoreFromJson(Map<String, dynamic> values) {
    _values
      ..clear()
      ..addAll(values);
    _itemIds.clear();
    _tombstones.clear();
  }

  void restoreMaterialized(Map<String, dynamic> values) {
    _values
      ..clear()
      ..addAll(values);
    _itemIds.clear();
    _tombstones.clear();
    for (final entry in _values.entries) {
      if (entry.value is YType && doc != null) {
        (entry.value as YType).integrate(doc!, this, entry.key);
      }
    }
  }

  void _detach(dynamic value) {
    if (value is YType && identical(value.parent, this)) {
      value._parent = null;
      value._parentKey = null;
    }
  }
}

class YArray extends YType {
  final List<dynamic> _values = [];
  final Map<YId, ({int start, int length})> _segments = {};
  final Map<YId, ({YId? origin, YId? rightOrigin})> _causal = {};
  final Set<YId> _tombstones = {};

  int get length => _values.length;
  dynamic get(int index) => _values[index];
  List<dynamic> toArray() => List<dynamic>.unmodifiable(_values);

  /// Materialized values used by the document's typed history snapshots.
  List<dynamic> get rawValues => _values;
  List<dynamic> slice([int start = 0, int? end]) => toArray()
      .sublist(_normalize(start), end == null ? length : _normalize(end));

  YId? _itemIdForValue(YType value) {
    final index = _values.indexOf(value);
    if (index < 0) return null;
    for (final entry in _segments.entries) {
      if (index >= entry.value.start &&
          index < entry.value.start + entry.value.length) {
        return YId(
            entry.key.client, entry.key.clock + index - entry.value.start);
      }
    }
    return null;
  }

  YType? typeForItemId(YId id) {
    final segment = _segments[id];
    if (segment == null) return null;
    for (var i = 0; i < segment.length; i++) {
      final value = _values[segment.start + i];
      if (value is YType) return value;
    }
    return null;
  }

  void insert(int index, Iterable<dynamic> values) {
    if (doc != null && !doc!.inTransaction) {
      doc!.transact(() => insert(index, values));
      return;
    }
    if (index < 0 || index > length) throw RangeError.index(index, this);
    final additions = values.toList(growable: false);
    if (additions.isEmpty) return;
    for (final value in additions) _assertValue(value);
    _values.insertAll(index, additions);
    for (final value in additions) {
      if (value is YType && doc != null) value.integrate(doc!, this, null);
    }
    YId? origin;
    YId? rightOrigin;
    for (final entry in _segments.entries) {
      if (entry.value.start + entry.value.length == index) origin = entry.key;
      if (entry.value.start == index) rightOrigin = entry.key;
    }
    var runOffset = 0;
    var runOrigin = origin;
    var runRightOrigin = rightOrigin;
    while (runOffset < additions.length) {
      final value = additions[runOffset];
      final isType = value is YType;
      var runLength = 1;
      if (!isType) {
        while (runOffset + runLength < additions.length &&
            additions[runOffset + runLength] is! YType) {
          runLength++;
        }
      }
      final content = isType
          ? YMap._typeContent(value)
          : additions.sublist(runOffset, runOffset + runLength);
      final id = doc?.recordStruct(
          length: runLength,
          content: content,
          parent: _parentItemId ?? parentKey ?? '',
          origin: runOrigin,
          rightOrigin: runRightOrigin);
      if (id != null) {
        _segments[id] = (start: index + runOffset, length: runLength);
        _causal[id] = (origin: runOrigin, rightOrigin: runRightOrigin);
        if (isType) value.emitInitialStructs(id);
        runOrigin = id;
        runRightOrigin = null;
      }
      runOffset += runLength;
    }
    if (additions.isNotEmpty) _changed();
  }

  void push(Iterable<dynamic> values) => insert(length, values);

  void clear() {
    if (doc != null && !doc!.inTransaction) {
      doc!.transact(clear);
      return;
    }
    if (_values.isEmpty) return;
    for (final entry in _segments.entries) {
      doc?.store.deleteRange(entry.key, entry.value.length);
      _tombstones.add(entry.key);
    }
    for (final value in _values) {
      if (value is YType && identical(value.parent, this)) value._parent = null;
    }
    _values.clear();
    _segments.clear();
    _causal.clear();
    _changed();
  }

  void applyRemoteDelete(YId id, int count) {
    applyRemoteDeleteRange(id, 0, count);
  }

  void applyRemoteDeleteRange(YId id, int offset, int count) {
    final segment = _segments[id];
    if (segment == null) {
      for (var i = 0; i < count; i++) {
        _tombstones.add(YId(id.client, id.clock + offset + i));
      }
      return;
    }
    final take = count.clamp(0, segment.length - offset);
    final start = segment.start + offset;
    final end = start + take;
    _values.removeRange(start, end);
    final causal = _causal[id];
    _segments.remove(id);
    _causal.remove(id);
    final leftLength = offset;
    final rightLength = segment.length - offset - take;
    if (leftLength > 0) {
      _segments[id] = (start: segment.start, length: leftLength);
      if (causal != null) _causal[id] = causal;
    }
    if (rightLength > 0) {
      final rightId = YId(id.client, id.clock + offset + take);
      _segments[rightId] = (start: segment.start + offset, length: rightLength);
      if (causal != null) _causal[rightId] = causal;
    }
    _tombstones.add(id);
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= end) {
        _segments[entry.key] =
            (start: entry.value.start - take, length: entry.value.length);
      }
    }
    _changed();
  }

  /// Applies an already-integrated remote ContentAny item without allocating
  /// a second local struct or emitting an update for the remote operation.
  void applyRemote(Iterable<dynamic> values,
      {YId? id, YId? origin, YId? rightOrigin}) {
    final additions = values.toList(growable: false);
    if (additions.isEmpty) return;
    if (id != null &&
        (_segments.containsKey(id) ||
            _hasTombstone(_tombstones, id, additions.length))) return;
    final oldLength = length;
    var start = oldLength;
    if (origin != null) {
      final segment = _segments[origin];
      if (segment != null) start = segment.start + segment.length;
    } else if (rightOrigin != null) {
      start = _segments[rightOrigin]?.start ?? start;
    }
    if (id != null) {
      final concurrent = _causal.entries
          .where((entry) =>
              entry.value.origin == origin &&
              entry.value.rightOrigin == rightOrigin)
          .toList()
        ..sort((a, b) => _compareIds(a.key, b.key));
      for (final entry in concurrent) {
        final segment = _segments[entry.key]!;
        if (_compareIds(entry.key, id) < 0) {
          final end = segment.start + segment.length;
          if (end > start) start = end;
        } else if (_compareIds(entry.key, id) > 0 && segment.start < start) {
          start = segment.start;
          break;
        }
      }
    }
    _values.insertAll(start, additions);
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= start) {
        _segments[entry.key] = (
          start: entry.value.start + additions.length,
          length: entry.value.length
        );
      }
    }
    if (id != null) {
      _segments[id] = (start: start, length: additions.length);
      _causal[id] = (origin: origin, rightOrigin: rightOrigin);
      _tombstones.remove(id);
    }
    for (final value in additions) {
      if (value is YType && doc != null) value.integrate(doc!, this, null);
    }
    _changed();
  }

  void delete(int index, [int count = 1]) {
    if (index < 0 || index > length) throw RangeError.index(index, this);
    if (count < 0 || index + count > length)
      throw RangeError('Invalid delete range');
    if (count == 0) return;
    final removed = _values.sublist(index, index + count);
    _values.removeRange(index, index + count);
    for (final value in removed) {
      if (value is YType && identical(value.parent, this)) value._parent = null;
    }
    final end = index + count;
    for (final entry in _segments.entries.toList()) {
      final segmentStart = entry.value.start;
      final segmentEnd = segmentStart + entry.value.length;
      final overlapStart = index > segmentStart ? index : segmentStart;
      final overlapEnd = end < segmentEnd ? end : segmentEnd;
      if (overlapStart < overlapEnd) {
        doc?.store.deleteRange(
          YId(entry.key.client, entry.key.clock + overlapStart - segmentStart),
          overlapEnd - overlapStart,
        );
        final causal = _causal[entry.key];
        _segments.remove(entry.key);
        _causal.remove(entry.key);
        final leftLength = overlapStart - segmentStart;
        final rightLength = segmentEnd - overlapEnd;
        if (leftLength > 0) {
          _segments[entry.key] = (start: segmentStart, length: leftLength);
          if (causal != null) _causal[entry.key] = causal;
        }
        if (rightLength > 0) {
          final rightId = YId(
              entry.key.client, entry.key.clock + (overlapEnd - segmentStart));
          _segments[rightId] = (
            start: segmentStart + leftLength,
            length: rightLength,
          );
          if (causal != null) _causal[rightId] = causal;
        }
        _tombstones.add(entry.key);
      }
    }
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= end) {
        _segments[entry.key] =
            (start: entry.value.start - count, length: entry.value.length);
      }
    }
    _changed();
  }

  @override
  List<dynamic> toJson() => List<dynamic>.unmodifiable(_values.map(_jsonValue));

  /// Internal history restore that does not allocate CRDT structs.
  void restoreFromJson(List<dynamic> values) {
    _values
      ..clear()
      ..addAll(values);
    _segments.clear();
    _causal.clear();
    _tombstones.clear();
  }

  void restoreMaterialized(List<dynamic> values) {
    _values
      ..clear()
      ..addAll(values);
    _segments.clear();
    _causal.clear();
    _tombstones.clear();
    for (final value in _values) {
      if (value is YType && doc != null) value.integrate(doc!, this, null);
    }
  }

  static int _compareIds(YId a, YId b) {
    final client = a.client.compareTo(b.client);
    return client != 0 ? client : a.clock.compareTo(b.clock);
  }

  int _normalize(int index) {
    if (index < 0) return (length + index).clamp(0, length);
    return index.clamp(0, length);
  }
}

class YText extends YType {
  String _text = '';
  final List<Map<String, dynamic>> _attributes = [];
  final Map<YId, ({int start, int length})> _segments = {};
  final Map<YId, ({YId? origin, YId? rightOrigin})> _causal = {};
  final Set<YId> _tombstones = {};
  final Map<YId, int> _deletedAnchorPositions = {};

  int get length => _text.length;
  String get text => _text;

  /// Materialized Y.Text delta with adjacent equal-attribute runs coalesced.
  List<Map<String, dynamic>> toDelta() {
    final result = <Map<String, dynamic>>[];
    var start = 0;
    while (start < _text.length) {
      final attrs = start < _attributes.length
          ? _attributes[start]
          : const <String, dynamic>{};
      var end = start + 1;
      while (end < _text.length &&
          _sameAttributes(
              attrs, end < _attributes.length ? _attributes[end] : const {})) {
        end++;
      }
      final entry = <String, dynamic>{'insert': _text.substring(start, end)};
      if (attrs.isNotEmpty) entry['attributes'] = Map.of(attrs);
      result.add(entry);
      start = end;
    }
    return result;
  }

  /// Applies inline attributes to a UTF-16 range. Null values remove keys.
  void format(int index, int count, Map<String, dynamic> attributes,
      {bool recordCausal = true}) {
    if (index < 0 || count < 0 || index + count > length) {
      throw RangeError('Invalid text format range');
    }
    if (count == 0 || attributes.isEmpty) return;
    final end = index + count;
    final startOrigin = index == 0 ? null : relativeAnchor(index, 1);
    final startRight = relativeAnchor(index, -1);
    final endOrigin = end == 0 ? null : relativeAnchor(end, 1);
    final endRight = relativeAnchor(end, -1);
    final priorAtEnd = end < _attributes.length
        ? Map<String, dynamic>.of(_attributes[end])
        : const <String, dynamic>{};
    while (_attributes.length < _text.length) {
      _attributes.add(<String, dynamic>{});
    }
    var changed = false;
    for (var offset = index; offset < index + count; offset++) {
      final current = _attributes[offset];
      final next = Map<String, dynamic>.of(current);
      for (final entry in attributes.entries) {
        if (entry.value == null) {
          next.remove(entry.key);
        } else {
          next[entry.key] = entry.value;
        }
      }
      if (!_sameAttributes(current, next)) {
        _attributes[offset] = next;
        changed = true;
      }
    }
    if (!changed) return;
    if (recordCausal && doc != null) {
      final parent = _parentItemId ?? parentKey ?? '';
      for (final entry in attributes.entries) {
        doc!.recordStruct(
            length: 1,
            content: YFormatContent(entry.key, entry.value),
            parent: parent,
            origin: startOrigin,
            rightOrigin: startRight);
        doc!.recordStruct(
            length: 1,
            content: YFormatContent(entry.key, priorAtEnd[entry.key]),
            parent: parent,
            origin: endOrigin,
            rightOrigin: endRight);
      }
    }
    _changed();
  }

  /// Applies a causal format marker received from a remote update. Yjs
  /// represents formatting as zero-width marker items; without a full marker
  /// interval index, the marker's effect is conservatively applied from its
  /// causal boundary to the end of the current visible text.
  void applyRemoteFormat(String key, dynamic value,
      {YId? origin, YId? rightOrigin}) {
    var index = 0;
    if (origin != null) {
      index = _positionAfterAnchor(origin);
      // A deleted/compacted origin can no longer resolve locally. In that
      // case the right anchor still identifies the same causal boundary.
      if (index >= length && rightOrigin != null) {
        index = _positionAtAnchor(rightOrigin);
      }
    } else if (rightOrigin != null) {
      index = _positionAtAnchor(rightOrigin);
    }
    if (index >= length) return;
    format(index, length - index, {key: value}, recordCausal: false);
  }

  int _positionAfterAnchor(YId anchor) {
    final direct = _segments[anchor];
    if (direct != null) return direct.start + 1;
    for (final entry in _segments.entries) {
      if (entry.key.client != anchor.client) continue;
      final delta = anchor.clock - entry.key.clock;
      if (delta >= 0 && delta < entry.value.length) {
        return entry.value.start + delta + 1;
      }
    }
    return length;
  }

  int _positionAtAnchor(YId anchor) {
    final direct = _segments[anchor];
    if (direct != null) return direct.start;
    for (final entry in _segments.entries) {
      if (entry.key.client != anchor.client) continue;
      final delta = anchor.clock - entry.key.clock;
      if (delta >= 0 && delta < entry.value.length) {
        return entry.value.start + delta;
      }
    }
    return length;
  }

  YId? relativeAnchor(int offset, int assoc) {
    for (final entry in _segments.entries) {
      final end = entry.value.start + entry.value.length;
      if (offset < entry.value.start || offset > end) continue;
      if (assoc < 0 && offset < end) {
        return YId(
            entry.key.client, entry.key.clock + (offset - entry.value.start));
      }
      if (assoc >= 0 && offset > entry.value.start) {
        return YId(entry.key.client,
            entry.key.clock + (offset - entry.value.start - 1));
      }
    }
    return null;
  }

  int resolveAnchor(YId? id, int assoc, int fallback) {
    if (id == null) return fallback.clamp(0, length);
    final segment = _segments[id];
    if (segment != null) {
      // A relative item always identifies one character, even when it is
      // the first character of a multi-character segment. Positive
      // association therefore advances by one UTF-16 unit, rather than
      // jumping to the segment's end.
      var value = assoc < 0 ? segment.start : segment.start + 1;
      if (assoc >= 0 && segment.length > 1) {
        // Concurrent inserts that materialize as a separate segment directly
        // after the anchored character are part of the right-associated
        // boundary. Do not jump across the remainder of the original
        // segment, which would lose internal UTF-16 precision.
        for (final entry in _segments.entries) {
          if (entry.key == id || entry.value.start != value) continue;
          if (_compareIds(entry.key, id) > 0) value += entry.value.length;
        }
      }
      return value.clamp(0, length);
    }
    final deleted = _deletedAnchorPositions[id];
    if (deleted != null) return deleted.clamp(0, length);
    for (final entry in _segments.entries) {
      if (entry.key.client != id.client) continue;
      final delta = id.clock - entry.key.clock;
      if (delta < 0 || delta >= entry.value.length) continue;
      final value =
          assoc < 0 ? entry.value.start + delta : entry.value.start + delta + 1;
      return value.clamp(0, length);
    }
    // A deleted anchor resolves to the nearest surviving boundary. The
    // fallback remains the original absolute offset when no causal fragment
    // is available, matching Yjs' best-effort resolution contract.
    return fallback.clamp(0, length);
  }

  void applyRemoteDelete(YId id, int count) {
    applyRemoteDeleteRange(id, 0, count);
  }

  void applyRemoteDeleteRange(YId id, int offset, int count) {
    // YText implementation (the preceding YArray has the same method name).
    final segment = _segments[id];
    if (segment == null) {
      for (var i = 0; i < count; i++) {
        _tombstones.add(YId(id.client, id.clock + offset + i));
      }
      return;
    }
    final take = count.clamp(0, segment.length - offset);
    final start = segment.start + offset;
    for (var i = 0; i < take; i++) {
      _deletedAnchorPositions[YId(id.client, id.clock + offset + i)] = start;
    }
    _text = _text.replaceRange(start, start + take, '');
    if (start + take <= _attributes.length) {
      _attributes.removeRange(start, start + take);
    }
    final causal = _causal[id];
    _segments.remove(id);
    _causal.remove(id);
    final leftLength = offset;
    final rightLength = segment.length - offset - take;
    if (leftLength > 0) {
      _segments[id] = (start: segment.start, length: leftLength);
      if (causal != null) _causal[id] = causal;
    }
    if (rightLength > 0) {
      final rightId = YId(id.client, id.clock + offset + take);
      _segments[rightId] = (start: segment.start + offset, length: rightLength);
      if (causal != null) _causal[rightId] = causal;
    }
    _tombstones.add(id);
    for (final entry in _segments.entries.toList()) {
      if (entry.key != id && entry.value.start >= start + take) {
        _segments[entry.key] =
            (start: entry.value.start - take, length: entry.value.length);
      }
    }
    _changed();
  }

  void insert(int index, String value, [Map<String, dynamic>? attrs]) {
    if (doc != null && !doc!.inTransaction) {
      doc!.transact(() => insert(index, value, attrs));
      return;
    }
    if (index < 0 || index > length) throw RangeError.index(index, this);
    if (value.isEmpty) return;
    while (_attributes.length < _text.length) {
      _attributes.add(<String, dynamic>{});
    }
    YId? origin;
    YId? rightOrigin;
    for (final entry in _segments.entries) {
      if (entry.value.start + entry.value.length == index) origin = entry.key;
      if (entry.value.start == index) rightOrigin = entry.key;
    }
    _text = _text.substring(0, index) + value + _text.substring(index);
    _attributes.insertAll(
        index,
        List<Map<String, dynamic>>.generate(
            value.length, (_) => Map<String, dynamic>.of(attrs ?? const {})));
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= index) {
        _segments[entry.key] = (
          start: entry.value.start + value.length,
          length: entry.value.length
        );
      }
    }
    final id = doc?.recordStruct(
        length: value.length,
        content: value,
        parent: _parentItemId ?? parentKey ?? '',
        origin: origin,
        rightOrigin: rightOrigin);
    if (id != null) {
      _segments[id] = (start: index, length: value.length);
      _causal[id] = (origin: origin, rightOrigin: rightOrigin);
    }
    _changed();
  }

  /// Applies a remote ContentString item at its causal position.
  void applyRemote(String value, {YId? id, YId? origin, YId? rightOrigin}) {
    if (id != null &&
        (_segments.containsKey(id) ||
            _hasTombstone(_tombstones, id, value.length))) {
      return;
    }
    while (_attributes.length < _text.length) {
      _attributes.add(<String, dynamic>{});
    }
    var index = _text.length;
    if (origin != null) {
      final segment = _segments[origin];
      if (segment != null) index = segment.start + segment.length;
    } else if (rightOrigin != null) {
      index = _segments[rightOrigin]?.start ?? index;
    }
    if (id != null) {
      final concurrent = _causal.entries
          .where((entry) =>
              entry.value.origin == origin &&
              entry.value.rightOrigin == rightOrigin)
          .toList()
        ..sort((a, b) => _compareIds(a.key, b.key));
      for (final entry in concurrent) {
        final segment = _segments[entry.key]!;
        if (_compareIds(entry.key, id) < 0) {
          final end = segment.start + segment.length;
          if (end > index) index = end;
        } else if (_compareIds(entry.key, id) > 0 && segment.start < index) {
          index = segment.start;
          break;
        }
      }
    }
    _text = _text.substring(0, index) + value + _text.substring(index);
    _attributes.insertAll(
        index, List<Map<String, dynamic>>.generate(value.length, (_) => {}));
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= index) {
        _segments[entry.key] = (
          start: entry.value.start + value.length,
          length: entry.value.length
        );
      }
    }
    if (id != null) {
      _segments[id] = (start: index, length: value.length);
      _causal[id] = (origin: origin, rightOrigin: rightOrigin);
      _tombstones.remove(id);
    }
    _changed();
  }

  void delete(int index, int count) {
    if (doc != null && !doc!.inTransaction) {
      doc!.transact(() => delete(index, count));
      return;
    }
    if (index < 0 || count < 0 || index + count > length) {
      throw RangeError('Invalid text delete range');
    }
    final end = index + count;
    for (final entry in _segments.entries.toList()) {
      final segmentStart = entry.value.start;
      final segmentEnd = segmentStart + entry.value.length;
      final overlapStart = index > segmentStart ? index : segmentStart;
      final overlapEnd = end < segmentEnd ? end : segmentEnd;
      if (overlapStart < overlapEnd) {
        final deleteId = YId(
            entry.key.client, entry.key.clock + overlapStart - segmentStart);
        doc?.store.deleteRange(deleteId, overlapEnd - overlapStart);
        final causal = _causal[entry.key];
        for (var clock = overlapStart; clock < overlapEnd; clock++) {
          _deletedAnchorPositions[YId(
                  entry.key.client, entry.key.clock + clock - segmentStart)] =
              overlapStart;
        }
        _segments.remove(entry.key);
        _causal.remove(entry.key);
        final leftLength = overlapStart - segmentStart;
        final rightLength = segmentEnd - overlapEnd;
        if (leftLength > 0) {
          _segments[entry.key] = (start: segmentStart, length: leftLength);
          if (causal != null) _causal[entry.key] = causal;
        }
        if (rightLength > 0) {
          final rightId = YId(
              entry.key.client, entry.key.clock + (overlapEnd - segmentStart));
          _segments[rightId] = (
            start: segmentStart + leftLength,
            length: rightLength,
          );
          if (causal != null) _causal[rightId] = causal;
        }
        _tombstones.add(entry.key);
      }
    }
    _text = _text.replaceRange(index, end, '');
    if (end <= _attributes.length) _attributes.removeRange(index, end);
    for (final entry in _segments.entries.toList()) {
      if (entry.value.start >= end) {
        _segments[entry.key] =
            (start: entry.value.start - count, length: entry.value.length);
      }
    }
    if (count > 0) _changed();
  }

  @override
  String toString() => _text;

  /// Internal history restore that does not allocate CRDT structs.
  void restoreFromJson(String value) {
    _text = value;
    _attributes
      ..clear()
      ..addAll(List<Map<String, dynamic>>.generate(
          value.length, (_) => <String, dynamic>{}));
    _segments.clear();
    _causal.clear();
    _tombstones.clear();
    _deletedAnchorPositions.clear();
  }

  /// Rebuilds the causal segment index after a snapshot-based history
  /// restore. Materialized JSON alone cannot retain relative-position item
  /// identities, so visible text structs are indexed again in store order.
  void rebuildIndexes(YStructStore store) {
    final expectedParent = _parentItemId ?? parentKey ?? '';
    _segments.clear();
    _causal.clear();
    _tombstones.clear();
    _deletedAnchorPositions.clear();
    _attributes
      ..clear()
      ..addAll(List<Map<String, dynamic>>.generate(
          _text.length, (_) => <String, dynamic>{}));
    var offset = 0;
    for (final structs in store.clients.values) {
      for (final struct in structs) {
        if (struct is! YItem) {
          continue;
        }
        if (struct.content is YFormatContent &&
            struct.parent == expectedParent) {
          continue;
        }
        if (struct.content is! String) continue;
        if (struct.parent != (parentKey ?? '')) continue;
        final value = struct.content as String;
        if (struct.deleted) {
          for (var i = 0; i < struct.length; i++) {
            _deletedAnchorPositions[
                YId(struct.id.client, struct.id.clock + i)] = offset;
          }
          continue;
        }
        _segments[struct.id] = (start: offset, length: value.length);
        _causal[struct.id] =
            (origin: struct.origin, rightOrigin: struct.rightOrigin);
        offset += value.length;
      }
    }
    final markers = <YItem>[];
    for (final structs in store.clients.values) {
      for (final struct in structs) {
        if (struct is YItem &&
            struct.content is YFormatContent &&
            struct.parent == expectedParent) {
          markers.add(struct);
        }
      }
    }
    markers.sort((a, b) => _compareIds(a.id, b.id));
    for (final marker in markers) {
      final format = marker.content as YFormatContent;
      var start =
          marker.origin == null ? 0 : _positionAfterAnchor(marker.origin!);
      if (start >= _text.length && marker.rightOrigin != null) {
        start = _positionAtAnchor(marker.rightOrigin!);
      }
      if (start >= _text.length) continue;
      for (var i = start; i < _attributes.length; i++) {
        if (format.value == null) {
          _attributes[i].remove(format.key);
        } else {
          _attributes[i][format.key] = format.value;
        }
      }
    }
  }

  @override
  String toJson() => _text;
}

int _compareIds(YId left, YId right) {
  final client = left.client.compareTo(right.client);
  return client != 0 ? client : left.clock.compareTo(right.clock);
}

void _assertValue(dynamic value) {
  if (value is Function || value is YType && value.doc != null) {
    if (value is YType && value.doc != null) {
      throw StateError('A YType cannot be integrated into two documents');
    }
  }
}

dynamic _jsonValue(dynamic value) => value is YType ? value.toJson() : value;

bool _sameAttributes(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _hasTombstone(Set<YId> tombstones, YId id, int length) {
  for (var i = 0; i < length; i++) {
    if (tombstones.contains(YId(id.client, id.clock + i))) return true;
  }
  return false;
}
