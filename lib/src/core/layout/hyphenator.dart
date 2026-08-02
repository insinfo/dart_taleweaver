library;

abstract interface class Hyphenator {
  List<int> hyphenate(String word, String language);
}

class MockHyphenator implements Hyphenator {
  final int every;
  final String? language;
  final int floor;

  const MockHyphenator({this.every = 3, this.language, this.floor = 1})
      : assert(every > 0),
        assert(floor >= 0);

  @override
  List<int> hyphenate(String word, String lang) {
    if (language != null && language != lang) return const [];
    if (word.length < floor) return const [];
    return [for (var i = every; i < word.length; i += every) i];
  }
}
