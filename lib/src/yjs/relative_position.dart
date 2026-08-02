library;

import 'doc.dart';
import 'id.dart';
import 'types.dart';

class YRelativePosition {
  final YText type;
  final int offset;
  final int assoc;
  final YId? item;

  const YRelativePosition(
      {required this.type, required this.offset, this.assoc = 0, this.item});

  Map<String, dynamic> toJson() => {
        if (type.parentKey != null) 'type': type.parentKey,
        'offset': offset,
        'assoc': assoc,
        if (item != null)
          'item': {'client': item!.client, 'clock': item!.clock},
        if (type.parentItemId != null)
          'typeItem': {
            'client': type.parentItemId!.client,
            'clock': type.parentItemId!.clock,
          },
      };
}

YRelativePosition createRelativePosition(YText type, int offset,
    {int assoc = 0}) {
  if (offset < 0 || offset > type.length)
    throw RangeError('Relative position outside text');
  return YRelativePosition(
      type: type,
      offset: offset,
      assoc: assoc,
      item: type.relativeAnchor(offset, assoc));
}

YRelativePosition? relativePositionFromJson(
    YDoc doc, Map<String, dynamic> json) {
  final offset = json['offset'];
  final assoc = json['assoc'];
  if (offset is! int || assoc is! int) return null;
  YText? type;
  final rawTypeItem = json['typeItem'];
  if (rawTypeItem is Map) {
    final client = rawTypeItem['client'];
    final clock = rawTypeItem['clock'];
    if (client is int && clock is int) {
      type = _findNestedText(doc, YId(client, clock));
    }
  }
  final key = json['type'];
  if (type == null && key is String) {
    final candidate = doc.get(key);
    if (candidate is YText) type = candidate;
  }
  if (type == null) return null;
  if (offset < 0 || offset > type.length) return null;
  YId? item;
  final rawItem = json['item'];
  if (rawItem is Map && rawItem['client'] is int && rawItem['clock'] is int) {
    item = YId(rawItem['client'] as int, rawItem['clock'] as int);
  }
  return YRelativePosition(
      type: type, offset: offset, assoc: assoc, item: item);
}

YText? _findNestedText(YDoc doc, YId parentItem) {
  YText? visit(dynamic value) {
    if (value is YText) {
      if (value.parentItemId == parentItem) return value;
      return null;
    }
    if (value is YMap) {
      for (final entry in value.rawEntries) {
        final found = visit(entry.value);
        if (found != null) return found;
      }
    } else if (value is YArray) {
      for (final child in value.rawValues) {
        final found = visit(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  for (final entry in doc.sharedTypes) {
    final found = visit(entry.value);
    if (found != null) return found;
  }
  return null;
}

class YAbsolutePosition {
  final YText type;
  final int offset;

  /// Association preserved from the relative position. Negative values keep
  /// the caret on the left of concurrent insertions; non-negative values keep
  /// it on the right, matching Yjs' `AbsolutePosition.assoc` contract.
  final int assoc;
  const YAbsolutePosition(
      {required this.type, required this.offset, this.assoc = 0});
}

YAbsolutePosition? createAbsolutePosition(
    YRelativePosition relative, YDoc doc) {
  if (!identical(relative.type.doc, doc)) return null;
  if (relative.offset < 0 ||
      (relative.item == null && relative.offset > relative.type.length))
    return null;
  return YAbsolutePosition(
      type: relative.type,
      offset: relative.type
          .resolveAnchor(relative.item, relative.assoc, relative.offset),
      assoc: relative.assoc);
}
