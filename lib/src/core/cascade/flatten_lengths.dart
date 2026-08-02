/// Resolve em-relative lengths to px.
///
/// Port of `cascade/flatten-lengths.ts`.
library;

import '../styles/computed_style.dart';
import '../styles/length.dart';
import '../styles/property_meta.dart';
import 'resolve_length.dart';

ComputedStyle flattenLengths(ComputedStyle cs) {
  final fontSize = _resolveFontSize(cs);

  return ComputedStyle(
    display: cs.display,
    writingMode: cs.writingMode,
    direction: cs.direction,
    inlineSize: _flattenSizingValue(cs.inlineSize, fontSize),
    blockSize: _flattenSizingValue(cs.blockSize, fontSize),
    minInlineSize: _flattenSizingOrIntrinsic(cs.minInlineSize, fontSize),
    minBlockSize: _flattenSizingOrIntrinsic(cs.minBlockSize, fontSize),
    maxInlineSize: _flattenSizingOrNone(cs.maxInlineSize, fontSize),
    maxBlockSize: _flattenSizingOrNone(cs.maxBlockSize, fontSize),
    boxSizing: cs.boxSizing,
    marginBlockStart: _flattenLengthOrAuto(cs.marginBlockStart, fontSize),
    marginBlockEnd: _flattenLengthOrAuto(cs.marginBlockEnd, fontSize),
    marginInlineStart: _flattenLengthOrAuto(cs.marginInlineStart, fontSize),
    marginInlineEnd: _flattenLengthOrAuto(cs.marginInlineEnd, fontSize),
    paddingBlockStart: _flattenLength(cs.paddingBlockStart, fontSize),
    paddingBlockEnd: _flattenLength(cs.paddingBlockEnd, fontSize),
    paddingInlineStart: _flattenLength(cs.paddingInlineStart, fontSize),
    paddingInlineEnd: _flattenLength(cs.paddingInlineEnd, fontSize),
    borderBlockStartWidth: cs.borderBlockStartWidth,
    borderBlockEndWidth: cs.borderBlockEndWidth,
    borderInlineStartWidth: cs.borderInlineStartWidth,
    borderInlineEndWidth: cs.borderInlineEndWidth,
    borderBlockStartStyle: cs.borderBlockStartStyle,
    borderBlockEndStyle: cs.borderBlockEndStyle,
    borderInlineStartStyle: cs.borderInlineStartStyle,
    borderInlineEndStyle: cs.borderInlineEndStyle,
    borderBlockStartColor: cs.borderBlockStartColor,
    borderBlockEndColor: cs.borderBlockEndColor,
    borderInlineStartColor: cs.borderInlineStartColor,
    borderInlineEndColor: cs.borderInlineEndColor,
    backgroundColor: cs.backgroundColor,
    fontFamily: cs.fontFamily,
    fontSize: fontSize,
    fontWeight: cs.fontWeight,
    fontStyle: cs.fontStyle,
    underline: cs.underline,
    lineThrough: cs.lineThrough,
    lineHeight: _flattenLineHeight(cs.lineHeight, fontSize),
    color: cs.color,
    whiteSpace: cs.whiteSpace,
    verticalAlign: cs.verticalAlign,
    textAlign: cs.textAlign,
    textIndent: _flattenLength(cs.textIndent, fontSize),
    textWrap: cs.textWrap,
    hyphens: cs.hyphens,
    language: cs.language,
    hyphenateLimitChars: cs.hyphenateLimitChars,
    overflowWrap: cs.overflowWrap,
    letterSpacing: _flattenLengthOrNormal(cs.letterSpacing, fontSize),
    wordSpacing: _flattenLengthOrNormal(cs.wordSpacing, fontSize),
    textTransform: cs.textTransform,
    fontFeatureSettings: cs.fontFeatureSettings,
    tabStops: cs.tabStops,
    defaultTabStop: cs.defaultTabStop,
    float: cs.float,
    clear: cs.clear,
    breakBefore: cs.breakBefore,
    breakAfter: cs.breakAfter,
    breakInside: cs.breakInside,
    widows: cs.widows,
    orphans: cs.orphans,
    listStyleType: cs.listStyleType,
    listStylePosition: cs.listStylePosition,
    markerText: cs.markerText,
    position: cs.position,
    insetBlockStart: _flattenLengthOrAuto(cs.insetBlockStart, fontSize),
    insetBlockEnd: _flattenLengthOrAuto(cs.insetBlockEnd, fontSize),
    insetInlineStart: _flattenLengthOrAuto(cs.insetInlineStart, fontSize),
    insetInlineEnd: _flattenLengthOrAuto(cs.insetInlineEnd, fontSize),
    zIndex: cs.zIndex,
    transform: cs.transform,
    transformOrigin: cs.transformOrigin,
    opacity: cs.opacity,
  );
}

