library;

import 'events.dart';
import 'id.dart';
import 'structs.dart';
import 'types.dart';

typedef YDocObserver = void Function(YTransaction transaction);
typedef YBeforeTransactionObserver = void Function(Object? origin);
typedef YUpdateObserver = void Function(List<YStruct> structs, Object? origin);

class YTransaction {
  final YDoc doc;
  final Object? origin;
  final List<YEvent> events;

  YTransaction(this.doc, this.origin, this.events);
}

class YDoc {
  static int _nextClientId = 1;
  final Map<String, YType> _share = {};
  final List<YDocObserver> _afterTransaction = [];
  final List<YBeforeTransactionObserver> _beforeTransaction = [];
  final List<YUpdateObserver> _updateObservers = [];
  final List<YEvent> _pendingEvents = [];
  final List<YStruct> _pendingStructs = [];
  int _transactionDepth = 0;
  Object? _origin;

  final int clientId;
  final YStructStore store = YStructStore();

  bool get inTransaction => _transactionDepth > 0;

  /// Root shared types declared by this document, exposed for causal snapshot
  /// reconstruction without relying on JSON type erasure.
  Iterable<MapEntry<String, YType>> get sharedTypes =>
      _share.entries.map((entry) => MapEntry(entry.key, entry.value));

  YDoc({int? clientId}) : clientId = clientId ?? _nextClientId++;

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
  void onBeforeTransaction(YBeforeTransactionObserver observer) =>
      _beforeTransaction.add(observer);
  void offBeforeTransaction(YBeforeTransactionObserver observer) =>
      _beforeTransaction.remove(observer);
  void onUpdate(YUpdateObserver observer) => _updateObservers.add(observer);
  void offUpdate(YUpdateObserver observer) => _updateObservers.remove(observer);

