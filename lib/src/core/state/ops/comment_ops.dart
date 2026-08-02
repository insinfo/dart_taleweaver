/// Comment ops.
///
/// Port of `ops/comment-ops.ts`.
library;

import '../block_id.dart';
import '../block_compare.dart';
import '../block_position.dart';
import '../comments.dart';
import '../block_traversal.dart';
import '../inline_content.dart';
import '../state.dart';
import 'insert_comment_markers.dart';

class AddCommentInput {
  final CommentId id;
  final String author;
  final String body;
  final int createdAt;

  const AddCommentInput({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });
}

class AddReplyInput {
  final String replyId;
  final String author;
  final String body;
  final int createdAt;

  const AddReplyInput({
    required this.replyId,
    required this.author,
    required this.body,
    required this.createdAt,
  });
}

OperationResult addComment(
  State state,
  Span span,
  AddCommentInput input,
) {
  if (state.doc.comments.containsKey(input.id.value)) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final start = spanStart(state, span);
  final end = spanEnd(state, span);
  final writes = planCommentMarkers(state, start, end, input.id);

  final record = CommentRecord(
    id: input.id,
    author: input.author,
    body: input.body,
    createdAt: input.createdAt,
    replies: [],
    resolved: false,
  );

  return applyOperation(state, (doc) {
    applyCommentMarkerWritesInTx(doc, writes);
    writeCommentRecordInTx(doc, record);
  });
}

OperationResult resolveComment(State state, CommentId id) {
  return _setResolved(state, id, true);
}

OperationResult reopenComment(State state, CommentId id) {
  return _setResolved(state, id, false);
}

OperationResult _setResolved(State state, CommentId id, bool resolved) {
  final doc = state.doc;
  final yRecord = doc.comments[id.value];
  if (yRecord == null) return OperationResult(state: state, dirtyIds: {});
  if (yRecord['resolved'] == resolved)
    return OperationResult(state: state, dirtyIds: {});

  return applyOperation(state, (d) {
    final rec = d.comments[id.value];
    if (rec != null) {
      rec['resolved'] = resolved;
    }
    d.markDirty(state.rootId.value);
  });
}

OperationResult deleteComment(State state, CommentId id) {
  final doc = state.doc;
  final hasRecord = doc.comments.containsKey(id.value);
  final writes = _planMarkerStrip(state, id);

  if (!hasRecord && writes.isEmpty) {
    return OperationResult(state: state, dirtyIds: {});
  }

  return applyOperation(state, (d) {
    for (final write in writes) {
      final yBlock = write.kind == ResolvedBlockKind.embed
          ? d.getEmbedContentMap(write.blockId.value)
          : (write.kind == ResolvedBlockKind.template
              ? d.getTemplateContentMap(write.blockId.value)
              : d.getBlockMap(write.blockId.value));
      if (yBlock != null) {
        yBlock['inlineContent'] = InlineContent(write.items);
        d.markDirty(write.blockId.value);
      }
    }

    d.comments.remove(id.value);

    if (writes.isEmpty) {
      d.markDirty(state.rootId.value);
    }
  });
}

OperationResult addReply(
  State state,
  CommentId id,
  AddReplyInput input,
) {
  final doc = state.doc;
  if (!doc.comments.containsKey(id.value)) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final reply = CommentReply(
    id: input.replyId,
    author: input.author,
    body: input.body,
    createdAt: input.createdAt,
  );

  return applyOperation(state, (d) {
    final yRecord = d.comments[id.value];
    if (yRecord == null) return;

    final replies = yRecord['replies'] as List<dynamic>?;
    if (replies == null) return;

    replies.add(reply.toJson());

    d.markDirty(state.rootId.value);
  });
}

class _StripWrite {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const _StripWrite({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

List<_StripWrite> _planMarkerStrip(State state, CommentId id) {
  final writes = <_StripWrite>[];

  for (final block in iterateBlocksInDocumentOrder(state)) {
    final content = block.inlineContent;
    if (content == null) continue;

    final kept = <InlineItem>[];
    var removed = false;

    for (final item in content.items) {
      if (_isCommentMarkerFor(item, id)) {
        removed = true;
        continue;
      }
      kept.add(item);
    }

    if (!removed) continue;

    final resolved = resolveBlock(state, block.id);
    if (resolved == null) continue;

    writes.add(_StripWrite(
      blockId: block.id,
      kind: resolved.kind,
      items: mergeAdjacentTextItems(kept),
    ));
  }

  return writes;
}

bool _isCommentMarkerFor(InlineItem item, CommentId id) {
  if (item is EmbedItem) {
    return (item.embedType == commentStartEmbedType ||
            item.embedType == commentEndEmbedType) &&
        item.properties['commentId'] == id.value;
  }
  return false;
}
