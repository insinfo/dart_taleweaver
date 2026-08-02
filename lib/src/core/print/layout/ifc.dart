library;

import '../../layout/text_shaper.dart';
import '../../layout/hyphenator.dart';
import '../../state/block_id.dart';
import '../../styles/computed_style.dart';
import '../../styles/style.dart';
import 'layout_box.dart';

List<LineBox> layoutInlineText(
    {required String text,
    required BlockId ownerBlockId,
    required TextShaper shaper,
    required ComputedStyle style,
    required double maxInlineSize,
    double blockOffset = 0,
    Hyphenator? hyphenator}) {
  final shaped = shaper.shape(text, style, style.direction);
  final metrics = shaper.measureFontMetrics(style);
  final hyphenAdvance = style.hyphens == Hyphens.auto
      ? shaper.shape('-', style, style.direction).unbreakableRunInlineSize
      : 0.0;
  final lines = <LineBox>[];
  var lineStart = 0;
  var lineStartCluster = 0;
  var lineWidth = 0.0;
  var lineIndex = 0;
  var lastSoftBreakCluster = -1;
  var lastBreakKind = 'soft';
  final breakKinds = <int, String>{
    for (final point in shaped.breakOpportunities)
      point.clusterIndex: point.kind,
  };
  if (hyphenator != null &&
      style.hyphens == Hyphens.auto &&
      style.language.isNotEmpty) {
    for (final match in RegExp(r'[A-Za-z]+').allMatches(text)) {
      final word = match.group(0)!;
      for (final point in hyphenator.hyphenate(word, style.language)) {
        final offset = match.start + point;
        if (offset > match.start && offset < match.end) {
          breakKinds[offset] = 'hyphen';
        }
      }
    }
  }
  for (var index = 0; index < shaped.clusters.length; index++) {
    final cluster = shaped.clusters[index];
    final breakKind = breakKinds[cluster.start];
    if (breakKind == 'soft' || breakKind == 'hyphen') {
      lastSoftBreakCluster = index;
      lastBreakKind = breakKind!;
    }
    if (breakKind == 'hard') {
      var hardOffset = cluster.start;
      var hardCluster = index;
      final newline = text.lastIndexOf('\n', cluster.start - 1);
      if (newline >= lineStart) {
        hardOffset = newline;
        for (var candidate = lineStartCluster; candidate < index; candidate++) {
          if (shaped.clusters[candidate].start == newline) {
            hardCluster = candidate;
            break;
          }
        }
      }
      lines.add(_line(
          text.substring(lineStart, hardOffset),
          ownerBlockId,
          lineStart,
          hardOffset,
          _widthForRange(shaped.clusters, lineStartCluster, hardCluster),
          blockOffset +
              lineIndex * (metrics.ascent + metrics.descent + metrics.lineGap),
          style,
          metrics,
          lineIndex));
      lineStart = cluster.start;
      lineStartCluster = index;
      lineWidth = 0;
      lineIndex++;
      lastSoftBreakCluster = -1;
      lastBreakKind = 'soft';
    }
    if (lineWidth > 0 && lineWidth + cluster.inlineAdvance > maxInlineSize) {
      if (lastSoftBreakCluster >= lineStartCluster) {
        final breakCluster = lastSoftBreakCluster;
        final breakOffset = shaped.clusters[breakCluster].start;
        // The normal path below recomputes the width from measured clusters;
        // only the source boundary is needed here because lineWidth already
        // contains the pre-break advances.
        final measuredWidth =
            _widthForRange(shaped.clusters, lineStart, breakCluster);
        final endsWithHyphen = lastBreakKind == 'hyphen';
        lines.add(_line(
            text.substring(lineStart, breakOffset),
            ownerBlockId,
            lineStart,
            breakOffset,
            measuredWidth + (endsWithHyphen ? hyphenAdvance : 0),
            blockOffset +
                lineIndex *
                    (metrics.ascent + metrics.descent + metrics.lineGap),
            style,
            metrics,
            lineIndex,
            endsWithHyphen: endsWithHyphen));
        lineStart = breakOffset;
        lineStartCluster = breakCluster;
        lineWidth = _widthForRange(shaped.clusters, breakCluster, index);
        lineIndex++;
        lastSoftBreakCluster = -1;
        lastBreakKind = 'soft';
        continue;
      }
      lines.add(_line(
          text.substring(lineStart, cluster.start),
          ownerBlockId,
          lineStart,
          cluster.start,
          lineWidth,
          blockOffset +
              lineIndex * (metrics.ascent + metrics.descent + metrics.lineGap),
          style,
          metrics,
          lineIndex));
      lineStart = cluster.start;
      lineStartCluster = index;
      lineWidth = 0;
      lineIndex++;
      lastSoftBreakCluster = -1;
      lastBreakKind = 'soft';
    }
    lineWidth += cluster.inlineAdvance;
  }
  lines.add(_line(
      text.substring(lineStart),
      ownerBlockId,
      lineStart,
      text.length,
      lineWidth,
      blockOffset +
          lineIndex * (metrics.ascent + metrics.descent + metrics.lineGap),
      style,
      metrics,
      lineIndex));
  return lines;
}

double _widthForRange(List<Cluster> clusters, int start, int end) {
  var width = 0.0;
  for (var i = start; i < end; i++) width += clusters[i].inlineAdvance;
  return width;
}

LineBox _line(String text, BlockId owner, int start, int end, double width,
    double blockOffset, ComputedStyle style, FontMetrics metrics, int lineIndex,
    {bool endsWithHyphen = false}) {
  final run = TextRunBox(
      key: '$owner-line-$lineIndex-text',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: width,
      blockSize: metrics.ascent + metrics.descent + metrics.lineGap,
      x: 0,
      y: 0,
      width: width,
      height: metrics.ascent + metrics.descent + metrics.lineGap,
      writingMode: style.writingMode,
      direction: style.direction,
      computedStyle: style,
      text: text,
      offsetLength: end - start);
  return LineBox(
      key: '$owner-line-$lineIndex',
      inlineOffset: 0,
      blockOffset: blockOffset,
      inlineSize: width,
      blockSize: run.height,
      x: 0,
      y: blockOffset,
      width: width,
      height: run.height,
      writingMode: style.writingMode,
      direction: style.direction,
      computedStyle: style,
      children: [run],
      baseline: metrics.ascent,
      ownerBlockId: owner,
      offsetStart: start,
      endsWithHyphen: endsWithHyphen);
}
