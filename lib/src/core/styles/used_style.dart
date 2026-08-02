/// Used style.
///
/// Port of `styles/used-style.ts`.
library;

import 'color.dart';
import 'length.dart';
import 'style.dart';
import 'tab_stops.dart';
import 'writing_mode.dart';

class UsedStyle {
  final Display display;
  final WritingMode writingMode;
  final Direction direction;
  final BoxSizing boxSizing;

  final UsedLength marginBlockStart;
  final UsedLength marginBlockEnd;
  final UsedLength marginInlineStart;
  final UsedLength marginInlineEnd;

  final UsedLength paddingBlockStart;
  final UsedLength paddingBlockEnd;
  final UsedLength paddingInlineStart;
  final UsedLength paddingInlineEnd;

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
  final double fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final bool underline;
  final bool lineThrough;
  final double lineHeight;
  final Color color;

  final WhiteSpace whiteSpace;
  final VerticalAlign verticalAlign;

  final TextAlign textAlign;
  final UsedLength textIndent;
  final TextWrap textWrap;
  final Hyphens hyphens;
  final String language;
  final List<int> hyphenateLimitChars;
  final OverflowWrap overflowWrap;
  final dynamic letterSpacing; // UsedLength or 'normal'
  final dynamic wordSpacing; // UsedLength or 'normal'
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

  const UsedStyle({
    required this.display,
    required this.writingMode,
    required this.direction,
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
  });
}
