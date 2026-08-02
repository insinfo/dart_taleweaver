/// Document outline logic.
///
/// Port of `state/outline.ts`.
library;

import 'block_id.dart';
import 'block_position.dart';
import 'block_traversal.dart';
import 'extract_text.dart';
import 'inline_content.dart';
import 'state.dart';
import 'suggestions.dart';

class OutlineEntry {
  final BlockId blockId;
  final int level;
  final String text;

  const OutlineEntry({
    required this.blockId,
    required this.level,
    required this.text,
  });
}

class OutlineOptions {
  final Iterable<BlockId>? blockIds;
  final SuggestionView suggestionView;

  const OutlineOptions({
    this.blockIds,
    this.suggestionView = SuggestionView.suggesting,
  });
}

List<OutlineEntry> getOutline(State state, [OutlineOptions? options]) {
  final entries = <OutlineEntry>[];
  final view = options?.suggestionView ?? SuggestionView.suggesting;

  for (final blockId in _iterateTargetBlocks(state, options?.blockIds)) {
    final block = getBlock(state, blockId);
    if (block == null || block.inlineContent == null) continue;
    if (block.type != 'heading') continue;

    final length = inlineContentLength(block.inlineContent!);
    final text = length == 0
        ? ''
        : extractText(
            state,
            createSpan(createPosition(blockId, 0), createPosition(blockId, length)),
            captionEmbedSerializer,
            view,
          );

    entries.add(OutlineEntry(
      blockId: blockId,
      level: _levelOf(block.attrs['level']),
      text: text,
    ));
  }

  return entries;
}

class OutlineSigEntry {
  final BlockId blockId;
  final int level;
  final String text;

  const OutlineSigEntry({
    required this.blockId,
    required this.level,
    required this.text,
  });
}

class OutlineSignature {
  final Set<BlockId> tocAnchorIds;
  final List<OutlineSigEntry> signature;

  const OutlineSignature({
    required this.tocAnchorIds,
    required this.signature,
  });
}

const emptyOutlineSignature = OutlineSignature(
  tocAnchorIds: {},
  signature: [],
);

OutlineSignature computeOutlineSignature(
  State state,
  SuggestionView suggestionView,
) {
  final entries = getOutline(state, OutlineOptions(suggestionView: suggestionView));
  final signature = entries
      .map((e) => OutlineSigEntry(
            blockId: e.blockId,
            level: e.level,
            text: e.text,
          ))
      .toList(growable: false);

  final tocAnchorIds = <BlockId>{};
  for (final block in iterateLeafBlocksInDocumentOrder(state)) {
    if (block.type == 'table-of-contents') tocAnchorIds.add(block.id);
  }

  return OutlineSignature(
    tocAnchorIds: tocAnchorIds,
    signature: signature,
  );
}

bool outlineSignaturesEqual(OutlineSignature a, OutlineSignature b) {
  if (identical(a, b)) return true;
  if (a.signature.length != b.signature.length) return false;
  for (int i = 0; i < a.signature.length; i++) {
    final x = a.signature[i];
    final y = b.signature[i];
    if (x.blockId != y.blockId || x.level != y.level || x.text != y.text) {
      return false;
    }
  }
  return true;
}

int _levelOf(dynamic level) {
  if (level is int && level >= 1 && level <= 6) {
    return level;
  }
  return 1;
}

Iterable<BlockId> _iterateTargetBlocks(
  State state,
  Iterable<BlockId>? blockIds,
) sync* {
  if (blockIds != null) {
    yield* blockIds;
    return;
  }
  for (final block in iterateLeafBlocksInDocumentOrder(state)) {
    yield block.id;
  }
}
