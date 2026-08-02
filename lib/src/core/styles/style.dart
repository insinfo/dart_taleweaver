/// Partial style ?" what a render fn or state node specifies.
///
/// Port of `styles/style.ts`.
library;

import 'color.dart';
import 'length.dart';
import 'position.dart';
import 'tab_stops.dart';
import 'writing_mode.dart';

enum Display {
  block,
  inline,
  inlineBlock,
  listItem,
  table,
  tableRow,
  tableCell,
  flowRoot,
  none,
  contents;

  String get value {
    switch (this) {
      case Display.block:
        return 'block';
      case Display.inline:
        return 'inline';
      case Display.inlineBlock:
        return 'inline-block';
      case Display.listItem:
        return 'list-item';
      case Display.table:
        return 'table';
      case Display.tableRow:
        return 'table-row';
      case Display.tableCell:
        return 'table-cell';
      case Display.flowRoot:
        return 'flow-root';
      case Display.none:
        return 'none';
      case Display.contents:
        return 'contents';
    }
  }

  static Display fromString(String val) {
    switch (val) {
      case 'block':
        return Display.block;
      case 'inline':
        return Display.inline;
      case 'inline-block':
        return Display.inlineBlock;
      case 'list-item':
        return Display.listItem;
      case 'table':
        return Display.table;
      case 'table-row':
        return Display.tableRow;
      case 'table-cell':
        return Display.tableCell;
      case 'flow-root':
        return Display.flowRoot;
      case 'none':
        return Display.none;
      case 'contents':
        return Display.contents;
      default:
        throw ArgumentError('Unhandled Display: $val');
    }
  }
}

enum BorderStyle {
  none,
  solid,
  dashed,
  dotted;

  String get value {
    switch (this) {
      case BorderStyle.none:
        return 'none';
      case BorderStyle.solid:
        return 'solid';
      case BorderStyle.dashed:
        return 'dashed';
      case BorderStyle.dotted:
        return 'dotted';
    }
  }

  static BorderStyle fromString(String val) {
    switch (val) {
      case 'none':
        return BorderStyle.none;
      case 'solid':
        return BorderStyle.solid;
      case 'dashed':
        return BorderStyle.dashed;
      case 'dotted':
        return BorderStyle.dotted;
      default:
        throw ArgumentError('Unhandled BorderStyle: $val');
    }
  }
}

/// FontWeight can be normal, bold, lighter, bolder, or a number.
/// In Dart, we can represent it with a class.
class FontWeight {
  final dynamic _val;
  const FontWeight._(this._val);

  static const normal = FontWeight._('normal');
  static const bold = FontWeight._('bold');
  static const lighter = FontWeight._('lighter');
  static const bolder = FontWeight._('bolder');

  factory FontWeight.number(int val) => FontWeight._(val);

  dynamic get value => _val;

  static FontWeight fromValue(dynamic val) {
    if (val is int) return FontWeight.number(val);
    if (val == 'normal') return normal;
    if (val == 'bold') return bold;
    if (val == 'lighter') return lighter;
    if (val == 'bolder') return bolder;
    throw ArgumentError('Unhandled FontWeight: $val');
  }
}

enum FontStyle {
  normal,
  italic,
  oblique;

  String get value {
    switch (this) {
      case FontStyle.normal:
        return 'normal';
      case FontStyle.italic:
        return 'italic';
      case FontStyle.oblique:
        return 'oblique';
    }
  }
}

enum WhiteSpace {
  normal,
  nowrap,
  pre,
  preWrap,
  preLine,
  breakSpaces;

  String get value {
    switch (this) {
      case WhiteSpace.normal:
        return 'normal';
      case WhiteSpace.nowrap:
        return 'nowrap';
      case WhiteSpace.pre:
        return 'pre';
      case WhiteSpace.preWrap:
        return 'pre-wrap';
      case WhiteSpace.preLine:
        return 'pre-line';
      case WhiteSpace.breakSpaces:
        return 'break-spaces';
    }
  }
}

enum VerticalAlign {
  baseline,
  sub,
  superAlign,
  top,
  middle,
  bottom;

  String get value {
    switch (this) {
      case VerticalAlign.baseline:
        return 'baseline';
      case VerticalAlign.sub:
        return 'sub';
      case VerticalAlign.superAlign:
        return 'super';
      case VerticalAlign.top:
        return 'top';
      case VerticalAlign.middle:
        return 'middle';
      case VerticalAlign.bottom:
        return 'bottom';
    }
  }
}

