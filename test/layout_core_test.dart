import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mat2d.dart';
import 'package:taleweaver/src/core/layout/text_tokenize.dart';
import 'package:taleweaver/src/core/layout/text_transform.dart';
import 'package:taleweaver/src/core/styles/length.dart';
import 'package:taleweaver/src/core/styles/style.dart';

void main() {
  test('tokenize preserves offsets for normal and pre whitespace modes', () {
    expect(tokenize('  hello  ', WhiteSpace.normal),
        [' ', ' ', 'hello', ' ', ' ']);
    expect(tokenize('a\nb', WhiteSpace.pre), ['a', lineBreak, 'b']);
    expect(tokenize(' a', WhiteSpace.breakSpaces), [' ', 'a']);
  });

  test('text transforms return display text and source code-unit lengths', () {
    expect(transformRun('hello world', TextTransform.uppercase).display,
        'HELLO WORLD');
    final capitalized = transformRun('hello world', TextTransform.capitalize);
    expect(capitalized.display, 'Hello World');
    expect(capitalized.sourceDisplayLengths, List.filled(11, 1));
  });

  test('Mat2D composes and inverts affine transformations', () {
    final matrix = compose(translate(10, 20), rotate(math.pi / 2));
    final point = applyMatrix(matrix, 1, 0);
    expect(point.x, closeTo(10, 1e-10));
    expect(point.y, closeTo(21, 1e-10));
    final restored = applyMatrix(invert(matrix)!, point.x, point.y);
    expect(restored.x, closeTo(1, 1e-10));
    expect(restored.y, closeTo(0, 1e-10));
    expect(resolveLength(const Length.percent(50), 200), 100);
  });
}
