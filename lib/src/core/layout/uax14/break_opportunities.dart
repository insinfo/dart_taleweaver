library;

import 'line_break_class.dart';

class LineBreakPoint {
  final int index;
  final bool mandatory;
  const LineBreakPoint(this.index, this.mandatory);
}

List<LineBreakPoint> lineBreakOpportunities(String text,
    {bool cjBreakable = false}) {
  final points = <({int offset, LineBreakClass cls})>[];
  var offset = 0;
  for (final rune in text.runes) {
    points.add((offset: offset, cls: lineBreakClass(rune)));
    offset += String.fromCharCode(rune).length;
  }
  final result = <LineBreakPoint>[];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    final mandatory = previous.cls == LineBreakClass.bk ||
        previous.cls == LineBreakClass.cr ||
        previous.cls == LineBreakClass.lf ||
        previous.cls == LineBreakClass.nl;
    if (mandatory) {
      result.add(LineBreakPoint(current.offset, true));
      continue;
    }
    if (previous.cls == LineBreakClass.wj ||
        current.cls == LineBreakClass.wj ||
        current.cls == LineBreakClass.cm ||
        current.cls == LineBreakClass.zwj ||
        previous.cls == LineBreakClass.op ||
        current.cls == LineBreakClass.cl ||
        (previous.cls == LineBreakClass.ri &&
            current.cls == LineBreakClass.ri &&
            i.isOdd)) {
      continue;
    }
    if (previous.cls == LineBreakClass.sp ||
        previous.cls == LineBreakClass.zw ||
        previous.cls == LineBreakClass.hy ||
        previous.cls == LineBreakClass.id ||
        current.cls == LineBreakClass.id ||
        (cjBreakable && current.cls == LineBreakClass.qu)) {
      result.add(LineBreakPoint(current.offset, false));
    }
  }
  return result;
}
