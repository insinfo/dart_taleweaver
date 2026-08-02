/// Resolved style.
///
/// Port of `styles/computed-style.ts`.
library;

import 'color.dart';
import 'length.dart';
import 'position.dart';
import 'style.dart';
import 'tab_stops.dart';
import 'writing_mode.dart';

class ComputedStyle {
  final Display display;
  final WritingMode writingMode;
  final Direction direction;

  final dynamic inlineSize;
  final dynamic blockSize;
  final dynamic minInlineSize;
  final dynamic minBlockSize;
  final dynamic maxInlineSize;
  final dynamic maxBlockSize;
  final BoxSizing boxSizing;

  final ComputedLengthOrAuto marginBlockStart;
  final ComputedLengthOrAuto marginBlockEnd;
  final ComputedLengthOrAuto marginInlineStart;
  final ComputedLengthOrAuto marginInlineEnd;

  final ComputedLength paddingBlockStart;
  final ComputedLength paddingBlockEnd;
  final ComputedLength paddingInlineStart;
  final ComputedLength paddingInlineEnd;

  final double borderBlockStartWidth;
  final double borderBlockEndWidth;
  final double borderInlineStartWidth;
  final double borderInlineEndWidth;
  final BorderStyle borderBlockStartStyle;
  final BorderStyle borderBlockEndStyle;
  final BorderStyle borderInlineStartStyle;
  final BorderStyle borderInlineEndStyle;
  final Color borderBlockStartColor;
  final Color borderBlockEndColor;
  final Color borderInlineStartColor;
  final Color borderInlineEndColor;

  final Color backgroundColor;

  final String fontFamily;
  final dynamic fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final bool underline;
  final bool lineThrough;
  final dynamic lineHeight;
  final Color color;

  final WhiteSpace whiteSpace;
  final VerticalAlign verticalAlign;

  final TextAlign textAlign;
  final ComputedLength textIndent;
  final TextWrap textWrap;
  final Hyphens hyphens;
  final String language;
  final List<int> hyphenateLimitChars;
  final OverflowWrap overflowWrap;
  final dynamic letterSpacing;
  final dynamic wordSpacing;
  final TextTransform textTransform;
  final List<String> fontFeatureSettings;
  final List<TabStop> tabStops;
  final double defaultTabStop;

  final Float float;
  final Clear clear;

  final BreakBefore breakBefore;
  final BreakAfter breakAfter;
  final BreakInside breakInside;

  final int widows;
  final int orphans;

  final ListStyleType listStyleType;
  final ListStylePosition listStylePosition;

  final String? markerText;

  final Position position;
  final dynamic insetBlockStart;
  final dynamic insetBlockEnd;
  final dynamic insetInlineStart;
  final dynamic insetInlineEnd;
  final dynamic zIndex;
  final List<TransformFn> transform;
  final TransformOrigin transformOrigin;
  final double opacity;

