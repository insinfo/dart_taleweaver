/// Find visible-text matches with UTF-16 positions.
///
/// Port of `find-matches.ts`. Matching is performed on a folded view while
/// retaining source start/end offsets, so Unicode case folds cannot corrupt
/// replacement ranges.
library;

import 'block_id.dart';
import 'block_traversal.dart';
import 'extract_text.dart';
import 'inline_content.dart';
import 'state.dart';

class TextMatch {
  final BlockId blockId;
  final int start;
  final int end;
  final String text;
  const TextMatch(this.blockId, this.start, this.end, this.text);
}

class FindMatchesOptions {
  final bool caseSensitive;
  final bool wholeWord;
  final Iterable<BlockId>? blockIds;

  const FindMatchesOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
    this.blockIds,
  });
}

/// Find non-overlapping visible-text matches and return Position offsets.
List<TextMatch> findMatches(State state, String query,
    [FindMatchesOptions options = const FindMatchesOptions()]) {
  if (query.isEmpty) return const [];
  final needle = options.caseSensitive ? query : query.toLowerCase();
  final ids = options.blockIds ??
      iterateLeafBlocksInDocumentOrder(state).map((block) => block.id);
  final result = <TextMatch>[];
  for (final id in ids) {
    final block = getBlock(state, id);
    final content = block?.inlineContent;
    if (content == null) continue;
    final chars = StringBuffer();
    final offsets = <int>[];
    var position = 0;
    for (final item in content.items) {
      if (item is TextItem) {
        for (var i = 0; i < item.text.length; i++) {
          chars.write(item.text[i]);
          offsets.add(position++);
        }
      } else if (item is EmbedItem) {
        final serialized = builtinEmbedSerializer(item);
        for (var i = 0; i < serialized.length; i++) {
          chars.write(serialized[i]);
          offsets.add(position);
        }
        position++;
      }
    }
    final original = chars.toString();
    final folded = options.caseSensitive
        ? _Folded(original, offsets,
            [for (var i = 0; i < offsets.length; i++) offsets[i] + 1])
        : _fold(original, offsets);
    final haystack = folded.text;
    var from = 0;
    while (from <= haystack.length - needle.length) {
      final index = haystack.indexOf(needle, from);
      if (index < 0) break;
      final end = index + needle.length;
      final before = index == 0 ? null : haystack[index - 1];
      final after = end >= haystack.length ? null : haystack[end];
      final whole = !options.wholeWord || (!_isWord(before) && !_isWord(after));
      if (whole &&
          index < folded.starts.length &&
          end > 0 &&
          end - 1 < folded.ends.length) {
        final startOffset = folded.starts[index];
        final endOffset = folded.ends[end - 1];
        result.add(TextMatch(id, startOffset, endOffset,
            original.substring(startOffset, endOffset)));
      }
      from = index + needle.length;
    }
  }
  return result;
}

bool _isWord(String? value) =>
    value != null && RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(value);

class _Folded {
  final String text;
  final List<int> starts;
  final List<int> ends;

  const _Folded(this.text, this.starts, this.ends);
}

_Folded _fold(String original, List<int> sourceOffsets) {
  final text = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var sourceIndex = 0;
  for (final rune in original.runes) {
    final sourceStart = sourceIndex < sourceOffsets.length
        ? sourceOffsets[sourceIndex]
        : sourceIndex;
    final sourceLength = String.fromCharCode(rune).length;
    final sourceEnd = sourceIndex + sourceLength <= sourceOffsets.length
        ? sourceOffsets[sourceIndex + sourceLength - 1] + 1
        : sourceStart + sourceLength;
    final folded = String.fromCharCode(rune).toLowerCase();
    text.write(folded);
    starts.addAll(List<int>.filled(folded.length, sourceStart));
    ends.addAll(List<int>.filled(folded.length, sourceEnd));
    sourceIndex += sourceLength;
  }
  return _Folded(text.toString(), starts, ends);
}
