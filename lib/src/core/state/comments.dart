/// Comment models.
library;

import 'state.dart';
import 'tw_doc.dart';

class CommentId {
  final String value;
  const CommentId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

const commentStartEmbedType = 'comment-start';
const commentEndEmbedType = 'comment-end';

class CommentReply {
  final String id;
  final String author;
  final String body;
  final int createdAt;

  const CommentReply({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'body': body,
        'createdAt': createdAt,
      };
}

class CommentRecord {
  final CommentId id;
  final String author;
  final String body;
  final int createdAt;
  final List<CommentReply> replies;
  final bool resolved;

  const CommentRecord({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    required this.replies,
    required this.resolved,
  });
}

void writeCommentRecordInTx(TwDoc doc, CommentRecord record) {
  doc.comments[record.id.value] = {
    'id': record.id.value,
    'author': record.author,
    'body': record.body,
    'createdAt': record.createdAt,
    'replies': [],
    'resolved': record.resolved,
  };
}

List<CommentRecord> getComments(State state) {
  final List<CommentRecord> out = [];
  for (final entry in state.doc.comments.entries) {
    out.add(CommentRecord(
      id: CommentId(entry.key),
      author: entry.value['author'],
      body: entry.value['body'],
      createdAt: entry.value['createdAt'],
      replies: (entry.value['replies'] as List)
          .map((r) => CommentReply(
                id: r['id'],
                author: r['author'],
                body: r['body'],
                createdAt: r['createdAt'],
              ))
          .toList(),
      resolved: entry.value['resolved'],
    ));
  }
  return out;
}
