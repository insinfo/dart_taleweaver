library;

import '../styles/computed_style.dart';
import 'mock_shaper.dart';
import 'text_shaper.dart';

abstract interface class TextMeasurer {
  double measureWidth(String text, ComputedStyle style);
  double measureHeight(ComputedStyle style);
}

TextMeasurer adaptShaperToMeasurer(TextShaper shaper) =>
    _ShaperMeasurer(shaper);

class _ShaperMeasurer implements TextMeasurer {
  final TextShaper shaper;
  _ShaperMeasurer(this.shaper);
  @override
  double measureWidth(String text, ComputedStyle style) =>
      shaper.shape(text, style, style.direction).unbreakableRunInlineSize;
  @override
  double measureHeight(ComputedStyle style) {
    final metrics = shaper.measureFontMetrics(style);
    return metrics.ascent + metrics.descent + metrics.lineGap;
  }
}

TextMeasurer createMockMeasurer(double charWidth, double lineHeight) =>
    adaptShaperToMeasurer(createMockShaper(charWidth, lineHeight));