  T transact<T>(T Function() callback, {Object? origin}) {
    _transactionDepth++;
    if (_transactionDepth == 1) {
      _origin = origin;
      for (final observer
          in List<YBeforeTransactionObserver>.of(_beforeTransaction)) {
        observer(origin);
      }
    }
    try {
      return callback();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        final events = List<YEvent>.of(_pendingEvents);
        _pendingEvents.clear();
        final structs = List<YStruct>.of(_pendingStructs);
        _pendingStructs.clear();
        final transaction = YTransaction(this, _origin, events);
        _origin = null;
        if (events.isNotEmpty) {
          final deepNotified = <YType>{};
          final targets = <YType>{for (final event in events) event.target};
          for (final type in targets) {
            type.notifyTransaction(events, deepNotified);
          }
        }
        for (final observer in List<YDocObserver>.of(_afterTransaction)) {
          observer(transaction);
        }
        if (structs.isNotEmpty) {
          for (final observer in List<YUpdateObserver>.of(_updateObservers)) {
            observer(List<YStruct>.unmodifiable(structs), transaction.origin);
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
        for (final entry in _share.entries) entry.key: entry.value.toJson(),
      };

  /// Typed materialization used by undo snapshots. Unlike [toJson], this
  /// retains the distinction between nested shared types and plain values.
  Map<String, dynamic> snapshotShared() => {
        for (final entry in _share.entries) entry.key: _encodeType(entry.value),
      };

  void restoreSharedSnapshot(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final root = _share[entry.key];
      if (root != null) _restoreType(root, entry.value);
    }
    for (final type in _share.values) {
      if (type is YText) type.rebuildIndexes(store);
    }
  }

  dynamic _encodeType(YType type) {
    if (type is YText) {
      return {'kind': 'text', 'value': type.text, 'delta': type.toDelta()};
    }
    if (type is YArray) {
      return {
        'kind': 'array',
        'values': type.rawValues.map(_encodeValue).toList(growable: false),
      };
    }
    if (type is YMap) {
      return {
        'kind': 'map',
        'values': {
          for (final entry in type.rawEntries)
            entry.key: _encodeValue(entry.value),
        },
      };
    }
    throw StateError('Unsupported shared type ${type.runtimeType}');
  }

  dynamic _encodeValue(dynamic value) {
    if (value is YType) return _encodeType(value);
    if (value is Map) {
      return {
        'kind': 'value-map',
        'values': {
          for (final entry in value.entries)
            '${entry.key}': _encodeValue(entry.value),
        },
      };
    }
    if (value is List) {
      return {
        'kind': 'value-list',
        'values': value.map(_encodeValue).toList(growable: false),
      };
    }
    return {'kind': 'value', 'value': value};
  }

  void _restoreType(YType target, dynamic encoded) {
    if (encoded is! Map) return;
    final kind = encoded['kind'];
    if (target is YText && kind == 'text') {
      final delta = encoded['delta'];
      if (delta is List) {
        target.restoreFromJson('');
        var offset = 0;
        for (final entry in delta) {
          if (entry is! Map || entry['insert'] is! String) continue;
          final text = entry['insert'] as String;
          target.insert(offset, text);
          final attrs = entry['attributes'];
          if (attrs is Map && attrs.isNotEmpty) {
            target.format(
                offset, text.length, Map<String, dynamic>.from(attrs));
          }
          offset += text.length;
        }
      } else {
        target.restoreFromJson(
            encoded['value'] is String ? encoded['value'] : '');
      }
      return;
    }
    if (target is YArray && kind == 'array' && encoded['values'] is List) {
      final old = target.rawValues.toList();
      final next = <dynamic>[];
      final encodedValues = encoded['values'] as List;
      for (var i = 0; i < encodedValues.length; i++) {
        final prior = i < old.length ? old[i] : null;
        next.add(_decodeValue(encodedValues[i], prior));
      }
      target.restoreMaterialized(next);
      return;
    }
    if (target is YMap && kind == 'map' && encoded['values'] is Map) {
      final old = {
        for (final entry in target.rawEntries) entry.key: entry.value
      };
      final next = <String, dynamic>{};
      for (final entry in (encoded['values'] as Map).entries) {
        next['${entry.key}'] = _decodeValue(entry.value, old['${entry.key}']);
      }
      target.restoreMaterialized(next);
    }
  }

  dynamic _decodeValue(dynamic encoded, dynamic prior) {
    if (encoded is! Map) return encoded;
    final kind = encoded['kind'];
    if (kind == 'text') {
      final target = prior is YText ? prior : YText();
      _restoreType(target, encoded);
      return target;
    }
    if (kind == 'array') {
      final target = prior is YArray ? prior : YArray();
      _restoreType(target, encoded);
      return target;
    }
    if (kind == 'map') {
      final target = prior is YMap ? prior : YMap();
      _restoreType(target, encoded);
      return target;
    }
    if (kind == 'value-map' && encoded['values'] is Map) {
      return {
        for (final entry in (encoded['values'] as Map).entries)
          '${entry.key}': _decodeValue(entry.value, null),
      };
    }
    if (kind == 'value-list' && encoded['values'] is List) {
      return (encoded['values'] as List)
          .map((value) => _decodeValue(value, null))
          .toList(growable: false);
    }
    return encoded['value'];
  }

  /// Restores materialized shared values for local history operations. This
  /// deliberately bypasses struct allocation; the CRDT store is restored by
  /// [YUndoManager] alongside these values.
  void restoreFromJson(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final type = _share[entry.key];
      final value = entry.value;
      if (type is YText && value is String) {
        type.restoreFromJson(value);
      } else if (type is YArray && value is List) {
        type.restoreFromJson(value);
      } else if (type is YMap && value is Map) {
        type.restoreFromJson(Map<String, dynamic>.from(value));
      }
    }
    for (final type in _share.values) {
      if (type is YText) type.rebuildIndexes(store);
    }
  }

  /// Materializes a decoded remote item in the corresponding shared type.
  /// Struct-store integration remains separate so this method never creates
  /// a second local update.
  void applyRemoteItem(YItem item) {
    if (item.deleted || item.content is YDeletedContent) return;
    if (item.content case YTypeContent(:final typeRef)) {
      final nested = switch (typeRef) {
        0 => YArray(),
        1 => YMap(),
        3 => YText(),
        _ => null,
      };
      if (nested == null) return;
      final owner = _parentTypeFor(item);
      if (owner is YMap && item.parentSub != null) {
        owner.applyRemote(item.parentSub!, nested, id: item.id);
      } else if (owner is YArray) {
        owner.applyRemote([nested],
            id: item.id, origin: item.origin, rightOrigin: item.rightOrigin);
      }
      return;
    }
    final owner =
        (item.parent is String && (item.parent as String).isNotEmpty) ||
                item.parent is YId ||
                item.parentSub != null ||
                item.origin != null ||
                item.rightOrigin != null
            ? _parentTypeFor(item)
            : null;
    if (owner is YMap && item.parentSub != null) {
      if (item.content is List && item.content.length == 1) {
        owner.applyRemote(item.parentSub!, item.content.first, id: item.id);
        return;
      }
    }
    if (owner is YText && item.content is YFormatContent) {
      final marker = item.content as YFormatContent;
      owner.applyRemoteFormat(marker.key, marker.value,
          origin: item.origin, rightOrigin: item.rightOrigin);
      return;
    }
    if (owner is YText && item.content is String) {
      owner.applyRemote(item.content as String,
          id: item.id, origin: item.origin, rightOrigin: item.rightOrigin);
      return;
    }
    if (owner is YArray && item.content is List) {
      owner.applyRemote(item.content as List,
          id: item.id, origin: item.origin, rightOrigin: item.rightOrigin);
      return;
    }
    final parent = _rootNameFor(item);
    if (parent == null || parent.isEmpty) return;
    final content = item.content;
    if (content is String) {
      final target = getText(parent);
      target.applyRemote(content,
          id: item.id, origin: item.origin, rightOrigin: item.rightOrigin);
    } else if (content is List) {
      if (item.parentSub != null && content.length == 1) {
        getMap(parent).applyRemote(item.parentSub!, content.first, id: item.id);
      } else {
        getArray(parent).applyRemote(content,
            id: item.id, origin: item.origin, rightOrigin: item.rightOrigin);
      }
    }
  }

  YType? _parentTypeFor(YItem item) {
    final parent = item.parent;
    if (parent is String && parent.isEmpty) {
      final causal = item.origin ?? item.rightOrigin;
      if (causal != null) {
        final index = store.getIndex(causal);
        if (index.index >= 0 && index.structs[index.index] is YItem) {
          return _parentTypeFor(index.structs[index.index] as YItem);
        }
      }
      return null;
    }
    if (parent is String && parent.isNotEmpty) {
      final existing = _share[parent];
      if (existing != null) return existing;
      if (item.parentSub != null) return getMap(parent);
      if (item.content is String) return getText(parent);
      if (item.content is List) return getArray(parent);
      return getMap(parent);
    }
    if (parent is! YId) return null;
    final index = store.getIndex(parent);
    if (index.index < 0) return null;
    final parentStruct = index.structs[index.index];
    if (parentStruct is! YItem) return null;
    final owner = _parentTypeFor(parentStruct);
    if (owner is YMap && parentStruct.parentSub != null) {
      final nested = owner.get(parentStruct.parentSub!);
      return nested is YType ? nested : null;
    }
    if (owner is YArray) return owner.typeForItemId(parentStruct.id) ?? owner;
    return owner;
  }

  void applyRemoteDelete(YStruct struct, {int offset = 0, int? length}) {
    if (struct is! YItem) return;
    final take = length ?? struct.length;
    final owner = _parentTypeFor(struct);
    if (owner is YText && struct.content is String) {
      owner.applyRemoteDeleteRange(struct.id, offset, take);
      return;
    }
    if (owner is YArray && struct.content is List) {
      owner.applyRemoteDeleteRange(struct.id, offset, take);
      return;
    }
    if (owner is YMap && struct.content is List && struct.parentSub != null) {
      owner.applyRemoteDelete(struct.id, key: struct.parentSub);
      return;
    }
    final parent = _rootNameFor(struct);
    if (parent == null || parent.isEmpty) return;
    if (struct.content is String) {
      getText(parent).applyRemoteDeleteRange(struct.id, offset, take);
    } else if (struct.content is List && struct.parentSub != null) {
      getMap(parent).applyRemoteDelete(struct.id, key: struct.parentSub);
    } else if (struct.content is List) {
      getArray(parent).applyRemoteDeleteRange(struct.id, offset, take);
    }
  }

  String? _rootNameFor(YItem item) {
    if (item.parent is String && (item.parent as String).isNotEmpty) {
      return item.parent as String;
    }
    final origin = item.origin ?? item.rightOrigin;
    if (origin == null) return null;
    final parentStruct = store.getIndex(origin);
    if (parentStruct.index < 0) return null;
    final parentItem = parentStruct.structs[parentStruct.index];
    return parentItem is YItem ? _rootNameFor(parentItem) : null;
  }

  void recordChange(YEvent event) {
    if (_transactionDepth == 0) {
      transact(() {
        _pendingEvents.add(event);
      });
    } else {
      _pendingEvents.add(event);
    }
  }

  /// Record a locally-created CRDT struct and advance this document's clock.
  /// Shared-type materialization and remote replay are separate steps; this
  /// method only records the causal struct in the document store.
  YId recordStruct({
    required int length,
    required dynamic content,
    Object parent = '',
    String? parentSub,
    YId? origin,
    YId? rightOrigin,
  }) {
    if (length <= 0) throw ArgumentError.value(length, 'length');
    if (_transactionDepth == 0) {
      late YId result;
      transact(() {
        result = _recordStruct(
            length: length,
            content: content,
            parent: parent,
            parentSub: parentSub,
            origin: origin,
            rightOrigin: rightOrigin);
      });
      return result;
    }
    return _recordStruct(
        length: length,
        content: content,
        parent: parent,
        parentSub: parentSub,
        origin: origin,
        rightOrigin: rightOrigin);
  }

  YId _recordStruct({
    required int length,
    required dynamic content,
    required Object parent,
    String? parentSub,
    YId? origin,
    YId? rightOrigin,
  }) {
    final id = YId(clientId, store.getClock(clientId));
    final struct = YItem(id, length, content,
        parent: parent,
        parentSub: parentSub,
        origin: origin,
        rightOrigin: rightOrigin);
    store.add(struct);
    _pendingStructs.add(struct);
    return id;
  }
}
