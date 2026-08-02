/// Insert comment markers.
///
/// Port of `ops/insert-comment-markers.ts`.
library;

import '../block_compare.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../comments.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

class LeafWrite {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const LeafWrite({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

OperationResult insertCommentMarkers(
  State state,
  Span span,
  CommentId commentId,
) {
  final start = spanStart(state, span);
  final end = spanEnd(state, span);
  final writes = planCommentMarkers(state, start, end, commentId);

  return applyOperation(state, (doc) {
    applyCommentMarkerWritesInTx(doc, writes);
  });
}

List<LeafWrite> planCommentMarkers(
  State state,
  Position start,
  Position end,
  CommentId commentId,
) {
  final startMarker = _makeMarker(commentStartEmbedType, commentId);
  final endMarker = _makeMarker(commentEndEmbedType, commentId);

  if (start.blockId == end.blockId) {
    final leaf = _resolveLeaf(state, start.blockId);
    _requireInRange(leaf.$1, start.offset, start.blockId);
    _requireInRange(leaf.$1, end.offset, end.blockId);

    final afterEnd = _spliceMarker(leaf.$1, end.offset, endMarker);
    final afterStart =
        _spliceMarker(InlineContent(afterEnd), start.offset, startMarker);

    return [
      LeafWrite(blockId: start.blockId, kind: leaf.$2, items: afterStart),
    ];
  }

  final startLeaf = _resolveLeaf(state, start.blockId);
  _requireInRange(startLeaf.$1, start.offset, start.blockId);

  final endLeaf = _resolveLeaf(state, end.blockId);
  _requireInRange(endLeaf.$1, end.offset, end.blockId);

  return [
    LeafWrite(
      blockId: end.blockId,
      kind: endLeaf.$2,
      items: _spliceMarker(endLeaf.$1, end.offset, endMarker),
    ),
    LeafWrite(
      blockId: start.blockId,
      kind: startLeaf.$2,
      items: _spliceMarker(startLeaf.$1, start.offset, startMarker),
    ),
  ];
}

EmbedItem _makeMarker(String embedType, CommentId commentId) {
  return EmbedItem(
    embedType: embedType,
    attrs: const {},
    properties: {'commentId': commentId.value},
  );
}

(InlineContent, ResolvedBlockKind) _resolveLeaf(State state, BlockId blockId) {
  final resolved = resolveBlock(state, blockId);
  if (resolved == null) {
    throw StateError('insertCommentMarkers: block "$blockId" not found');
  }
  if (resolved.block.inlineContent == null) {
    throw StateError('insertCommentMarkers: block "$blockId" is not a leaf');
  }
  return (resolved.block.inlineContent!, resolved.kind);
}

void _requireInRange(InlineContent content, int offset, BlockId blockId) {
  final totalLen = inlineContentLength(content);
  if (offset < 0 || offset > totalLen) {
    throw RangeError('insertCommentMarkers: offset out of range');
  }
}

List<InlineItem> _spliceMarker(
    InlineContent content, int offset, EmbedItem marker) {
  final split = splitInlineContentAtOffset(content, offset);
  return mergeAdjacentTextItems([...split.$1, marker, ...split.$2]);
}

void applyCommentMarkerWritesInTx(TwDoc doc, List<LeafWrite> writes) {
  for (final write in writes) {
    final yBlock = write.kind == ResolvedBlockKind.embed
        ? doc.getEmbedContentMap(write.blockId.value)
        : (write.kind == ResolvedBlockKind.template
            ? doc.getTemplateContentMap(write.blockId.value)
            : doc.getBlockMap(write.blockId.value));

    if (yBlock != null) {
      yBlock['inlineContent'] = InlineContent(write.items);
      doc.markDirty(write.blockId.value);
    }
  }
}
