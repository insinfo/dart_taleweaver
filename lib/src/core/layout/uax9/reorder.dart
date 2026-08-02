library;

List<int> reorderRunsByLevel(List<int> levels) {
  final permutation = List<int>.generate(levels.length, (index) => index);
  if (levels.isEmpty) return permutation;
  final odd = levels.where((level) => level.isOdd).toList();
  if (odd.isEmpty) return permutation;
  final minimumOdd = odd.reduce((a, b) => a < b ? a : b);
  final maximum = levels.reduce((a, b) => a > b ? a : b);
  for (var level = maximum; level >= minimumOdd; level--) {
    var start = 0;
    while (start < levels.length) {
      while (start < levels.length && levels[start] < level) start++;
      var end = start;
      while (end < levels.length && levels[end] >= level) end++;
      for (var left = start, right = end - 1; left < right; left++, right--) {
        final value = permutation[left];
        permutation[left] = permutation[right];
        permutation[right] = value;
      }
      start = end;
    }
  }
  return permutation;
}

List<int> reorderVisual(List<int> levels) => reorderRunsByLevel(levels);
