library;

import '../styles/computed_style.dart';
import '../styles/writing_mode.dart';
import 'mock_shaper.dart';
import 'text_shaper.dart';

abstract interface class TextMeasurer {
  double measureWidth(String text, ComputedStyle style);
  double measureHeight(ComputedStyle style);
}

TextMeasurer adaptShaperToMeasurer(TextShaper shaper) =>
    _ShaperMeasurer(shaper);

/// Adapt the legacy width/height interface to the canonical [TextShaper].
///
/// This compatibility path intentionally models one cluster per UTF-16 code
/// unit, matching the TypeScript fallback used when no shaping engine exists.
TextShaper measurerToShaper(TextMeasurer measurer) => _MeasurerShaper(measurer);

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

class _MeasurerShaper implements TextShaper {
  final TextMeasurer measurer;
  _MeasurerShaper(this.measurer);

  @override
  ShapedRun shape(String text, ComputedStyle style, Direction baseDirection) {
    final totalWidth = text.isEmpty ? 0.0 : measurer.measureWidth(text, style);
    final perUnit = text.isEmpty ? 0.0 : totalWidth / text.length;
    final clusters = List<Cluster>.generate(
      text.length,
      (i) => Cluster(
        start: i,
        end: i + 1,
        inlineAdvance: perUnit,
        isLigature: false,
        glyphs: [text.codeUnitAt(i)],
      ),
      growable: false,
    );
    final totalHeight = measurer.measureHeight(style);
    final ascent = totalHeight * 0.8;
    final descent = totalHeight * 0.2;
    return ShapedRun(
      text: text,
      computedStyle: style,
      clusters: clusters,
      ascent: ascent,
      descent: descent,
      lineGap: totalHeight - ascent - descent,
      minClusterInlineSize: perUnit,
      unbreakableRunInlineSize: totalWidth,
      breakOpportunities: toBreakOpportunities(text),
      bidiLevel: 0,
    );
  }

  @override
  FontMetrics measureFontMetrics(ComputedStyle style) {
    final totalHeight = measurer.measureHeight(style);
    final ascent = totalHeight * 0.8;
    final descent = totalHeight * 0.2;
    return FontMetrics(
      ascent: ascent,
      descent: descent,
      lineGap: totalHeight - ascent - descent,
      capHeight: totalHeight * 0.7,
      xHeight: totalHeight * 0.5,
    );
  }
}

TextMeasurer createMockMeasurer(double charWidth, double lineHeight) =>
    adaptShaperToMeasurer(createMockShaper(charWidth, lineHeight));
