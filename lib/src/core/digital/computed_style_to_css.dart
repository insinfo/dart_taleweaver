library;

import '../styles/computed_style.dart';
import '../styles/length.dart';
import '../styles/property_meta.dart';

String _length(dynamic value) {
  if (value is num) return '${value}px';
  return switch (value) {
    PxLength(:final value) => '${value}px',
    PercentLength(:final value) => '${value}%',
    ComputedPxLength(:final value) => '${value}px',
    ComputedPercentLength(:final value) => '${value}%',
    _ => 'auto',
  };
}

String _lengthOrAuto(dynamic value) {
  if (value is AutoLength || value is ComputedAutoLength || value == 'auto')
    return 'auto';
  if (value is LengthValue) return _length(value.value);
  if (value is ComputedLengthValue) return _length(value.value);
  return _length(value);
}

/// Keeps style-model keywords intact while serializing computed lengths to
/// browser CSS. The model deliberately carries a few dynamic values (`auto`,
/// `none`, `normal`, intrinsic sizing keywords) for parity with the source.
String _cssValue(dynamic value) {
  if (value is String) return value;
  if (value is num) return '$value';
  if (value is LengthOrAuto || value is ComputedLengthOrAuto) {
    return _lengthOrAuto(value);
  }
  return _length(value);
}

String _border(double width, dynamic style, String color) =>
    '${width}px ${style.value} $color';