bool _isIntrinsicKeyword(dynamic v) {
  return v == 'min-content' || v == 'max-content' || v == 'fit-content';
}

ComputedLength _flattenLength(dynamic v, double fontSize) {
  if (v is ComputedLength) return v; // already computed
  if (v is Length) return resolveLength(v, fontSize);
  return const ComputedLength.px(0); // fallback
}

dynamic _flattenLengthOrAuto(dynamic v, double fontSize) {
  if (v == 'auto' || v is AutoLength || v is ComputedAutoLength)
    return const ComputedLengthOrAuto.auto();
  if (v is ComputedLengthOrAuto) {
    if (v is ComputedLengthValue) return v;
    return const ComputedLengthOrAuto.auto();
  }
  if (v is LengthOrAuto) {
    if (v is LengthValue) {
      return ComputedLengthValue(_flattenLength(v.value, fontSize));
    }
    return const ComputedLengthOrAuto.auto();
  }
  return ComputedLengthValue(_flattenLength(v, fontSize));
}

dynamic _flattenLengthOrNormal(dynamic v, double fontSize) {
  if (v == 'normal') return 'normal';
  return _flattenLength(v, fontSize);
}

dynamic _flattenSizingValue(dynamic v, double fontSize) {
  if (_isIntrinsicKeyword(v)) return v;
  return _flattenLengthOrAuto(v, fontSize);
}

dynamic _flattenSizingOrIntrinsic(dynamic v, double fontSize) {
  if (_isIntrinsicKeyword(v)) return v;
  return _flattenLength(v, fontSize);
}

dynamic _flattenSizingOrNone(dynamic v, double fontSize) {
  if (v == 'none') return 'none';
  if (_isIntrinsicKeyword(v)) return v;
  return _flattenLength(v, fontSize);
}

dynamic _flattenLineHeight(dynamic v, double fontSize) {
  if (v is num) return v.toDouble();
  if (v is EmLength) return v.value;
  if (v is ComputedPercentLength) return v;
  if (v is PercentLength) return ComputedLength.percent(v.value);
  return initialComputedStyle.lineHeight;
}

double _resolveFontSize(ComputedStyle cs) {
  final v = cs.fontSize;
  // in Dart we kept cs.fontSize as double.
  // if for some reason it comes as a Length (e.g. before flattening, it might be dynamic in a loose type), we handle it.
  // Actually, ComputedStyle's fontSize is strongly typed to double.
  // So it's already resolved! Oh wait, in TS ComputedStyle.fontSize is a number, but BEFORE flattenLengths, it might be a Length from `composeComputed`!
  // In our dart composeComputed, we kept it dynamic. Wait, `ComputedStyle.fontSize` is typed as `double`. So if `composeComputed` assigned a Length to `ComputedStyle`, it would throw at runtime!
  // Let me check my `ComputedStyle` class!
  if (v is num) return v.toDouble();
  if (v is PxLength) return v.value;
  if (v is EmLength) return v.value;
  return initialComputedStyle.fontSize is num
      ? (initialComputedStyle.fontSize as num).toDouble()
      : 16;
}