enum TextAlign {
  start,
  end,
  center,
  justify;

  String get value {
    switch (this) {
      case TextAlign.start:
        return 'start';
      case TextAlign.end:
        return 'end';
      case TextAlign.center:
        return 'center';
      case TextAlign.justify:
        return 'justify';
    }
  }
}

enum TextTransform {
  none,
  capitalize,
  uppercase,
  lowercase;

  String get value {
    switch (this) {
      case TextTransform.none:
        return 'none';
      case TextTransform.capitalize:
        return 'capitalize';
      case TextTransform.uppercase:
        return 'uppercase';
      case TextTransform.lowercase:
        return 'lowercase';
    }
  }
}

enum Float {
  none,
  inlineStart,
  inlineEnd;

  String get value {
    switch (this) {
      case Float.none:
        return 'none';
      case Float.inlineStart:
        return 'inline-start';
      case Float.inlineEnd:
        return 'inline-end';
    }
  }
}

enum Clear {
  none,
  inlineStart,
  inlineEnd,
  both;

  String get value {
    switch (this) {
      case Clear.none:
        return 'none';
      case Clear.inlineStart:
        return 'inline-start';
      case Clear.inlineEnd:
        return 'inline-end';
      case Clear.both:
        return 'both';
    }
  }
}

enum BreakBefore {
  auto,
  page,
  avoid;

  String get value {
    switch (this) {
      case BreakBefore.auto:
        return 'auto';
      case BreakBefore.page:
        return 'page';
      case BreakBefore.avoid:
        return 'avoid';
    }
  }
}

enum BreakAfter {
  auto,
  page,
  avoid;

  String get value {
    switch (this) {
      case BreakAfter.auto:
        return 'auto';
      case BreakAfter.page:
        return 'page';
      case BreakAfter.avoid:
        return 'avoid';
    }
  }
}

enum BreakInside {
  auto,
  avoid;

  String get value {
    switch (this) {
      case BreakInside.auto:
        return 'auto';
      case BreakInside.avoid:
        return 'avoid';
    }
  }
}

class ListStyleType {
  final dynamic _val;
  const ListStyleType._(this._val);

  static const disc = ListStyleType._('disc');
  static const circle = ListStyleType._('circle');
  static const square = ListStyleType._('square');
  static const decimal = ListStyleType._('decimal');
  static const lowerAlpha = ListStyleType._('lower-alpha');
  static const upperAlpha = ListStyleType._('upper-alpha');
  static const lowerRoman = ListStyleType._('lower-roman');
  static const upperRoman = ListStyleType._('upper-roman');
  static const none = ListStyleType._('none');

  factory ListStyleType.content(String content) =>
      ListStyleType._({'content': content});

  dynamic get value => _val;
}

enum ListStylePosition {
  outside,
  inside;

  String get value {
    switch (this) {
      case ListStylePosition.outside:
        return 'outside';
      case ListStylePosition.inside:
        return 'inside';
    }
  }
}

enum BoxSizing {
  contentBox,
  borderBox;

  String get value {
    switch (this) {
      case BoxSizing.contentBox:
        return 'content-box';
      case BoxSizing.borderBox:
        return 'border-box';
    }
  }
}

enum TextWrap {
  wrap,
  nowrap,
  balance,
  pretty,
  stable;

  String get value {
    switch (this) {
      case TextWrap.wrap:
        return 'wrap';
      case TextWrap.nowrap:
        return 'nowrap';
      case TextWrap.balance:
        return 'balance';
      case TextWrap.pretty:
        return 'pretty';
      case TextWrap.stable:
        return 'stable';
    }
  }
}

enum Hyphens {
  none,
  manual,
  auto;

  String get value {
    switch (this) {
      case Hyphens.none:
        return 'none';
      case Hyphens.manual:
        return 'manual';
      case Hyphens.auto:
        return 'auto';
    }
  }
}

enum OverflowWrap {
  normal,
  breakWord,
  anywhere;

  String get value {
    switch (this) {
      case OverflowWrap.normal:
        return 'normal';
      case OverflowWrap.breakWord:
        return 'break-word';
      case OverflowWrap.anywhere:
        return 'anywhere';
    }
  }
}

