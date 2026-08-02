import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/uax14/break_opportunities.dart';
import 'package:taleweaver/src/core/layout/uax14/line_break_class.dart';

void main() {
  test('line break classes cover mandatory, whitespace and CJK basics', () {
    expect(lineBreakClass(0x0a), LineBreakClass.lf);
    expect(lineBreakClass(0x20), LineBreakClass.sp);
    expect(lineBreakClass(0x4e00), LineBreakClass.id);
  });

  test('line break opportunities use UTF-16 offsets and mandatory markers', () {
    final points = lineBreakOpportunities('a b\nc');
    expect(points.map((point) => [point.index, point.mandatory]), [
      [2, false],
      [4, true],
    ]);
  });
}
