/// Compose a computed style for one node from its specified style and
/// its parent's computed style.
///
/// Port of `cascade/compose.ts`.
library;

import '../styles/computed_style.dart';
import '../styles/length.dart';
import '../styles/property_meta.dart';
import '../styles/style.dart';

ComputedLength _toComputedLength(dynamic value) {
  if (value is ComputedLength) return value;
  if (value is PxLength) return ComputedPxLength(value.value);
  if (value is PercentLength) return ComputedPercentLength(value.value);
  if (value is EmLength) return ComputedPxLength(value.value);
  return const ComputedPxLength(0);
}

ComputedLengthOrAuto _toComputedLengthOrAuto(dynamic value) {
  if (value is ComputedLengthOrAuto) return value;
  if (value is AutoLength || value == null) return const ComputedAutoLength();
  if (value is LengthValue)
    return ComputedLengthValue(_toComputedLength(value.value));
  return ComputedLengthValue(_toComputedLength(value));
}

ComputedStyle composeComputed(Style specified, ComputedStyle? parent) {
  return ComputedStyle(
    display: specified.display ??
        (propertyMeta['display']!.inherits && parent != null
            ? parent.display
            : initialComputedStyle.display),
    writingMode: specified.writingMode ??
        (propertyMeta['writingMode']!.inherits && parent != null
            ? parent.writingMode
            : initialComputedStyle.writingMode),
    direction: specified.direction ??
        (propertyMeta['direction']!.inherits && parent != null
            ? parent.direction
            : initialComputedStyle.direction),
    inlineSize: specified.inlineSize ??
        (propertyMeta['inlineSize']!.inherits && parent != null
            ? parent.inlineSize
            : initialComputedStyle.inlineSize),
    blockSize: specified.blockSize ??
        (propertyMeta['blockSize']!.inherits && parent != null
            ? parent.blockSize
            : initialComputedStyle.blockSize),
    minInlineSize: specified.minInlineSize ??
        (propertyMeta['minInlineSize']!.inherits && parent != null
            ? parent.minInlineSize
            : initialComputedStyle.minInlineSize),
    minBlockSize: specified.minBlockSize ??
        (propertyMeta['minBlockSize']!.inherits && parent != null
            ? parent.minBlockSize
            : initialComputedStyle.minBlockSize),
    maxInlineSize: specified.maxInlineSize ??
        (propertyMeta['maxInlineSize']!.inherits && parent != null
            ? parent.maxInlineSize
            : initialComputedStyle.maxInlineSize),
    maxBlockSize: specified.maxBlockSize ??
        (propertyMeta['maxBlockSize']!.inherits && parent != null
            ? parent.maxBlockSize
            : initialComputedStyle.maxBlockSize),
    boxSizing: specified.boxSizing ??
        (propertyMeta['boxSizing']!.inherits && parent != null
            ? parent.boxSizing
            : initialComputedStyle.boxSizing),
    marginBlockStart: _toComputedLengthOrAuto(specified.marginBlockStart ??
        (propertyMeta['marginBlockStart']!.inherits && parent != null
            ? parent.marginBlockStart
            : initialComputedStyle.marginBlockStart)),
    marginBlockEnd: _toComputedLengthOrAuto(specified.marginBlockEnd ??
        (propertyMeta['marginBlockEnd']!.inherits && parent != null
            ? parent.marginBlockEnd
            : initialComputedStyle.marginBlockEnd)),
    marginInlineStart: _toComputedLengthOrAuto(specified.marginInlineStart ??
        (propertyMeta['marginInlineStart']!.inherits && parent != null
            ? parent.marginInlineStart
            : initialComputedStyle.marginInlineStart)),
    marginInlineEnd: _toComputedLengthOrAuto(specified.marginInlineEnd ??
        (propertyMeta['marginInlineEnd']!.inherits && parent != null
            ? parent.marginInlineEnd
            : initialComputedStyle.marginInlineEnd)),
    paddingBlockStart: _toComputedLength(specified.paddingBlockStart ??
        (propertyMeta['paddingBlockStart']!.inherits && parent != null
            ? parent.paddingBlockStart
            : initialComputedStyle.paddingBlockStart)),
    paddingBlockEnd: _toComputedLength(specified.paddingBlockEnd ??
        (propertyMeta['paddingBlockEnd']!.inherits && parent != null
            ? parent.paddingBlockEnd
            : initialComputedStyle.paddingBlockEnd)),
    paddingInlineStart: _toComputedLength(specified.paddingInlineStart ??
        (propertyMeta['paddingInlineStart']!.inherits && parent != null
            ? parent.paddingInlineStart
            : initialComputedStyle.paddingInlineStart)),
    paddingInlineEnd: _toComputedLength(specified.paddingInlineEnd ??
        (propertyMeta['paddingInlineEnd']!.inherits && parent != null
            ? parent.paddingInlineEnd
            : initialComputedStyle.paddingInlineEnd)),
    borderBlockStartWidth: specified.borderBlockStartWidth ??
        (propertyMeta['borderBlockStartWidth']!.inherits && parent != null
            ? parent.borderBlockStartWidth
            : initialComputedStyle.borderBlockStartWidth),
    borderBlockEndWidth: specified.borderBlockEndWidth ??
        (propertyMeta['borderBlockEndWidth']!.inherits && parent != null
            ? parent.borderBlockEndWidth
            : initialComputedStyle.borderBlockEndWidth),
    borderInlineStartWidth: specified.borderInlineStartWidth ??
        (propertyMeta['borderInlineStartWidth']!.inherits && parent != null
            ? parent.borderInlineStartWidth
            : initialComputedStyle.borderInlineStartWidth),
    borderInlineEndWidth: specified.borderInlineEndWidth ??
        (propertyMeta['borderInlineEndWidth']!.inherits && parent != null
            ? parent.borderInlineEndWidth
            : initialComputedStyle.borderInlineEndWidth),
    borderBlockStartStyle: specified.borderBlockStartStyle ??
        (propertyMeta['borderBlockStartStyle']!.inherits && parent != null
            ? parent.borderBlockStartStyle
            : initialComputedStyle.borderBlockStartStyle),
    borderBlockEndStyle: specified.borderBlockEndStyle ??
        (propertyMeta['borderBlockEndStyle']!.inherits && parent != null
            ? parent.borderBlockEndStyle
            : initialComputedStyle.borderBlockEndStyle),
    borderInlineStartStyle: specified.borderInlineStartStyle ??
        (propertyMeta['borderInlineStartStyle']!.inherits && parent != null
            ? parent.borderInlineStartStyle
            : initialComputedStyle.borderInlineStartStyle),
    borderInlineEndStyle: specified.borderInlineEndStyle ??
        (propertyMeta['borderInlineEndStyle']!.inherits && parent != null
            ? parent.borderInlineEndStyle
            : initialComputedStyle.borderInlineEndStyle),
    borderBlockStartColor: specified.borderBlockStartColor ??
        (propertyMeta['borderBlockStartColor']!.inherits && parent != null
            ? parent.borderBlockStartColor
            : initialComputedStyle.borderBlockStartColor),
    borderBlockEndColor: specified.borderBlockEndColor ??
        (propertyMeta['borderBlockEndColor']!.inherits && parent != null
            ? parent.borderBlockEndColor
            : initialComputedStyle.borderBlockEndColor),
    borderInlineStartColor: specified.borderInlineStartColor ??
        (propertyMeta['borderInlineStartColor']!.inherits && parent != null
            ? parent.borderInlineStartColor
            : initialComputedStyle.borderInlineStartColor),
    borderInlineEndColor: specified.borderInlineEndColor ??
        (propertyMeta['borderInlineEndColor']!.inherits && parent != null
            ? parent.borderInlineEndColor
            : initialComputedStyle.borderInlineEndColor),
    backgroundColor: specified.backgroundColor ??
        (propertyMeta['backgroundColor']!.inherits && parent != null
            ? parent.backgroundColor
            : initialComputedStyle.backgroundColor),
    fontFamily: specified.fontFamily ??
        (propertyMeta['fontFamily']!.inherits && parent != null
            ? parent.fontFamily
            : initialComputedStyle.fontFamily),
    fontSize: specified.fontSize ??
        (propertyMeta['fontSize']!.inherits && parent != null
            ? parent.fontSize
            : initialComputedStyle.fontSize),
    fontWeight: specified.fontWeight ??
        (propertyMeta['fontWeight']!.inherits && parent != null
            ? parent.fontWeight
            : initialComputedStyle.fontWeight),
    fontStyle: specified.fontStyle ??
        (propertyMeta['fontStyle']!.inherits && parent != null
            ? parent.fontStyle
            : initialComputedStyle.fontStyle),
    underline: specified.underline ??
        (propertyMeta['underline']!.inherits && parent != null
            ? parent.underline
            : initialComputedStyle.underline),
    lineThrough: specified.lineThrough ??
        (propertyMeta['lineThrough']!.inherits && parent != null
            ? parent.lineThrough
            : initialComputedStyle.lineThrough),
    lineHeight: specified.lineHeight ??
        (propertyMeta['lineHeight']!.inherits && parent != null
            ? parent.lineHeight
            : initialComputedStyle.lineHeight),
    color: specified.color ??
        (propertyMeta['color']!.inherits && parent != null
            ? parent.color
            : initialComputedStyle.color),
    whiteSpace: specified.whiteSpace ??
        (propertyMeta['whiteSpace']!.inherits && parent != null
            ? parent.whiteSpace
            : initialComputedStyle.whiteSpace),
    verticalAlign: specified.verticalAlign ??
        (propertyMeta['verticalAlign']!.inherits && parent != null
            ? parent.verticalAlign
            : initialComputedStyle.verticalAlign),
    textAlign: specified.textAlign ??
        (propertyMeta['textAlign']!.inherits && parent != null
            ? parent.textAlign
            : initialComputedStyle.textAlign),
    textIndent: _toComputedLength(specified.textIndent ??
        (propertyMeta['textIndent']!.inherits && parent != null
            ? parent.textIndent
            : initialComputedStyle.textIndent)),
    textWrap: specified.textWrap ??
        (propertyMeta['textWrap']!.inherits && parent != null
            ? parent.textWrap
            : initialComputedStyle.textWrap),
    hyphens: specified.hyphens ??
        (propertyMeta['hyphens']!.inherits && parent != null
            ? parent.hyphens
            : initialComputedStyle.hyphens),
    language: specified.language ??
        (propertyMeta['language']!.inherits && parent != null
            ? parent.language
            : initialComputedStyle.language),
    hyphenateLimitChars: specified.hyphenateLimitChars ??
        (propertyMeta['hyphenateLimitChars']!.inherits && parent != null
            ? parent.hyphenateLimitChars
            : initialComputedStyle.hyphenateLimitChars),
    overflowWrap: specified.overflowWrap ??
        (propertyMeta['overflowWrap']!.inherits && parent != null
            ? parent.overflowWrap
            : initialComputedStyle.overflowWrap),
    letterSpacing: specified.letterSpacing ??
        (propertyMeta['letterSpacing']!.inherits && parent != null
            ? parent.letterSpacing
            : initialComputedStyle.letterSpacing),
    wordSpacing: specified.wordSpacing ??
        (propertyMeta['wordSpacing']!.inherits && parent != null
            ? parent.wordSpacing
            : initialComputedStyle.wordSpacing),
    textTransform: specified.textTransform ??
        (propertyMeta['textTransform']!.inherits && parent != null
            ? parent.textTransform
            : initialComputedStyle.textTransform),
    fontFeatureSettings: specified.fontFeatureSettings ??
        (propertyMeta['fontFeatureSettings']!.inherits && parent != null
            ? parent.fontFeatureSettings
            : initialComputedStyle.fontFeatureSettings),
    tabStops: specified.tabStops ??
        (propertyMeta['tabStops']!.inherits && parent != null
            ? parent.tabStops
            : initialComputedStyle.tabStops),
    defaultTabStop: specified.defaultTabStop ??
        (propertyMeta['defaultTabStop']!.inherits && parent != null
            ? parent.defaultTabStop
            : initialComputedStyle.defaultTabStop),
    float: specified.float ??
        (propertyMeta['float']!.inherits && parent != null
            ? parent.float
            : initialComputedStyle.float),
    clear: specified.clear ??
        (propertyMeta['clear']!.inherits && parent != null
            ? parent.clear
            : initialComputedStyle.clear),
    breakBefore: specified.breakBefore ??
        (propertyMeta['breakBefore']!.inherits && parent != null
            ? parent.breakBefore
            : initialComputedStyle.breakBefore),
    breakAfter: specified.breakAfter ??
        (propertyMeta['breakAfter']!.inherits && parent != null
            ? parent.breakAfter
            : initialComputedStyle.breakAfter),
    breakInside: specified.breakInside ??
        (propertyMeta['breakInside']!.inherits && parent != null
            ? parent.breakInside
            : initialComputedStyle.breakInside),
    widows: specified.widows ??
        (propertyMeta['widows']!.inherits && parent != null
            ? parent.widows
            : initialComputedStyle.widows),
    orphans: specified.orphans ??
        (propertyMeta['orphans']!.inherits && parent != null
            ? parent.orphans
            : initialComputedStyle.orphans),
    listStyleType: specified.listStyleType ??
        (propertyMeta['listStyleType']!.inherits && parent != null
            ? parent.listStyleType
            : initialComputedStyle.listStyleType),
    listStylePosition: specified.listStylePosition ??
        (propertyMeta['listStylePosition']!.inherits && parent != null
            ? parent.listStylePosition
            : initialComputedStyle.listStylePosition),
    markerText: specified.markerText ??
        (propertyMeta['markerText']!.inherits && parent != null
            ? parent.markerText
            : initialComputedStyle.markerText),
    position: specified.position ??
        (propertyMeta['position']!.inherits && parent != null
            ? parent.position
            : initialComputedStyle.position),
    insetBlockStart: specified.insetBlockStart ??
        (propertyMeta['insetBlockStart']!.inherits && parent != null
            ? parent.insetBlockStart
            : initialComputedStyle.insetBlockStart),
    insetBlockEnd: specified.insetBlockEnd ??
        (propertyMeta['insetBlockEnd']!.inherits && parent != null
            ? parent.insetBlockEnd
            : initialComputedStyle.insetBlockEnd),
    insetInlineStart: specified.insetInlineStart ??
        (propertyMeta['insetInlineStart']!.inherits && parent != null
            ? parent.insetInlineStart
            : initialComputedStyle.insetInlineStart),
    insetInlineEnd: specified.insetInlineEnd ??
        (propertyMeta['insetInlineEnd']!.inherits && parent != null
            ? parent.insetInlineEnd
            : initialComputedStyle.insetInlineEnd),
    zIndex: specified.zIndex ??
        (propertyMeta['zIndex']!.inherits && parent != null
            ? parent.zIndex
            : initialComputedStyle.zIndex),
    transform: specified.transform ??
        (propertyMeta['transform']!.inherits && parent != null
            ? parent.transform
            : initialComputedStyle.transform),
    transformOrigin: specified.transformOrigin ??
        (propertyMeta['transformOrigin']!.inherits && parent != null
            ? parent.transformOrigin
            : initialComputedStyle.transformOrigin),
    opacity: specified.opacity ??
        (propertyMeta['opacity']!.inherits && parent != null
            ? parent.opacity
            : initialComputedStyle.opacity),
  );
}
