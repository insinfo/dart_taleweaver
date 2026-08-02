library;

import 'doc.dart';
import 'types.dart';

class YRelativePosition {
  final YText type;
  final int offset;
  final int assoc;

  const YRelativePosition(
      {required this.type, required this.offset, this.assoc = 0});

  Map<String, dynamic> toJson() => {
        'type': type.parentKey,
        'offset': offset,
        'assoc': assoc,
      };
}

YRelativePosition createRelativePosition(YText type, int offset,
    {int assoc = 0}) {
  if (offset < 0 || offset > type.length)
    throw RangeError('Relative position outside text');
  return YRelativePosition(type: type, offset: offset, assoc: assoc);
}

YRelativePosition? relativePositionFromJson(
    YDoc doc, Map<String, dynamic> json) {
  final key = json['type'];
  final offset = json['offset'];
  final assoc = json['assoc'];
  if (key is! String || offset is! int || assoc is! int) return null;
  final type = doc.get(key);
  if (type is! YText || offset < 0 || offset > type.length) return null;
  return YRelativePosition(type: type, offset: offset, assoc: assoc);
}

class YAbsolutePosition {
  final YText type;
  final int offset;
  const YAbsolutePosition({required this.type, required this.offset});
}

YAbsolutePosition? createAbsolutePosition(
    YRelativePosition relative, YDoc doc) {
  if (!identical(relative.type.doc, doc)) return null;
  if (relative.offset < 0 || relative.offset > relative.type.length)
    return null;
  return YAbsolutePosition(type: relative.type, offset: relative.offset);
}
