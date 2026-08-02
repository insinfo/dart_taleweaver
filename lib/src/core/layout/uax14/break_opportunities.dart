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
    points.add(
        (offset: offset, cls: _resolve(lineBreakClass(rune), cjBreakable)));
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
    // LB6: never break before a mandatory break; LB7: no break before SP/ZW.
    if (current.cls == LineBreakClass.bk ||
        current.cls == LineBreakClass.cr ||
        current.cls == LineBreakClass.lf ||
        current.cls == LineBreakClass.nl ||
        current.cls == LineBreakClass.sp ||
        current.cls == LineBreakClass.zw ||
        previous.cls == LineBreakClass.wj ||
        current.cls == LineBreakClass.wj ||
        current.cls == LineBreakClass.cm ||
        current.cls == LineBreakClass.zwj ||
        previous.cls == LineBreakClass.op ||
        current.cls == LineBreakClass.cl ||
        current.cls == LineBreakClass.cp ||
        current.cls == LineBreakClass.ex ||
        current.cls == LineBreakClass.sy ||
        current.cls == LineBreakClass.ba ||
        current.cls == LineBreakClass.hy ||
        current.cls == LineBreakClass.ns ||
        current.cls == LineBreakClass.inClass ||
        previous.cls == LineBreakClass.bb ||
        previous.cls == LineBreakClass.gl ||
        (current.cls == LineBreakClass.gl &&
            previous.cls != LineBreakClass.sp) ||
        (previous.cls == LineBreakClass.al &&
            (current.cls == LineBreakClass.al ||
                current.cls == LineBreakClass.hl)) ||
        (previous.cls == LineBreakClass.hl &&
            (current.cls == LineBreakClass.al ||
                current.cls == LineBreakClass.hl)) ||
        (previous.cls == LineBreakClass.nu &&
            (current.cls == LineBreakClass.al ||
                current.cls == LineBreakClass.hl)) ||
        ((previous.cls == LineBreakClass.al ||
                previous.cls == LineBreakClass.hl) &&
            current.cls == LineBreakClass.nu) ||
        ((previous.cls == LineBreakClass.pr ||
                previous.cls == LineBreakClass.po) &&
            (current.cls == LineBreakClass.al ||
                current.cls == LineBreakClass.hl)) ||
        ((previous.cls == LineBreakClass.al ||
                previous.cls == LineBreakClass.hl) &&
            (current.cls == LineBreakClass.pr ||
                current.cls == LineBreakClass.po)) ||
        (previous.cls == LineBreakClass.qu &&
            current.cls != LineBreakClass.sp) ||
        (current.cls == LineBreakClass.qu &&
            previous.cls != LineBreakClass.sp) ||
        (previous.cls == LineBreakClass.ri &&
            current.cls == LineBreakClass.ri &&
            i.isOdd) ||
        (previous.cls == LineBreakClass.isClass &&
            current.cls == LineBreakClass.nu) ||
        (previous.cls == LineBreakClass.hy &&
            current.cls == LineBreakClass.nu)) {
      continue;
    }
    if (previous.cls == LineBreakClass.sp ||
        previous.cls == LineBreakClass.zw ||
        previous.cls == LineBreakClass.hy ||
        (cjBreakable && current.cls == LineBreakClass.qu)) {
      result.add(LineBreakPoint(current.offset, false));
    }
  }
  return result;
}

LineBreakClass _resolve(LineBreakClass cls, bool cjBreakable) => switch (cls) {
      LineBreakClass.ai ||
      LineBreakClass.sg ||
      LineBreakClass.xx =>
        LineBreakClass.al,
      LineBreakClass.cj => cjBreakable ? LineBreakClass.id : LineBreakClass.ns,
      _ => cls,
    };
