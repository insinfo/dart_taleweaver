/// Counter formatting utilities.
///
/// Port of `styles/format-counter.ts`.
library;

const Set<String> _counterStyles = {
  'decimal',
  'lower-alpha',
  'upper-alpha',
  'lower-roman',
  'upper-roman',
  'disc',
  'circle',
  'square',
};

/// Runtime type guard for CounterStyle.
bool isCounterStyle(dynamic value) {
  return value is String && _counterStyles.contains(value);
}

/// Format `value` under `style`, BARE (no suffix).
String formatCounter(int value, String style) {
  switch (style) {
    case 'decimal':
      return '$value';
    case 'lower-alpha':
      return _toAlpha(value, 0x61 /* 'a' */);
    case 'upper-alpha':
      return _toAlpha(value, 0x41 /* 'A' */);
    case 'lower-roman':
      return _toRoman(value).toLowerCase();
    case 'upper-roman':
      return _toRoman(value);
    case 'disc':
      return '•';
    case 'circle':
      return '○';
    case 'square':
      return '▪';
    default:
      throw StateError('Invalid counter style: $style');
  }
}

String _toAlpha(int n, int baseCharCode) {
  var s = '';
  var cur = n;
  while (cur > 0) {
    cur -= 1;
    s = String.fromCharCode(baseCharCode + (cur % 26)) + s;
    cur = (cur / 26).floor();
  }
  return s;
}

const _romanPairs = [
  [1000, 'M'],
  [900, 'CM'],
  [500, 'D'],
  [400, 'CD'],
  [100, 'C'],
  [90, 'XC'],
  [50, 'L'],
  [40, 'XL'],
  [10, 'X'],
  [9, 'IX'],
  [5, 'V'],
  [4, 'IV'],
  [1, 'I'],
];

String _toRoman(int n) {
  var s = '';
  var cur = n;
  for (final pair in _romanPairs) {
    final v = pair[0] as int;
    final lit = pair[1] as String;
    while (cur >= v) {
      s += lit;
      cur -= v;
    }
  }
  return s;
}
