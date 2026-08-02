library;

import 'doc.dart';
import 'events.dart';

abstract class YType {
  YDoc? _doc;
  YType? _parent;
  String? _parentKey;
  final List<YObserver> _observers = [];
  final List<YDeepObserver> _deepObservers = [];

  YDoc? get doc => _doc;
  YType? get parent => _parent;
  String? get parentKey => _parentKey;

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

  dynamic get(String key) => _values[key];
  bool containsKey(String key) => _values.containsKey(key);
  int get length => _values.length;
  Iterable<String> get keys => _values.keys;
  Iterable<dynamic> get values => _values.values;
  Iterable<MapEntry<String, dynamic>> get entries => _values.entries;

  dynamic set(String key, dynamic value) {
    _assertValue(value);
    final previous = _values[key];
    if (identical(previous, value) || previous == value) return previous;
    _detach(previous);
    _values[key] = value;
    if (value is YType && doc != null) value.integrate(doc!, this, key);
    _changed(key: key);
    return value;
  }

  dynamic remove(String key) {
    if (!_values.containsKey(key)) return null;
    final old = _values.remove(key);
    _detach(old);
    _changed(key: key);
    return old;
  }

  void clear() {
    final changed = _values.keys.toSet();
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

  void _detach(dynamic value) {
    if (value is YType && identical(value.parent, this)) {
      value._parent = null;
      value._parentKey = null;
    }
  }
}

class YArray extends YType {
  final List<dynamic> _values = [];

  int get length => _values.length;
  dynamic get(int index) => _values[index];
  List<dynamic> toArray() => List<dynamic>.unmodifiable(_values);
  List<dynamic> slice([int start = 0, int? end]) => toArray()
      .sublist(_normalize(start), end == null ? length : _normalize(end));

  void insert(int index, Iterable<dynamic> values) {
    if (index < 0 || index > length) throw RangeError.index(index, this);
    final additions = values.toList(growable: false);
    for (final value in additions) _assertValue(value);
    _values.insertAll(index, additions);
    for (final value in additions) {
      if (value is YType && doc != null) value.integrate(doc!, this, null);
    }
    doc?.recordStruct(
        length: additions.length, content: additions, parent: parentKey ?? '');
    if (additions.isNotEmpty) _changed();
  }

  void push(Iterable<dynamic> values) => insert(length, values);

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
    _changed();
  }

  @override
  List<dynamic> toJson() => List<dynamic>.unmodifiable(_values.map(_jsonValue));

  int _normalize(int index) {
    if (index < 0) return (length + index).clamp(0, length);
    return index.clamp(0, length);
  }
}

class YText extends YType {
  String _text = '';

  int get length => _text.length;
  String get text => _text;

  void insert(int index, String value, [Map<String, dynamic>? attrs]) {
    if (index < 0 || index > length) throw RangeError.index(index, this);
    _text = _text.substring(0, index) + value + _text.substring(index);
    doc?.recordStruct(
        length: value.length, content: value, parent: parentKey ?? '');
    _changed();
  }

  void delete(int index, int count) {
    if (index < 0 || count < 0 || index + count > length) {
      throw RangeError('Invalid text delete range');
    }
    _text = _text.replaceRange(index, index + count, '');
    if (count > 0) _changed();
  }

  @override
  String toString() => _text;

  @override
  String toJson() => _text;
}

void _assertValue(dynamic value) {
  if (value is Function || value is YType && value.doc != null) {
    if (value is YType && value.doc != null) {
      throw StateError('A YType cannot be integrated into two documents');
    }
  }
}

dynamic _jsonValue(dynamic value) => value is YType ? value.toJson() : value;
