library;

import '../styles/computed_style.dart';
import 'graphemes.dart';
import 'text_shaper.dart';

class IntrinsicTextSize {
  final double minContent;
  final double maxContent;
  const IntrinsicTextSize({required this.minContent, required this.maxContent});
}

/// Computes CSS-like min/max content widths from the active shaper. The
/// min-content width is the widest grapheme cluster; max-content is the
/// widest whitespace-delimited unbreakable run.
IntrinsicTextSize measureIntrinsicText(
    String text, TextShaper shaper, ComputedStyle style) {
  if (text.isEmpty)
    return const IntrinsicTextSize(minContent: 0, maxContent: 0);
  var minContent = 0.0;
  for (final cluster in graphemeClusters(text)) {
    final width =
        shaper.shape(cluster, style, style.direction).unbreakableRunInlineSize;
    if (width > minContent) minContent = width;
  }
  var maxContent = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final width =
        shaper.shape(word, style, style.direction).unbreakableRunInlineSize;
    if (width > maxContent) maxContent = width;
  }
  return IntrinsicTextSize(minContent: minContent, maxContent: maxContent);
}
