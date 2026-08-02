import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/hyphenator.dart';
import 'package:taleweaver/src/core/layout/liang_hyphenator.dart';

void main() {
  test('mock hyphenator returns sorted interior code-unit points', () {
    const hyphenator = MockHyphenator(every: 3, floor: 4);
    expect(hyphenator.hyphenate('abcdefgh', 'en'), [3, 6]);
    expect(hyphenator.hyphenate('abc', 'en'), isEmpty);
  });

  test('mock hyphenator can restrict language', () {
    const hyphenator = MockHyphenator(language: 'pt');
    expect(hyphenator.hyphenate('palavra', 'en'), isEmpty);
    expect(hyphenator.hyphenate('palavra', 'pt'), isNotEmpty);
  });

  test('Liang hyphenator applies patterns, exceptions and language fallback',
      () {
    const set = PatternSet(
      patterns: 'a1bc ab1 c1d',
      exceptions: {'associate': 'as-so-ciate'},
    );
    final h = LiangHyphenator({'en': set});
    expect(h.hyphenate('associate', 'en-US'), [2, 4]);
    expect(h.hyphenate('abcd', 'en'), isNotEmpty);
    expect(h.hyphenate('associate', 'de'), isEmpty);
  });

  test('Liang hyphenator maps soft-hyphen indices back to original UTF-16', () {
    const set = PatternSet(patterns: 'hy3ph');
    final h = LiangHyphenator({'en': set});
    expect(h.hyphenate('hy\u00adphen', 'en'), [3]);
  });
}
