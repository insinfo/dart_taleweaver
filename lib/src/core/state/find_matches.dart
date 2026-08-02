/// Find matches (stub for replace_matches to compile).
///
/// Port of `find-matches.ts`.
library;

import 'block_id.dart';

class TextMatch {
  final BlockId blockId;
  final int start;
  final int end;
  final String text;
  const TextMatch(this.blockId, this.start, this.end, this.text);
}
