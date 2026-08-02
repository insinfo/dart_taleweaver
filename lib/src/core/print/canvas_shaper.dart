/// Browser Canvas-backed text shaping and measurement adapter.
library;

import 'package:web/web.dart' as web;

import '../layout/graphemes.dart';
import '../layout/text_shaper.dart';
import '../layout/text_spacing.dart';
import '../styles/computed_style.dart';
import '../styles/writing_mode.dart';

/// Shapes one UAX #29 grapheme cluster at a time using Canvas2D metrics.
///
/// Canvas does not expose HarfBuzz glyph clusters, so this adapter deliberately
/// keeps the same contract as the TypeScript canvas backend: grapheme clusters
/// are stable, advances are measured independently, and bidi level is uniform
/// for the run. Complex-script shaping can be supplied later by another
/// [TextShaper] implementation without changing IFC consumers.
TextShaper createCanvasShaper(web.HTMLCanvasElement canvas) {
  final raw = canvas.getContext('2d');
  if (raw is! web.CanvasRenderingContext2D) {
    throw StateError('createCanvasShaper: failed to get 2D context');
  }
  return _CanvasShaper(raw);
}

class _CanvasShaper implements TextShaper {
  final web.CanvasRenderingContext2D context;
  _CanvasShaper(this.context);

  void _setFont(ComputedStyle style) {
    final size =
        (style.fontSize is num ? style.fontSize as num : 16).toDouble();
    final weight = style.fontWeight.toString().split('.').last;
    final italic = style.fontStyle.toString().split('.').last == 'italic';
    context.font =
        '${italic ? 'italic ' : ''}$weight ${size}px ${style.fontFamily}';
  }

  @override
  FontMetrics measureFontMetrics(ComputedStyle style) {
    _setFont(style);
    final size =
        (style.fontSize is num ? style.fontSize as num : 16).toDouble();
    final lineHeight = style.lineHeight is num
        ? ((style.lineHeight as num).toDouble() < 4
            ? (style.lineHeight as num).toDouble() * size
            : (style.lineHeight as num).toDouble())
        : size * 1.2;
    // Prefer the browser's actual glyph metrics, with the CSS-compatible
    // heuristic fallback required by older engines that return zero.
    final hg = context.measureText('Hg');
    final ascent = _positiveOr(hg.actualBoundingBoxAscent, size * .8);
    final descent = _positiveOr(hg.actualBoundingBoxDescent, size * .2);
    final cap = context.measureText('H');
    final x = context.measureText('x');
    return FontMetrics(
      ascent: ascent,
      descent: descent,
      lineGap: (lineHeight - ascent - descent).clamp(0, double.infinity),
      capHeight: _positiveOr(cap.actualBoundingBoxAscent, size * .7),
      xHeight: _positiveOr(x.actualBoundingBoxAscent, size * .5),
    );
  }

  double _positiveOr(double value, double fallback) =>
      value.isFinite && value > 0 ? value : fallback;

  @override
  ShapedRun shape(String text, ComputedStyle style, Direction baseDirection) {
    _setFont(style);
    final letter = resolveSpacingPx(style.letterSpacing);
    final word = resolveSpacingPx(style.wordSpacing);
    final clusters = <Cluster>[];
    var offset = 0;
    var total = 0.0;
    var widest = 0.0;
    for (final grapheme in graphemeClusters(text)) {
      final advance = grapheme == '\u00ad'
          ? 0.0
          : context.measureText(grapheme).width +
              clusterSpacing(grapheme, letter, word);
      clusters.add(Cluster(
        start: offset,
        end: offset + grapheme.length,
        inlineAdvance: advance,
        isLigature: false,
        glyphs: [grapheme.codeUnitAt(0)],
      ));
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
      bidiLevel: baseDirection == Direction.rtl ? 1 : 0,
    );
  }
}