class Style {
  final Display? display;
  final WritingMode? writingMode;
  final Direction? direction;
  final dynamic inlineSize;
  final dynamic blockSize;
  final dynamic minInlineSize;
  final dynamic minBlockSize;
  final dynamic maxInlineSize;
  final dynamic maxBlockSize;
  final BoxSizing? boxSizing;

  final LengthOrAuto? marginBlockStart;
  final LengthOrAuto? marginBlockEnd;
  final LengthOrAuto? marginInlineStart;
  final LengthOrAuto? marginInlineEnd;

  final Length? paddingBlockStart;
  final Length? paddingBlockEnd;
  final Length? paddingInlineStart;
  final Length? paddingInlineEnd;

  final double? borderBlockStartWidth;
  final double? borderBlockEndWidth;
  final double? borderInlineStartWidth;
  final double? borderInlineEndWidth;
  final BorderStyle? borderBlockStartStyle;
  final BorderStyle? borderBlockEndStyle;
  final BorderStyle? borderInlineStartStyle;
  final BorderStyle? borderInlineEndStyle;
  final Color? borderBlockStartColor;
  final Color? borderBlockEndColor;
  final Color? borderInlineStartColor;
  final Color? borderInlineEndColor;

  final Color? backgroundColor;

  final String? fontFamily;
  final Length? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final bool? underline;
  final bool? lineThrough;
  final dynamic lineHeight;
  final Color? color;

  final WhiteSpace? whiteSpace;
  final VerticalAlign? verticalAlign;

  final TextAlign? textAlign;
  final Length? textIndent;
  final TextWrap? textWrap;
  final Hyphens? hyphens;
  final String? language;
  final List<int>? hyphenateLimitChars;
  final OverflowWrap? overflowWrap;
  final dynamic letterSpacing;
  final dynamic wordSpacing;
  final TextTransform? textTransform;
  final List<String>? fontFeatureSettings;
  final List<TabStop>? tabStops;
  final double? defaultTabStop;

  final Float? float;
  final Clear? clear;

  final BreakBefore? breakBefore;
  final BreakAfter? breakAfter;
  final BreakInside? breakInside;

  final int? widows;
  final int? orphans;

  final ListStyleType? listStyleType;
  final ListStylePosition? listStylePosition;
  final String? markerText;

  final Position? position;
  final LengthOrAuto? insetBlockStart;
  final LengthOrAuto? insetBlockEnd;
  final LengthOrAuto? insetInlineStart;
  final LengthOrAuto? insetInlineEnd;
  final dynamic zIndex;
  final List<TransformFn>? transform;
  final TransformOrigin? transformOrigin;
  final double? opacity;

  const Style({
    this.display,
    this.writingMode,
    this.direction,
    this.inlineSize,
    this.blockSize,
    this.minInlineSize,
    this.minBlockSize,
    this.maxInlineSize,
    this.maxBlockSize,
    this.boxSizing,
    this.marginBlockStart,
    this.marginBlockEnd,
    this.marginInlineStart,
    this.marginInlineEnd,
    this.paddingBlockStart,
    this.paddingBlockEnd,
    this.paddingInlineStart,
    this.paddingInlineEnd,
    this.borderBlockStartWidth,
    this.borderBlockEndWidth,
    this.borderInlineStartWidth,
    this.borderInlineEndWidth,
    this.borderBlockStartStyle,
    this.borderBlockEndStyle,
    this.borderInlineStartStyle,
    this.borderInlineEndStyle,
    this.borderBlockStartColor,
    this.borderBlockEndColor,
    this.borderInlineStartColor,
    this.borderInlineEndColor,
    this.backgroundColor,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.underline,
    this.lineThrough,
    this.lineHeight,
    this.color,
    this.whiteSpace,
    this.verticalAlign,
    this.textAlign,
    this.textIndent,
    this.textWrap,
    this.hyphens,
    this.language,
    this.hyphenateLimitChars,
    this.overflowWrap,
    this.letterSpacing,
    this.wordSpacing,
    this.textTransform,
    this.fontFeatureSettings,
    this.tabStops,
    this.defaultTabStop,
    this.float,
    this.clear,
    this.breakBefore,
    this.breakAfter,
    this.breakInside,
    this.widows,
    this.orphans,
    this.listStyleType,
    this.listStylePosition,
    this.markerText,
    this.position,
    this.insetBlockStart,
    this.insetBlockEnd,
    this.insetInlineStart,
    this.insetInlineEnd,
    this.zIndex,
    this.transform,
    this.transformOrigin,
    this.opacity,
  });
}
