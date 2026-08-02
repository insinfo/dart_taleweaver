/// UTF-16 offset helpers for grapheme-like and word boundaries.
library;

bool _isCombining(int rune) =>
    (rune >= 0x300 && rune <= 0x36f) ||
    (rune >= 0x1ab0 && rune <= 0x1aff) ||
    (rune >= 0x1dc0 && rune <= 0x1dff) ||
    (rune >= 0x20d0 && rune <= 0x20ff) ||
    (rune >= 0xfe20 && rune <= 0xfe2f);

bool _isVariation(int rune) =>
    (rune >= 0xfe00 && rune <= 0xfe0f) || (rune >= 0xe0100 && rune <= 0xe01ef);

bool _isModifier(int rune) => rune >= 0x1f3fb && rune <= 0x1f3ff;
bool _isRegional(int rune) => rune >= 0x1f1e6 && rune <= 0x1f1ff;
bool _isWordRune(int rune) =>
    (rune >= 0x30 && rune <= 0x39) ||
    (rune >= 0x41 && rune <= 0x5a) ||
    (rune >= 0x61 && rune <= 0x7a) ||
    rune == 0x5f ||
    (rune >= 0xc0 &&
        rune <= 0x2fff &&
        !_isWhitespace(rune) &&
        !_isPunctuation(rune));

bool _isWhitespace(int rune) => String.fromCharCode(rune).trim().isEmpty;
bool _isPunctuation(int rune) => const {
      0x2e,
      0x2c,
      0x21,
      0x3f,
      0x3b,
      0x3a,
      0x28,
      0x29,
      0x5b,
      0x5d,
      0x7b,
      0x7d,
      0x22,
      0x27,
      0x2d,
    }.contains(rune);

List<(int start, int end, bool word)> _segments(String text) {
  final codePoints = <(int offset, int rune)>[];
  var offset = 0;
  for (final rune in text.runes) {
    codePoints.add((offset, rune));
    offset += String.fromCharCode(rune).length;
  }
  final result = <(int, int, bool)>[];
  var i = 0;
  while (i < codePoints.length) {
    final start = codePoints[i].$1;
    final word = _isWordRune(codePoints[i].$2);
    var j = i + 1;
    while (j < codePoints.length && _isWordRune(codePoints[j].$2) == word) {
      j++;
    }
    final end = j < codePoints.length ? codePoints[j].$1 : text.length;
    result.add((start, end, word));
    i = j;
  }
  return result;
}

List<(int start, int end)> _graphemes(String text) {
  final points = <(int offset, int rune)>[];
  var offset = 0;
  for (final rune in text.runes) {
    points.add((offset, rune));
    offset += String.fromCharCode(rune).length;
  }
  final result = <(int, int)>[];
  for (var i = 0; i < points.length; i++) {
    final start = points[i].$1;
    var j = i + 1;
    var regionalCount = _isRegional(points[i].$2) ? 1 : 0;
    while (j < points.length) {
      final rune = points[j].$2;
      final previous = points[j - 1].$2;
      if (previous == 0x0d && rune == 0x0a) {
        j++;
        continue;
      }
      if (_isCombining(rune) || _isVariation(rune) || _isModifier(rune)) {
        j++;
        continue;
      }
      if (previous == 0x200d) {
        j++;
        continue;
      }
      if (_isRegional(rune) && regionalCount == 1) {
        regionalCount++;
        j++;
        continue;
      }
      break;
    }
    final end = j < points.length ? points[j].$1 : text.length;
    result.add((start, end));
    i = j - 1;
  }
  return result;
}

int nextGraphemeBoundary(String text, int offset) {
  if (offset >= text.length) return text.length;
  for (final segment in _graphemes(text)) {
    if (segment.$2 > offset) return segment.$2;
  }
  return text.length;
}

int prevGraphemeBoundary(String text, int offset) {
  if (offset <= 0) return 0;
  var previous = 0;
  for (final segment in _graphemes(text)) {
    if (segment.$1 >= offset) return previous;
    previous = segment.$1;
  }
  return previous;
}

int nextWordBoundary(String text, int offset) {
  if (offset >= text.length) return text.length;
  for (final segment in _segments(text)) {
    if (segment.$3 && segment.$2 > offset) return segment.$2;
  }
  return text.length;
}

int prevWordBoundary(String text, int offset) {
  if (offset <= 0) return 0;
  var lastWordStart = 0;
  var found = false;
  for (final segment in _segments(text)) {
    if (!segment.$3) continue;
    if (segment.$2 >= offset) {
      if (segment.$1 < offset && segment.$1 > 0) return segment.$1;
      if (segment.$1 >= offset) return found ? lastWordStart : 0;
    }
    lastWordStart = segment.$1;
    found = true;
  }
  return found ? lastWordStart : 0;
}

Iterable<({int start, int end, bool isWordLike})> iterateWordSegments(
  String text,
) sync* {
  for (final segment in _segments(text)) {
    yield (start: segment.$1, end: segment.$2, isWordLike: segment.$3);
  }
}