  const ComputedStyle({
    required this.display,
    required this.writingMode,
    required this.direction,
    required this.inlineSize,
    required this.blockSize,
    required this.minInlineSize,
    required this.minBlockSize,
    required this.maxInlineSize,
    required this.maxBlockSize,
    required this.boxSizing,
    required this.marginBlockStart,
    required this.marginBlockEnd,
    required this.marginInlineStart,
    required this.marginInlineEnd,
    required this.paddingBlockStart,
    required this.paddingBlockEnd,
    required this.paddingInlineStart,
    required this.paddingInlineEnd,
    required this.borderBlockStartWidth,
    required this.borderBlockEndWidth,
    required this.borderInlineStartWidth,
    required this.borderInlineEndWidth,
    required this.borderBlockStartStyle,
    required this.borderBlockEndStyle,
    required this.borderInlineStartStyle,
    required this.borderInlineEndStyle,
    required this.borderBlockStartColor,
    required this.borderBlockEndColor,
    required this.borderInlineStartColor,
    required this.borderInlineEndColor,
    required this.backgroundColor,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.fontStyle,
    required this.underline,
    required this.lineThrough,
    required this.lineHeight,
    required this.color,
    required this.whiteSpace,
    required this.verticalAlign,
    required this.textAlign,
    required this.textIndent,
    required this.textWrap,
    required this.hyphens,
    required this.language,
    required this.hyphenateLimitChars,
    required this.overflowWrap,
    required this.letterSpacing,
    required this.wordSpacing,
    required this.textTransform,
    required this.fontFeatureSettings,
    required this.tabStops,
    required this.defaultTabStop,
    required this.float,
    required this.clear,
    required this.breakBefore,
    required this.breakAfter,
    required this.breakInside,
    required this.widows,
    required this.orphans,
    required this.listStyleType,
    required this.listStylePosition,
    this.markerText,
    required this.position,
    required this.insetBlockStart,
    required this.insetBlockEnd,
    required this.insetInlineStart,
    required this.insetInlineEnd,
    required this.zIndex,
    required this.transform,
    required this.transformOrigin,
    required this.opacity,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputedStyle &&
          runtimeType == other.runtimeType &&
          other.display == display &&
          other.writingMode == writingMode &&
          other.direction == direction &&
          other.inlineSize == inlineSize &&
          other.blockSize == blockSize &&
          other.minInlineSize == minInlineSize &&
          other.minBlockSize == minBlockSize &&
          other.maxInlineSize == maxInlineSize &&
          other.maxBlockSize == maxBlockSize &&
          other.boxSizing == boxSizing &&
          other.marginBlockStart == marginBlockStart &&
          other.marginBlockEnd == marginBlockEnd &&
          other.marginInlineStart == marginInlineStart &&
          other.marginInlineEnd == marginInlineEnd &&
          other.paddingBlockStart == paddingBlockStart &&
          other.paddingBlockEnd == paddingBlockEnd &&
          other.paddingInlineStart == paddingInlineStart &&
          other.paddingInlineEnd == paddingInlineEnd &&
          other.borderBlockStartWidth == borderBlockStartWidth &&
          other.borderBlockEndWidth == borderBlockEndWidth &&
          other.borderInlineStartWidth == borderInlineStartWidth &&
          other.borderInlineEndWidth == borderInlineEndWidth &&
          other.borderBlockStartStyle == borderBlockStartStyle &&
          other.borderBlockEndStyle == borderBlockEndStyle &&
          other.borderInlineStartStyle == borderInlineStartStyle &&
          other.borderInlineEndStyle == borderInlineEndStyle &&
          other.borderBlockStartColor == borderBlockStartColor &&
          other.borderBlockEndColor == borderBlockEndColor &&
          other.borderInlineStartColor == borderInlineStartColor &&
          other.borderInlineEndColor == borderInlineEndColor &&
          other.backgroundColor == backgroundColor &&
          other.fontFamily == fontFamily &&
          other.fontSize == fontSize &&
          other.fontWeight == fontWeight &&
          other.fontStyle == fontStyle &&
          other.underline == underline &&
          other.lineThrough == lineThrough &&
          other.lineHeight == lineHeight &&
          other.color == color &&
          other.whiteSpace == whiteSpace &&
          other.verticalAlign == verticalAlign &&
          other.textAlign == textAlign &&
          other.textIndent == textIndent &&
          other.textWrap == textWrap &&
          other.hyphens == hyphens &&
          other.language == language &&
          // lists using simple equality or identical since we freeze them usually
          // using listEquality would be safer, but for now simple identical is fine in this port
          other.hyphenateLimitChars == hyphenateLimitChars &&
          other.overflowWrap == overflowWrap &&
          other.letterSpacing == letterSpacing &&
          other.wordSpacing == wordSpacing &&
          other.textTransform == textTransform &&
          other.fontFeatureSettings == fontFeatureSettings &&
          other.tabStops == tabStops &&
          other.defaultTabStop == defaultTabStop &&
          other.float == float &&
          other.clear == clear &&
          other.breakBefore == breakBefore &&
          other.breakAfter == breakAfter &&
          other.breakInside == breakInside &&
          other.widows == widows &&
          other.orphans == orphans &&
          other.listStyleType == listStyleType &&
          other.listStylePosition == listStylePosition &&
          other.markerText == markerText &&
          other.position == position &&
          other.insetBlockStart == insetBlockStart &&
          other.insetBlockEnd == insetBlockEnd &&
          other.insetInlineStart == insetInlineStart &&
          other.insetInlineEnd == insetInlineEnd &&
          other.zIndex == zIndex &&
          other.transform == transform &&
          other.transformOrigin == transformOrigin &&
          other.opacity == opacity;

  @override
  int get hashCode => Object.hashAll([
        display,
        writingMode,
        direction,
        inlineSize,
        blockSize,
        minInlineSize,
        minBlockSize,
        maxInlineSize,
        maxBlockSize,
        boxSizing,
        marginBlockStart,
        marginBlockEnd,
        marginInlineStart,
        marginInlineEnd,
        paddingBlockStart,
        paddingBlockEnd,
        paddingInlineStart,
        paddingInlineEnd,
        borderBlockStartWidth,
        borderBlockEndWidth,
        borderInlineStartWidth,
        borderInlineEndWidth,
        borderBlockStartStyle,
        borderBlockEndStyle,
        borderInlineStartStyle,
        borderInlineEndStyle,
        borderBlockStartColor,
        borderBlockEndColor,
        borderInlineStartColor,
        borderInlineEndColor,
        backgroundColor,
        fontFamily,
        fontSize,
        fontWeight,
        fontStyle,
        underline,
        lineThrough,
        lineHeight,
        color,
        whiteSpace,
        verticalAlign,
        textAlign,
        textIndent,
        textWrap,
        hyphens,
        language,
        hyphenateLimitChars,
        overflowWrap,
        letterSpacing,
        wordSpacing,
        textTransform,
        fontFeatureSettings,
        tabStops,
        defaultTabStop,
        float,
        clear,
        breakBefore,
        breakAfter,
        breakInside,
        widows,
        orphans,
        listStyleType,
        listStylePosition,
        markerText,
        position,
        insetBlockStart,
        insetBlockEnd,
        insetInlineStart,
        insetInlineEnd,
        zIndex,
        transform,
        transformOrigin,
        opacity
      ]);
}
