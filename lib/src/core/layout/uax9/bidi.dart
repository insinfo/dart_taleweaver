library;

import 'bidi_class.dart';

class BidiResult {
  final List<int> levels;
  final List<BidiClass> types;
  final int paragraphLevel;
  const BidiResult(this.levels, this.types, this.paragraphLevel);
}

int computeParagraphLevel(List<BidiClass> types) {
  var isolates = 0;
  for (final type in types) {
    if (type == BidiClass.lri ||
        type == BidiClass.rli ||
        type == BidiClass.fsi) {
      isolates++;
    } else if (type == BidiClass.pdi) {
      if (isolates > 0) isolates--;
    } else if (isolates == 0) {
      if (type == BidiClass.r || type == BidiClass.al) return 1;
      if (type == BidiClass.l) return 0;
    }
  }
  return 0;
}

BidiResult resolveBidi(String text, {String baseDirection = 'auto'}) {
  final types = [for (final rune in text.runes) bidiClass(rune)];
  final paragraph = baseDirection == 'rtl'
      ? 1
      : baseDirection == 'ltr'
          ? 0
          : computeParagraphLevel(types);
  final levels = <int>[];
  var current = paragraph;
  for (final type in types) {
    if (type == BidiClass.r || type == BidiClass.al) {
      levels.add(paragraph.isEven ? paragraph + 1 : paragraph);
    } else if (type == BidiClass.en || type == BidiClass.an) {
      levels.add(paragraph.isEven ? paragraph : paragraph + 1);
    } else {
      levels.add(current);
    }
  }
  return BidiResult(levels, types, paragraph);
}
