library;

import '../styles/style.dart';

const lineBreak = '\u2028';

List<String> tokenize(String text, WhiteSpace whiteSpace) {
  if (text.isEmpty) return const [];
  final mandatory = RegExp(r'\r\n|[\n\u000B\u000C\r\u0085\u2028\u2029]');
  switch (whiteSpace) {
    case WhiteSpace.normal:
    case WhiteSpace.nowrap:
      final trimmed = text.trim();
      if (trimmed.isEmpty) return List.filled(text.length, ' ');
      final leading = text.length - text.trimLeft().length;
      final trailing = text.length - text.trimRight().length;
      final result = <String>[...List.filled(leading, ' ')];
      final parts = trimmed.split(RegExp(r'\s+'));
      for (var i = 0; i < parts.length; i++) {
        result.add(parts[i]);
        if (i < parts.length - 1) result.add(' ');
      }
      result.addAll(List.filled(trailing, ' '));
      return result;
    case WhiteSpace.pre:
      return _splitLines(text, mandatory, preserveWhitespace: true);
    case WhiteSpace.preWrap:
    case WhiteSpace.breakSpaces:
      final result = <String>[];
      for (final line in _splitRawLines(text, mandatory)) {
        var word = '';
        for (final rune in line.runes) {
          final char = String.fromCharCode(rune);
          if (char.trim().isEmpty) {
            if (word.isNotEmpty) {
              result.add(word);
              word = '';
            }
            result.add(' ');
          } else {
            word += char;
          }
        }
        if (word.isNotEmpty) result.add(word);
        if (line != _splitRawLines(text, mandatory).last) result.add(lineBreak);
      }
      return result;
    case WhiteSpace.preLine:
      final result = <String>[];
      final lines = _splitRawLines(text, mandatory);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (i == 0) {
          result.addAll(List.filled(line.length - line.trimLeft().length, ' '));
        }
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          final parts = trimmed.split(RegExp(r'\s+'));
          for (var j = 0; j < parts.length; j++) {
            result.add(parts[j]);
            if (j < parts.length - 1) result.add(' ');
          }
        }
        if (i < lines.length - 1) result.add(lineBreak);
      }
      return result;
  }
}

List<String> _splitRawLines(String text, RegExp separator) =>
    text.split(separator);

List<String> _splitLines(String text, RegExp separator,
    {required bool preserveWhitespace}) {
  final lines = _splitRawLines(text, separator);
  final result = <String>[];
  for (var i = 0; i < lines.length; i++) {
    result.add(lines[i]);
    if (i < lines.length - 1) result.add(lineBreak);
  }
  return result;
}
