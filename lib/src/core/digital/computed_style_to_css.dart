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

String computedStyleToInlineStyle(ComputedStyle style) {
  final initial = initialComputedStyle;
  final output = <String>[];
  void add(String property, String value) => output.add('$property: $value');
  if (style.writingMode != initial.writingMode)
    add('writing-mode', style.writingMode.value);
  if (style.direction != initial.direction)
    add('direction', style.direction.value);
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
  if (style.textAlign != initial.textAlign)
    add('text-align', style.textAlign.value);
  if (style.whiteSpace != initial.whiteSpace)
    add('white-space', style.whiteSpace.value);
  if (style.textTransform != initial.textTransform)
    add('text-transform', style.textTransform.value);
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
  return output.join('; ');
}
