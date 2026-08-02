/// Attribute registry for the cascade.
///
/// Port of `cascade/attr-registry.ts`.
library;

import '../state/attrs.dart';
import '../styles/style.dart';
import '../styles/writing_mode.dart';
import 'builtin_attrs.dart';

abstract class AttrInterpreter {
  String get attrKey;
  Style toStyle(dynamic value, [CascadeContext? ctx]);
  bool equals(dynamic a, dynamic b) => a == b;
}

class CascadeContext {
  final Style? parentStyle;
  const CascadeContext({this.parentStyle});
}

class AttrRegistry {
  final Map<String, AttrInterpreter> _interpreters = {};

  void register(AttrInterpreter interpreter) {
    _interpreters[interpreter.attrKey] = interpreter;
  }

  bool has(String attrKey) => _interpreters.containsKey(attrKey);

  AttrInterpreter? get(String attrKey) => _interpreters[attrKey];

  Style applyAll(ReadonlyAttrs attrs, [CascadeContext? ctx]) {
    // In Dart, we can't do Object.assign into a Partial<Style> easily.
    // Instead we collect all fields into variables and build a final Style.
    // However, since toStyle returns a Style with nullable fields, we just merge them.
    // Wait, the merging of multiple Styles requires a custom merge function.
    // We will accumulate by picking the non-null value from the latest contribution.
    
    Display? display;
    WritingMode? writingMode;
    Direction? direction;
    dynamic inlineSize;
    dynamic blockSize;
    dynamic minInlineSize;
    dynamic minBlockSize;
    dynamic maxInlineSize;
    dynamic maxBlockSize;
    BoxSizing? boxSizing;
    dynamic marginBlockStart;
    dynamic marginBlockEnd;
    dynamic marginInlineStart;
    dynamic marginInlineEnd;
    dynamic paddingBlockStart;
    dynamic paddingBlockEnd;
    dynamic paddingInlineStart;
    dynamic paddingInlineEnd;
    double? borderBlockStartWidth;
    double? borderBlockEndWidth;
    double? borderInlineStartWidth;
    double? borderInlineEndWidth;
    BorderStyle? borderBlockStartStyle;
    BorderStyle? borderBlockEndStyle;
    BorderStyle? borderInlineStartStyle;
    BorderStyle? borderInlineEndStyle;
    String? borderBlockStartColor;
    String? borderBlockEndColor;
    String? borderInlineStartColor;
    String? borderInlineEndColor;
    String? backgroundColor;
    String? fontFamily;
    dynamic fontSize;
    dynamic fontWeight;
    dynamic fontStyle;
    bool? underline;
    bool? lineThrough;
    dynamic lineHeight;
    String? color;
    dynamic whiteSpace;
    dynamic verticalAlign;
    dynamic textAlign;
    dynamic textIndent;
    dynamic textWrap;
    dynamic hyphens;
    String? language;
    List<int>? hyphenateLimitChars;
    dynamic overflowWrap;
    dynamic letterSpacing;
    dynamic wordSpacing;
    dynamic textTransform;
    List<String>? fontFeatureSettings;
    dynamic tabStops;
    double? defaultTabStop;
    dynamic float;
    dynamic clear;
    dynamic breakBefore;
    dynamic breakAfter;
    dynamic breakInside;
    int? widows;
    int? orphans;
    dynamic listStyleType;
    dynamic listStylePosition;
    String? markerText;
    dynamic position;
    dynamic insetBlockStart;
    dynamic insetBlockEnd;
    dynamic insetInlineStart;
    dynamic insetInlineEnd;
    dynamic zIndex;
    dynamic transform;
    dynamic transformOrigin;
    double? opacity;

    for (final entry in attrs.entries) {
      final interpreter = _interpreters[entry.key];
      if (interpreter == null) continue;

      final contrib = interpreter.toStyle(entry.value, ctx);

      display = contrib.display ?? display;
      writingMode = contrib.writingMode ?? writingMode;
      direction = contrib.direction ?? direction;
      inlineSize = contrib.inlineSize ?? inlineSize;
      blockSize = contrib.blockSize ?? blockSize;
      minInlineSize = contrib.minInlineSize ?? minInlineSize;
      minBlockSize = contrib.minBlockSize ?? minBlockSize;
      maxInlineSize = contrib.maxInlineSize ?? maxInlineSize;
      maxBlockSize = contrib.maxBlockSize ?? maxBlockSize;
      boxSizing = contrib.boxSizing ?? boxSizing;
      marginBlockStart = contrib.marginBlockStart ?? marginBlockStart;
      marginBlockEnd = contrib.marginBlockEnd ?? marginBlockEnd;
      marginInlineStart = contrib.marginInlineStart ?? marginInlineStart;
      marginInlineEnd = contrib.marginInlineEnd ?? marginInlineEnd;
      paddingBlockStart = contrib.paddingBlockStart ?? paddingBlockStart;
      paddingBlockEnd = contrib.paddingBlockEnd ?? paddingBlockEnd;
      paddingInlineStart = contrib.paddingInlineStart ?? paddingInlineStart;
      paddingInlineEnd = contrib.paddingInlineEnd ?? paddingInlineEnd;
      borderBlockStartWidth = contrib.borderBlockStartWidth ?? borderBlockStartWidth;
      borderBlockEndWidth = contrib.borderBlockEndWidth ?? borderBlockEndWidth;
      borderInlineStartWidth = contrib.borderInlineStartWidth ?? borderInlineStartWidth;
      borderInlineEndWidth = contrib.borderInlineEndWidth ?? borderInlineEndWidth;
      borderBlockStartStyle = contrib.borderBlockStartStyle ?? borderBlockStartStyle;
      borderBlockEndStyle = contrib.borderBlockEndStyle ?? borderBlockEndStyle;
      borderInlineStartStyle = contrib.borderInlineStartStyle ?? borderInlineStartStyle;
      borderInlineEndStyle = contrib.borderInlineEndStyle ?? borderInlineEndStyle;
      borderBlockStartColor = contrib.borderBlockStartColor ?? borderBlockStartColor;
      borderBlockEndColor = contrib.borderBlockEndColor ?? borderBlockEndColor;
      borderInlineStartColor = contrib.borderInlineStartColor ?? borderInlineStartColor;
      borderInlineEndColor = contrib.borderInlineEndColor ?? borderInlineEndColor;
      backgroundColor = contrib.backgroundColor ?? backgroundColor;
      fontFamily = contrib.fontFamily ?? fontFamily;
      fontSize = contrib.fontSize ?? fontSize;
      fontWeight = contrib.fontWeight ?? fontWeight;
      fontStyle = contrib.fontStyle ?? fontStyle;
      underline = contrib.underline ?? underline;
      lineThrough = contrib.lineThrough ?? lineThrough;
      lineHeight = contrib.lineHeight ?? lineHeight;
      color = contrib.color ?? color;
      whiteSpace = contrib.whiteSpace ?? whiteSpace;
      verticalAlign = contrib.verticalAlign ?? verticalAlign;
      textAlign = contrib.textAlign ?? textAlign;
      textIndent = contrib.textIndent ?? textIndent;
      textWrap = contrib.textWrap ?? textWrap;
      hyphens = contrib.hyphens ?? hyphens;
      language = contrib.language ?? language;
      hyphenateLimitChars = contrib.hyphenateLimitChars ?? hyphenateLimitChars;
      overflowWrap = contrib.overflowWrap ?? overflowWrap;
      letterSpacing = contrib.letterSpacing ?? letterSpacing;
      wordSpacing = contrib.wordSpacing ?? wordSpacing;
      textTransform = contrib.textTransform ?? textTransform;
      fontFeatureSettings = contrib.fontFeatureSettings ?? fontFeatureSettings;
      tabStops = contrib.tabStops ?? tabStops;
      defaultTabStop = contrib.defaultTabStop ?? defaultTabStop;
      float = contrib.float ?? float;
      clear = contrib.clear ?? clear;
      breakBefore = contrib.breakBefore ?? breakBefore;
      breakAfter = contrib.breakAfter ?? breakAfter;
      breakInside = contrib.breakInside ?? breakInside;
      widows = contrib.widows ?? widows;
      orphans = contrib.orphans ?? orphans;
      listStyleType = contrib.listStyleType ?? listStyleType;
      listStylePosition = contrib.listStylePosition ?? listStylePosition;
      markerText = contrib.markerText ?? markerText;
      position = contrib.position ?? position;
      insetBlockStart = contrib.insetBlockStart ?? insetBlockStart;
      insetBlockEnd = contrib.insetBlockEnd ?? insetBlockEnd;
      insetInlineStart = contrib.insetInlineStart ?? insetInlineStart;
      insetInlineEnd = contrib.insetInlineEnd ?? insetInlineEnd;
      zIndex = contrib.zIndex ?? zIndex;
      transform = contrib.transform ?? transform;
      transformOrigin = contrib.transformOrigin ?? transformOrigin;
      opacity = contrib.opacity ?? opacity;
    }

    return Style(
      display: display,
      writingMode: writingMode,
      direction: direction,
      inlineSize: inlineSize,
      blockSize: blockSize,
      minInlineSize: minInlineSize,
      minBlockSize: minBlockSize,
      maxInlineSize: maxInlineSize,
      maxBlockSize: maxBlockSize,
      boxSizing: boxSizing,
      marginBlockStart: marginBlockStart,
      marginBlockEnd: marginBlockEnd,
      marginInlineStart: marginInlineStart,
      marginInlineEnd: marginInlineEnd,
      paddingBlockStart: paddingBlockStart,
      paddingBlockEnd: paddingBlockEnd,
      paddingInlineStart: paddingInlineStart,
      paddingInlineEnd: paddingInlineEnd,
      borderBlockStartWidth: borderBlockStartWidth,
      borderBlockEndWidth: borderBlockEndWidth,
      borderInlineStartWidth: borderInlineStartWidth,
      borderInlineEndWidth: borderInlineEndWidth,
      borderBlockStartStyle: borderBlockStartStyle,
      borderBlockEndStyle: borderBlockEndStyle,
      borderInlineStartStyle: borderInlineStartStyle,
      borderInlineEndStyle: borderInlineEndStyle,
      borderBlockStartColor: borderBlockStartColor,
      borderBlockEndColor: borderBlockEndColor,
      borderInlineStartColor: borderInlineStartColor,
      borderInlineEndColor: borderInlineEndColor,
      backgroundColor: backgroundColor,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      underline: underline,
      lineThrough: lineThrough,
      lineHeight: lineHeight,
      color: color,
      whiteSpace: whiteSpace,
      verticalAlign: verticalAlign,
      textAlign: textAlign,
      textIndent: textIndent,
      textWrap: textWrap,
      hyphens: hyphens,
      language: language,
      hyphenateLimitChars: hyphenateLimitChars,
      overflowWrap: overflowWrap,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textTransform: textTransform,
      fontFeatureSettings: fontFeatureSettings,
      tabStops: tabStops,
      defaultTabStop: defaultTabStop,
      float: float,
      clear: clear,
      breakBefore: breakBefore,
      breakAfter: breakAfter,
      breakInside: breakInside,
      widows: widows,
      orphans: orphans,
      listStyleType: listStyleType,
      listStylePosition: listStylePosition,
      markerText: markerText,
      position: position,
      insetBlockStart: insetBlockStart,
      insetBlockEnd: insetBlockEnd,
      insetInlineStart: insetInlineStart,
      insetInlineEnd: insetInlineEnd,
      zIndex: zIndex,
      transform: transform,
      transformOrigin: transformOrigin,
      opacity: opacity,
    );
  }
}

final attrRegistry = createDefaultAttrRegistry();

AttrRegistry createDefaultAttrRegistry() {
  final reg = AttrRegistry();
  registerBuiltinAttrs(reg);
  return reg;
}
