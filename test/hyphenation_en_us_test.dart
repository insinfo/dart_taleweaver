import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/hyphenation_en_us.dart';

void main() {
  test('ships the reference en-US PatternSet and canonical exceptions', () {
    expect(enUsPatternSet.patterns, contains('hy3ph'));
    expect(enUsPatternSet.exceptions['associate'], 'as-so-ciate');
    expect(enUsPatternSet.exceptions['declination'], 'dec-li-na-tion');
  });

  test('default Liang hyphenator resolves en-US and en aliases', () {
    final hyphenator = createDefaultLiangHyphenator();
    expect(hyphenator.hyphenate('associate', 'en-us'), [2, 4]);
    expect(hyphenator.hyphenate('hyphenation', 'en'), [2, 6]);
    expect(hyphenator.hyphenate('associate', 'en-US'), [2, 4]);
  });
}
