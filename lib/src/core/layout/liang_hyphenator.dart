/// Pure Knuth–Liang hyphenation matcher.
library;

import 'hyphenator.dart';

class PatternSet {
  final String patterns;
  final Map<String, String> exceptions;
  const PatternSet({required this.patterns, this.exceptions = const {}});
}

class _CompiledPatterns {
  final Map<String, List<int>> pointsByKey;
  final Map<String, List<int>> exceptions;
  const _CompiledPatterns(this.pointsByKey, this.exceptions);
}

({String key, List<int> points}) _parsePattern(String pattern) {
  final key = StringBuffer();
  final points = <int>[];
  var pending = 0;
  for (var i = 0; i < pattern.length; i++) {
    final code = pattern.codeUnitAt(i);
    if (code >= 48 && code <= 57) {
      pending = code - 48;
    } else {
      points.add(pending);
      pending = 0;
      key.writeCharCode(code);
    }
  }
  points.add(pending);
  return (key: key.toString(), points: points);
}

({String word, List<int> breaks}) _parseException(String spelling) {
  final word = StringBuffer();
  final breaks = <int>[];
  for (var i = 0; i < spelling.length; i++) {
    final ch = spelling[i];
    if (ch == '-') {
      breaks.add(word.length);
    } else {
      word.write(ch);
    }
  }
  return (word: word.toString(), breaks: breaks);
}

_CompiledPatterns _compile(PatternSet set) {
  final patterns = <String, List<int>>{};
  for (final pattern in set.patterns.split(RegExp(r'\s+'))) {
    if (pattern.isEmpty) continue;
    final parsed = _parsePattern(pattern);
    patterns[parsed.key] = parsed.points;
  }
  final exceptions = <String, List<int>>{};
  for (final spelling in set.exceptions.values) {
    final parsed = _parseException(spelling);
    exceptions[parsed.word.toLowerCase()] = parsed.breaks;
  }
  return _CompiledPatterns(patterns, exceptions);
}

List<int> hyphenateWord(String word, PatternSet set,
    {int leftMin = 2, int rightMin = 2}) {
  return _hyphenate(word, _compile(set), leftMin, rightMin);
}

List<int> _hyphenate(
    String word, _CompiledPatterns compiled, int leftMin, int rightMin) {
  final clean = StringBuffer();
  final originalIndex = <int>[];
  for (var i = 0; i < word.length; i++) {
    if (word.codeUnitAt(i) == 0xad) continue;
    clean.writeCharCode(word.codeUnitAt(i));
    originalIndex.add(i);
  }
  final lower = clean.toString().toLowerCase();
  if (lower.length < leftMin + rightMin) return const [];
  final exception = compiled.exceptions[lower];
  if (exception != null) {
    return exception
        .where((p) => p >= leftMin && lower.length - p >= rightMin)
        .map((p) => originalIndex[p])
        .toList(growable: false);
  }

  final framed = '.$lower.';
  final points = List<int>.filled(framed.length + 1, 0);
  for (var start = 0; start < framed.length; start++) {
    final key = StringBuffer();
    for (var end = start; end < framed.length; end++) {
      key.write(framed[end]);
      final pattern = compiled.pointsByKey[key.toString()];
      if (pattern == null) continue;
      for (var k = 0; k < pattern.length; k++) {
        final pos = start + k;
        if (pos < points.length && pattern[k] > points[pos]) {
          points[pos] = pattern[k];
        }
      }
    }
  }
  final result = <int>[];
  for (var p = 1; p < lower.length; p++) {
    if (p < leftMin || lower.length - p < rightMin) continue;
    if (points[p + 1].isOdd) result.add(originalIndex[p]);
  }
  return result;
}

class LiangHyphenator implements Hyphenator {
  final Map<String, _CompiledPatterns> _languages;
  final Map<String, List<int>> _memo = {};
  final int maxMemoEntries;

  LiangHyphenator(Map<String, PatternSet> languages,
      {this.maxMemoEntries = 2000})
      : _languages = {
          for (final entry in languages.entries)
            entry.key.toLowerCase(): _compile(entry.value)
        };

  @override
  List<int> hyphenate(String word, String language) {
    final lower = language.toLowerCase();
    final compiled = _languages[lower] ?? _languages[lower.split('-').first];
    if (compiled == null) return const [];
    final key = '${lower}\u0000$word';
    final cached = _memo[key];
    if (cached != null) return cached;
    final result = List<int>.unmodifiable(_hyphenate(word, compiled, 2, 2));
    if (_memo.length >= maxMemoEntries && _memo.isNotEmpty) {
      _memo.remove(_memo.keys.first);
    }
    _memo[key] = result;
    return result;
  }
}
