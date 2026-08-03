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
    // The command API uses Word's left/right vocabulary. Map it to logical
    // alignment so right-to-left documents still behave correctly.
    if (value == 'left') return TextAlign.start;
    if (value == 'right') return TextAlign.end;
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

double? marginInlineEndFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value > 0) return value.toDouble();
  return null;
}

/// The first-line indent is a signed delta from the paragraph's inline start.
///
/// A negative value represents a hanging indent. Zero is deliberately
/// normalized to no direct style so it can inherit the initial CSS value.
double? textIndentFromAttrs(dynamic value) {
  if (value is num && value.isFinite && value != 0) return value.toDouble();
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

/// Resolves the block-level manual page-break attribute used by
/// [PageBreakAction].  It lives with the other leaf style readers because
/// block components construct their specified style directly rather than
/// flowing their attrs through the inline-run registry.
BreakBefore? breakBeforeFromAttrs(dynamic value) {
  if (value == 'page') return BreakBefore.page;
  if (value == 'avoid') return BreakBefore.avoid;
  if (value == 'auto') return BreakBefore.auto;
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
