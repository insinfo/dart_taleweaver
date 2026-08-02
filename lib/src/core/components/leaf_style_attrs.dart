/// Helpers for reading block-level style overrides from leaf attrs.
///
/// Port of `components/leaf-style-attrs.ts`.
library;

import '../cascade/builtin_attrs.dart';
import '../styles/style.dart';
import '../styles/tab_stops.dart';
import '../styles/writing_mode.dart';

bool isWritingMode(dynamic value) {
  return value == 'horizontal-tb' ||
      value == 'vertical-rl' ||
      value == 'vertical-lr';
}

WritingMode? writingModeFromAttrs(dynamic value) {
  if (isWritingMode(value)) {
    if (value == 'horizontal-tb') return WritingMode.horizontalTb;
    if (value == 'vertical-rl') return WritingMode.verticalRl;
    if (value == 'vertical-lr') return WritingMode.verticalLr;
  }
  return null;
}

String? langFromAttrs(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

TextAlign? textAlignFromAttrs(dynamic value) {
  if (isTextAlign(value)) {
    if (value == 'start') return TextAlign.start;
    if (value == 'end') return TextAlign.end;
    if (value == 'center') return TextAlign.center;
    if (value == 'justify') return TextAlign.justify;
  }
  return null;
}

double? lineHeightFromAttrs(dynamic value) {
  if (value is num && value > 0) return value.toDouble();
  return null;
}

double? marginInlineStartFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value > 0) return value.toDouble();
  return null;
}

double? marginBlockStartFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  return null;
}

double? marginBlockEndFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  return null;
}

List<TabStop>? tabStopsFromAttrs(dynamic value) {
  final stops = normalizeTabStops(value);
  return stops;
}

Float? imageWrapFloat(dynamic wrap, Direction direction) {
  if (wrap == 'left') {
    return direction == Direction.rtl ? Float.inlineEnd : Float.inlineStart;
  }
  if (wrap == 'right') {
    return direction == Direction.rtl ? Float.inlineStart : Float.inlineEnd;
  }
  return null;
}
