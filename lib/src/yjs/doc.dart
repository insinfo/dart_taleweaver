library;

import 'events.dart';
import 'types.dart';

typedef YDocObserver = void Function(YTransaction transaction);

class YTransaction {
  final YDoc doc;
  final Object? origin;
  final List<YEvent> events;

  YTransaction(this.doc, this.origin, this.events);
}

class YDoc {
  final Map<String, YType> _share = {};
  final List<YDocObserver> _afterTransaction = [];
  final List<YEvent> _pendingEvents = [];
  int _transactionDepth = 0;
  Object? _origin;

  YType get(String name) => _share.putIfAbsent(name, () {
        final type = YMap();
        type.integrate(this, null, name);
        return type;
      });

  YMap getMap(String name) => _getAs(name, YMap);
  YArray getArray(String name) => _getAs(name, YArray);
  YText getText(String name) => _getAs(name, YText);

  T _getAs<T extends YType>(String name, Type expected) {
    final type = _share[name];
    if (type != null && type.runtimeType != expected) {
      throw StateError(
          'Shared type "$name" already has type ${type.runtimeType}');
    }
    if (type != null) return type as T;
    final created = switch (expected) {
      const (YMap) => YMap(),
      const (YArray) => YArray(),
      const (YText) => YText(),
      _ => throw ArgumentError('Unsupported shared type'),
    } as T;
    created.integrate(this, null, name);
    _share[name] = created;
    return created;
  }

  void onAfterTransaction(YDocObserver observer) =>
      _afterTransaction.add(observer);
  void offAfterTransaction(YDocObserver observer) =>
      _afterTransaction.remove(observer);

  T transact<T>(T Function() callback, {Object? origin}) {
    _transactionDepth++;
    if (_transactionDepth == 1) _origin = origin;
    try {
      return callback();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        final events = List<YEvent>.of(_pendingEvents);
        _pendingEvents.clear();
        final transaction = YTransaction(this, _origin, events);
        _origin = null;
        if (events.isNotEmpty) {
          final deepNotified = <YType>{};
          final targets = <YType>{for (final event in events) event.target};
          for (final type in targets) {
            type.notifyTransaction(events, deepNotified);
          }
          for (final observer in List<YDocObserver>.of(_afterTransaction)) {
            observer(transaction);
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
        for (final entry in _share.entries) entry.key: entry.value.toJson(),
      };

  void recordChange(YEvent event) {
    if (_transactionDepth == 0) {
      transact(() {
        _pendingEvents.add(event);
      });
    } else {
      _pendingEvents.add(event);
    }
  }
}
