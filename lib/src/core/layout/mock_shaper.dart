library;

import '../styles/computed_style.dart';
import '../styles/writing_mode.dart';
import 'graphemes.dart';
import 'text_shaper.dart';
import 'text_spacing.dart';

TextShaper createMockShaper(double charWidth, double lineHeight) =>
    _MockShaper(charWidth, lineHeight);

class _MockShaper implements TextShaper {
  final double charWidth;
  final double lineHeight;
  _MockShaper(this.charWidth, this.lineHeight);

  @override
  FontMetrics measureFontMetrics(ComputedStyle style) => FontMetrics(
        ascent: lineHeight * .8,
        descent: lineHeight * .2,
        lineGap: 0,
        capHeight: lineHeight * .7,
        xHeight: lineHeight * .5,
      );

  @override
  ShapedRun shape(String text, ComputedStyle style, Direction baseDirection) {
    final letter = resolveSpacingPx(style.letterSpacing);
    final word = resolveSpacingPx(style.wordSpacing);
    final clusters = <Cluster>[];
    var offset = 0;
    var total = 0.0;
    var widest = 0.0;
    for (final grapheme in graphemeClusters(text)) {
      final double advance = grapheme == '\u00ad'
          ? 0.0
          : charWidth + clusterSpacing(grapheme, letter, word);
      clusters.add(Cluster(
          start: offset,
          end: offset + grapheme.length,
          inlineAdvance: advance,
          isLigature: false,
          glyphs: [grapheme.codeUnitAt(0)]));
      offset += grapheme.length;
      total += advance;
      if (advance > widest) widest = advance;
    }
    final metrics = measureFontMetrics(style);
    return ShapedRun(
        text: text,
        computedStyle: style,
        clusters: clusters,
        ascent: metrics.ascent,
        descent: metrics.descent,
        lineGap: metrics.lineGap,
        minClusterInlineSize: widest,
        unbreakableRunInlineSize: total,
        breakOpportunities: toBreakOpportunities(text),
        bidiLevel: baseDirection == Direction.rtl ? 1 : 0);
  }
}