String computedStyleToInlineStyle(ComputedStyle style) {
  final initial = initialComputedStyle;
  final output = <String>[];
  void add(String property, String value) => output.add('$property: $value');
  if (style.display != initial.display) add('display', style.display.value);
  if (style.writingMode != initial.writingMode)
    add('writing-mode', style.writingMode.value);
  if (style.direction != initial.direction)
    add('direction', style.direction.value);
  if (style.inlineSize != initial.inlineSize)
    add('inline-size', _cssValue(style.inlineSize));
  if (style.blockSize != initial.blockSize)
    add('block-size', _cssValue(style.blockSize));
  if (style.minInlineSize != initial.minInlineSize)
    add('min-inline-size', _cssValue(style.minInlineSize));
  if (style.minBlockSize != initial.minBlockSize)
    add('min-block-size', _cssValue(style.minBlockSize));
  if (style.maxInlineSize != initial.maxInlineSize)
    add('max-inline-size', _cssValue(style.maxInlineSize));
  if (style.maxBlockSize != initial.maxBlockSize)
    add('max-block-size', _cssValue(style.maxBlockSize));
  if (style.boxSizing != initial.boxSizing)
    add('box-sizing', style.boxSizing.value);
  if (style.color != initial.color) add('color', style.color);
  if (style.backgroundColor != initial.backgroundColor)
    add('background-color', style.backgroundColor);
  if (style.fontFamily != initial.fontFamily)
    add('font-family', style.fontFamily);
  if (style.fontSize != initial.fontSize)
    add('font-size', _length(style.fontSize));
  if (style.fontWeight != initial.fontWeight)
    add('font-weight', '${style.fontWeight.value}');
  if (style.fontStyle != initial.fontStyle)
    add('font-style', style.fontStyle.value);
  if (style.lineHeight != initial.lineHeight)
    add('line-height', _cssValue(style.lineHeight));
  if (style.textAlign != initial.textAlign)
    add('text-align', style.textAlign.value);
  if (style.whiteSpace != initial.whiteSpace)
    add('white-space', style.whiteSpace.value);
  if (style.verticalAlign != initial.verticalAlign)
    add('vertical-align', style.verticalAlign.value);
  if (style.textIndent != initial.textIndent)
    add('text-indent', _length(style.textIndent));
  if (style.textWrap != initial.textWrap)
    add('text-wrap', style.textWrap.value);
  if (style.hyphens != initial.hyphens) add('hyphens', style.hyphens.value);
  if (style.overflowWrap != initial.overflowWrap)
    add('overflow-wrap', style.overflowWrap.value);
  if (style.letterSpacing != initial.letterSpacing)
    add('letter-spacing', _cssValue(style.letterSpacing));
  if (style.wordSpacing != initial.wordSpacing)
    add('word-spacing', _cssValue(style.wordSpacing));
  if (style.textTransform != initial.textTransform)
    add('text-transform', style.textTransform.value);
  if (style.fontFeatureSettings.isNotEmpty &&
      style.fontFeatureSettings != initial.fontFeatureSettings) {
    add('font-feature-settings',
        style.fontFeatureSettings.map((feature) => '"$feature"').join(', '));
  }
  if (style.underline != initial.underline ||
      style.lineThrough != initial.lineThrough) {
    final decorations = <String>[];
    if (style.underline) decorations.add('underline');
    if (style.lineThrough) decorations.add('line-through');
    add('text-decoration-line',
        decorations.isEmpty ? 'none' : decorations.join(' '));
  }
  if (style.marginBlockStart != initial.marginBlockStart)
    add('margin-block-start', _lengthOrAuto(style.marginBlockStart));
  if (style.marginBlockEnd != initial.marginBlockEnd)
    add('margin-block-end', _lengthOrAuto(style.marginBlockEnd));
  if (style.marginInlineStart != initial.marginInlineStart)
    add('margin-inline-start', _lengthOrAuto(style.marginInlineStart));
  if (style.marginInlineEnd != initial.marginInlineEnd)
    add('margin-inline-end', _lengthOrAuto(style.marginInlineEnd));
  if (style.paddingBlockStart != initial.paddingBlockStart)
    add('padding-block-start', _length(style.paddingBlockStart));
  if (style.paddingBlockEnd != initial.paddingBlockEnd)
    add('padding-block-end', _length(style.paddingBlockEnd));
  if (style.paddingInlineStart != initial.paddingInlineStart)
    add('padding-inline-start', _length(style.paddingInlineStart));
  if (style.paddingInlineEnd != initial.paddingInlineEnd)
    add('padding-inline-end', _length(style.paddingInlineEnd));
  if (style.borderBlockStartWidth != initial.borderBlockStartWidth ||
      style.borderBlockStartStyle != initial.borderBlockStartStyle ||
      style.borderBlockStartColor != initial.borderBlockStartColor) {
    add(
        'border-block-start',
        _border(style.borderBlockStartWidth, style.borderBlockStartStyle,
            style.borderBlockStartColor));
  }
  if (style.borderBlockEndWidth != initial.borderBlockEndWidth ||
      style.borderBlockEndStyle != initial.borderBlockEndStyle ||
      style.borderBlockEndColor != initial.borderBlockEndColor) {
    add(
        'border-block-end',
        _border(style.borderBlockEndWidth, style.borderBlockEndStyle,
            style.borderBlockEndColor));
  }
  if (style.borderInlineStartWidth != initial.borderInlineStartWidth ||
      style.borderInlineStartStyle != initial.borderInlineStartStyle ||
      style.borderInlineStartColor != initial.borderInlineStartColor) {
    add(
        'border-inline-start',
        _border(style.borderInlineStartWidth, style.borderInlineStartStyle,
            style.borderInlineStartColor));
  }
  if (style.borderInlineEndWidth != initial.borderInlineEndWidth ||
      style.borderInlineEndStyle != initial.borderInlineEndStyle ||
      style.borderInlineEndColor != initial.borderInlineEndColor) {
    add(
        'border-inline-end',
        _border(style.borderInlineEndWidth, style.borderInlineEndStyle,
            style.borderInlineEndColor));
  }
  if (style.float != initial.float) add('float', style.float.value);
  if (style.clear != initial.clear) add('clear', style.clear.value);
  if (style.breakBefore != initial.breakBefore) {
    add('break-before', style.breakBefore.value);
    // Keep paged printing compatible with engines that still consume the
    // legacy property. Screen/continuous flow is unaffected by either
    // declaration until it is fragmented by a print or page context.
    if (style.breakBefore.value == 'page') {
      add('page-break-before', 'always');
    }
  }
  if (style.breakAfter != initial.breakAfter)
    add('break-after', style.breakAfter.value);
  if (style.breakInside != initial.breakInside)
    add('break-inside', style.breakInside.value);
  if (style.widows != initial.widows) add('widows', '${style.widows}');
  if (style.orphans != initial.orphans) add('orphans', '${style.orphans}');
  if (style.position != initial.position) add('position', style.position.value);
  if (style.insetBlockStart != initial.insetBlockStart)
    add('inset-block-start', _cssValue(style.insetBlockStart));
  if (style.insetBlockEnd != initial.insetBlockEnd)
    add('inset-block-end', _cssValue(style.insetBlockEnd));
  if (style.insetInlineStart != initial.insetInlineStart)
    add('inset-inline-start', _cssValue(style.insetInlineStart));
  if (style.insetInlineEnd != initial.insetInlineEnd)
    add('inset-inline-end', _cssValue(style.insetInlineEnd));
  if (style.zIndex != initial.zIndex) add('z-index', _cssValue(style.zIndex));
  if (style.opacity != initial.opacity) add('opacity', '${style.opacity}');
  return output.join('; ');
}
