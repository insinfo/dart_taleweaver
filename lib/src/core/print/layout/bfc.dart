library;

import '../../styles/computed_style.dart';
import '../../layout/text_shaper.dart';
import '../../layout/hyphenator.dart';
import 'ifc.dart';
import 'layout_box.dart';

BlockBox layoutBlockText(
    {required String key,
    required String text,
    required ownerBlockId,
    required TextShaper shaper,
    required ComputedStyle style,
    required double inlineSize,
    double blockOffset = 0,
    Hyphenator? hyphenator}) {
  final lines = layoutInlineText(
      text: text,
      ownerBlockId: ownerBlockId,
      shaper: shaper,
      style: style,
      maxInlineSize: inlineSize,
      blockOffset: 0,
      hyphenator: hyphenator);
  final blockSize = lines.fold<double>(0, (sum, line) => sum + line.blockSize);
  return BlockBox(
      key: key,
      inlineOffset: 0,
      blockOffset: blockOffset,
      inlineSize: inlineSize,
      blockSize: blockSize,
      x: 0,
      y: blockOffset,
      width: inlineSize,
      height: blockSize,
      writingMode: style.writingMode,
      direction: style.direction,
      computedStyle: style,
      children: lines,
      ownerBlockId: ownerBlockId);
}
