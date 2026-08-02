/// Built-in attribute interpreters for the standard text styles.
///
/// Port of `cascade/builtin-attrs.ts`.
library;

import '../styles/length.dart';
import '../styles/style.dart';
import '../styles/tab_stops.dart';
import 'attr_registry.dart';

Length? _asStructuredLength(dynamic value) {
  if (value is Map) {
    final unit = value['unit'];
    final val = value['value'];
    if (val is num && (unit == 'px' || unit == 'em' || unit == 'percent')) {
      if (unit == 'px') return Length.px(val.toDouble());
      if (unit == 'em') return Length.em(val.toDouble());
      if (unit == 'percent') return Length.percent(val.toDouble());
    }
  }
  return null;
}

Length? _asLength(dynamic value) {
  if (value is num) return Length.px(value.toDouble());
  return _asStructuredLength(value);
}

bool isTextAlign(dynamic value) {
  return value == 'start' || value == 'end' || value == 'center' || value == 'justify';
}

AttrInterpreter _makeLengthOrNormalInterpreter(String attrKey) {
  return _LengthOrNormalInterpreter(attrKey);
}

class _LengthOrNormalInterpreter extends AttrInterpreter {
  @override
  final String attrKey;

  _LengthOrNormalInterpreter(this.attrKey);

  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (value == 'normal') {
      return Style(
        letterSpacing: attrKey == 'letterSpacing' ? 'normal' : null,
        wordSpacing: attrKey == 'wordSpacing' ? 'normal' : null,
      );
    }
    final length = _asLength(value);
    if (length != null) {
      return Style(
        letterSpacing: attrKey == 'letterSpacing' ? length : null,
        wordSpacing: attrKey == 'wordSpacing' ? length : null,
      );
    }
    return const Style();
  }
}

class BoldInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'bold';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value == true) ? const Style(fontWeight: FontWeight.bold) : const Style();
}

class ItalicInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'italic';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value == true) ? const Style(fontStyle: FontStyle.italic) : const Style();
}

class UnderlineInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'underline';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value == true) ? const Style(underline: true) : const Style();
}

class StrikethroughInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'strikethrough';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value == true) ? const Style(lineThrough: true) : const Style();
}

class LinkInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'link';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value is String) ? const Style(color: '#1a73e8', underline: true) : const Style();
}

class FontFamilyInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'fontFamily';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value is String) ? Style(fontFamily: value) : const Style();
}

class LangInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'lang';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value is String) ? Style(language: value) : const Style();
}

class HyphensInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'hyphens';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (value == 'none') return const Style(hyphens: Hyphens.none);
    if (value == 'manual') return const Style(hyphens: Hyphens.manual);
    if (value == 'auto') return const Style(hyphens: Hyphens.auto);
    return const Style();
  }
}

class FontSizeInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'fontSize';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (value is num) return Style(fontSize: Length.px(value.toDouble()));
    final length = _asStructuredLength(value);
    if (length != null) return Style(fontSize: length);
    return const Style();
  }
}

class ColorInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'color';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value is String) ? Style(color: value) : const Style();
}

class BackgroundColorInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'backgroundColor';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) => 
    (value is String) ? Style(backgroundColor: value) : const Style();
}

class TextAlignInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'textAlign';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (isTextAlign(value)) {
      if (value == 'start') return const Style(textAlign: TextAlign.start);
      if (value == 'end') return const Style(textAlign: TextAlign.end);
      if (value == 'center') return const Style(textAlign: TextAlign.center);
      if (value == 'justify') return const Style(textAlign: TextAlign.justify);
    }
    return const Style();
  }
}

class TextTransformInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'textTransform';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (value == 'none') return const Style(textTransform: TextTransform.none);
    if (value == 'capitalize') return const Style(textTransform: TextTransform.capitalize);
    if (value == 'uppercase') return const Style(textTransform: TextTransform.uppercase);
    if (value == 'lowercase') return const Style(textTransform: TextTransform.lowercase);
    return const Style();
  }
}

class LineHeightInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'lineHeight';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    if (value is num) return Style(lineHeight: value.toDouble());
    final length = _asStructuredLength(value);
    if (length != null) return Style(lineHeight: length);
    return const Style();
  }
}

class TextIndentInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'textIndent';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    final length = _asLength(value);
    if (length != null) return Style(textIndent: length);
    return const Style();
  }
}

List<TabStop>? normalizeTabStops(dynamic value) {
  if (value is! List) return null;
  final stops = <TabStop>[];
  for (final raw in value) {
    if (raw is! Map) continue;
    final pos = raw['position'];
    final position = (pos is num && !pos.isNaN && !pos.isInfinite) ? (pos > 0 ? pos.toDouble() : 0.0) : 0.0;
    
    TabAlignment alignment = TabAlignment.left;
    final alignVal = raw['alignment'];
    if (alignVal == 'left') alignment = TabAlignment.left;
    else if (alignVal == 'center') alignment = TabAlignment.center;
    else if (alignVal == 'right') alignment = TabAlignment.right;
    else if (alignVal == 'decimal') alignment = TabAlignment.decimal;
    else if (alignVal == 'content-edge') alignment = TabAlignment.contentEdge;
    
    LeaderStyle leader = LeaderStyle.none;
    final leaderVal = raw['leader'];
    if (leaderVal == 'none') leader = LeaderStyle.none;
    else if (leaderVal == 'dot') leader = LeaderStyle.dot;
    else if (leaderVal == 'dash') leader = LeaderStyle.dash;
    else if (leaderVal == 'line') leader = LeaderStyle.line;

    stops.add(TabStop(position: position, alignment: alignment, leader: leader));
  }
  stops.sort((a, b) => a.position.compareTo(b.position));
  return stops;
}

class TabStopsInterpreter extends AttrInterpreter {
  @override
  String get attrKey => 'tabStops';
  @override
  Style toStyle(dynamic value, [CascadeContext? ctx]) {
    final stops = normalizeTabStops(value);
    if (stops != null) return Style(tabStops: stops);
    return const Style();
  }
}

void registerBuiltinAttrs(AttrRegistry registry) {
  registry.register(BoldInterpreter());
  registry.register(ItalicInterpreter());
  registry.register(UnderlineInterpreter());
  registry.register(StrikethroughInterpreter());
  registry.register(LinkInterpreter());
  registry.register(FontFamilyInterpreter());
  registry.register(LangInterpreter());
  registry.register(HyphensInterpreter());
  registry.register(FontSizeInterpreter());
  registry.register(ColorInterpreter());
  registry.register(BackgroundColorInterpreter());
  
  registry.register(TextAlignInterpreter());
  registry.register(TextTransformInterpreter());
  registry.register(LineHeightInterpreter());
  registry.register(TextIndentInterpreter());
  
  registry.register(_makeLengthOrNormalInterpreter('letterSpacing'));
  registry.register(_makeLengthOrNormalInterpreter('wordSpacing'));
  
  registry.register(TabStopsInterpreter());
}
