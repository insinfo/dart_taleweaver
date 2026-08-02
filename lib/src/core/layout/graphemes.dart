library;

import '../cursor/grapheme_utils.dart';

List<String> graphemeClusters(String text) {
  final clusters = <String>[];
  var offset = 0;
  while (offset < text.length) {
    final end = nextGraphemeBoundary(text, offset);
    clusters.add(text.substring(offset, end));
    offset = end;
  }
  return clusters;
}
