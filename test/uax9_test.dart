import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/uax9/bidi.dart';
import 'package:taleweaver/src/core/layout/uax9/bidi_class.dart';
import 'package:taleweaver/src/core/layout/uax9/mirror.dart';
import 'package:taleweaver/src/core/layout/uax9/reorder.dart';

void main() {
  test('bidi classes and paragraph direction detect Hebrew/Arabic', () {
    expect(bidiClass(0x41), BidiClass.l);
    expect(bidiClass(0x05d0), BidiClass.r);
    expect(resolveBidi('abc').paragraphLevel, 0);
    expect(resolveBidi('אב').paragraphLevel, 1);
  });

  test('L2 reorders runs from highest level down to lowest odd level', () {
    expect(reorderRunsByLevel([0, 1, 1, 0]), [0, 2, 1, 3]);
    expect(reorderRunsByLevel([0, 2, 0]), [0, 1, 2]);
  });

  test('mirror and canonical bracket helpers cover basic pairs', () {
    expect(bidiMirror(0x28), 0x29);
    expect(canonicalBracketEquiv(0x2329), 0x3008);
  });

  test('full Unicode mirror and bracket tables cover non-ASCII pairs', () {
    expect(bidiMirror(0x00AB), 0x00BB);
    expect(bidiMirror(0x2264), 0x2265);
    expect(bracketPair(0x3008)?.paired, 0x3009);
    expect(bracketPair(0x3008)?.opening, isTrue);
    expect(bracketPair(0x3009)?.opening, isFalse);
    expect(bracketPair(0x0041), isNull);
  });
}
