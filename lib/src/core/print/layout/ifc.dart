library;

import '../../layout/text_shaper.dart';
import '../../state/block_id.dart';
import '../../styles/computed_style.dart';
import 'layout_box.dart';

List<LineBox> layoutInlineText(
    {required String text,
    required BlockId ownerBlockId,
    required TextShaper shaper,
    required ComputedStyle style,
    required double maxInlineSize,
    double blockOffset = 0}) {
  final shaped = shaper.shape(text, style, style.direction);
  final metrics = shaper.measureFontMetrics(style);
  final lines = <LineBox>[];
  var lineStart = 0;
  var lineWidth = 0.0;
  var lineIndex = 0;
  for (var index = 0; index < shaped.clusters.length; index++) {
    final cluster = shaped.clusters[index];
    if (lineWidth > 0 && lineWidth + cluster.inlineAdvance > maxInlineSize) {
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
      lineWidth = 0;
      lineIndex++;
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

LineBox _line(
    String text,
    BlockId owner,
    int start,
    int end,
    double width,
    double blockOffset,
    ComputedStyle style,
    FontMetrics metrics,
    int lineIndex) {
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
      ownerBlockId: owner);
}
