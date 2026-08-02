library;

import '../styles/style.dart';

class TransformedRun {
  final String display;
  final List<int> sourceDisplayLengths;
  const TransformedRun(this.display, this.sourceDisplayLengths);
}

TransformedRun transformRun(String text, TextTransform mode) {
  if (mode == TextTransform.none) {
    return TransformedRun(text, List.filled(text.length, 1));
  }
  final lengths = <int>[];
  final output = StringBuffer();
  var atWordStart = true;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    String transformed;
    if (mode == TextTransform.uppercase) {
      transformed = char.toUpperCase();
    } else if (mode == TextTransform.lowercase) {
      transformed = char.toLowerCase();
    } else {
      final isSpace = char.trim().isEmpty;
      final isCased = char.toLowerCase() != char.toUpperCase();
      if (atWordStart && isCased) {
        transformed = char.toUpperCase();
        atWordStart = false;
      } else {
        transformed = char;
        if (isSpace) atWordStart = true;
      }
    }
    output.write(transformed);
    lengths.add(transformed.length);
  }
  return TransformedRun(output.toString(), lengths);
}
