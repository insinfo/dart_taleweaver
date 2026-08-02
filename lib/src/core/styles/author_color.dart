/// Author color for suggestions.
///
/// Port of `styles/author-color.ts`.
library;

import 'color.dart';

const _authorColorPalette = <Color>[
  '#1a73e8', // blue
  '#d93025', // red
  '#188038', // green
  '#9334e6', // purple
  '#e8710a', // orange
  '#1a8aa0', // teal
  '#c5221f', // crimson
  '#a142f4', // violet
];

/// Deterministically map an author string to a stable color.
Color authorColorOf(String author) {
  int hash = 5381;
  for (var i = 0; i < author.length; i++) {
    hash = (((hash << 5) + hash) + author.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  
  final index = hash % _authorColorPalette.length;
  return _authorColorPalette[index];
}
