library;

import '../styles/computed_style.dart';
import '../styles/writing_mode.dart';
import 'uax14/break_opportunities.dart';

typedef GlyphId = int;

class Cluster {
  final int start;
  final int end;
  final double inlineAdvance;
  final bool isLigature;
  final List<GlyphId> glyphs;
  const Cluster(
      {required this.start,
      required this.end,
      required this.inlineAdvance,
      required this.isLigature,
      required this.glyphs});
}

class BreakOpportunity {
  final int clusterIndex;
  final String kind;
  const BreakOpportunity(this.clusterIndex, this.kind);
}

class FontMetrics {
  final double ascent;
  final double descent;
  final double lineGap;
  final double capHeight;
  final double xHeight;
  const FontMetrics(
      {required this.ascent,
      required this.descent,
      required this.lineGap,
      required this.capHeight,
      required this.xHeight});
}

class ShapedRun {
  final String text;
  final ComputedStyle computedStyle;
  final List<Cluster> clusters;
  final double ascent;
  final double descent;
  final double lineGap;
  final double minClusterInlineSize;
  final double unbreakableRunInlineSize;
  final List<BreakOpportunity> breakOpportunities;
  final int bidiLevel;
  const ShapedRun(
      {required this.text,
      required this.computedStyle,
      required this.clusters,
      required this.ascent,
      required this.descent,
      required this.lineGap,
      required this.minClusterInlineSize,
      required this.unbreakableRunInlineSize,
      required this.breakOpportunities,
      required this.bidiLevel});
}

abstract interface class TextShaper {
  ShapedRun shape(String text, ComputedStyle style, Direction baseDirection);
  FontMetrics measureFontMetrics(ComputedStyle style);
}

List<BreakOpportunity> toBreakOpportunities(String text) {
  return lineBreakOpportunities(text, cjBreakable: true)
      .map((point) =>
          BreakOpportunity(point.index, point.mandatory ? 'hard' : 'soft'))
      .toList(growable: false);
}
