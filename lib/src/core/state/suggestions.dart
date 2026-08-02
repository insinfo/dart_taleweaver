/// Suggestion models.
library;

import 'attrs.dart';
import 'inline_content.dart';
import 'state.dart';
import 'tw_doc.dart';

class SuggestionId {
  final String value;
  const SuggestionId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

const blockJoinSuggestionEmbedType = 'block-join-suggestion';
const blockSplitSuggestionEmbedType = 'block-split-suggestion';

const deletionSuggestionAttr = 'deletionSuggestionId';
const formattingSuggestionAttr = 'formattingSuggestionId';
const insertionSuggestionAttr = 'insertionSuggestionId';

const suggestionResolveOrigin = 'suggestion-resolve';

enum SuggestionView {
  suggesting,
  finalView,
  originalView,
}

bool itemVisibleInView(InlineItem item, SuggestionView view) {
  switch (view) {
    case SuggestionView.suggesting:
      return true;
    case SuggestionView.finalView:
      if (item is TextItem) {
        return item.attrs[deletionSuggestionAttr] is! String;
      } else if (item is EmbedItem) {
        return item.embedType != blockJoinSuggestionEmbedType;
      }
      return true;
    case SuggestionView.originalView:
      if (item is TextItem) {
        return item.attrs[insertionSuggestionAttr] is! String;
      } else if (item is EmbedItem) {
        return item.embedType != blockSplitSuggestionEmbedType;
      }
      return true;
  }
}

bool blockBoundaryMergesInView(List<InlineItem> items, SuggestionView view) {
  if (view == SuggestionView.suggesting) return false;
  if (items.isEmpty) return false;

  final last = items.last;
  if (last is EmbedItem) {
    if (last.embedType == blockJoinSuggestionEmbedType ||
        last.embedType == blockSplitSuggestionEmbedType) {
      return !itemVisibleInView(last, view);
    }
  }
  return false;
}

class SuggestionMintInput {
  final SuggestionId id;
  final String author;
  final int createdAt;

  const SuggestionMintInput({
    required this.id,
    required this.author,
    required this.createdAt,
  });
}

class SuggestionRecord {
  final SuggestionId id;
  final String kind;
  final String author;
  final int createdAt;
  final ReadonlyAttrs? proposedAttrs;

  const SuggestionRecord({
    required this.id,
    required this.kind,
    required this.author,
    required this.createdAt,
    this.proposedAttrs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id.value,
      'kind': kind,
      'author': author,
      'createdAt': createdAt,
      if (proposedAttrs != null) 'proposedAttrs': proposedAttrs,
    };
  }
}

void writeSuggestionRecordInTx(TwDoc doc, SuggestionRecord record) {
  doc.suggestions[record.id.value] = record.toJson();
}

SuggestionRecord? readSuggestionRecord(TwDoc doc, SuggestionId id) {
  final json = doc.suggestions[id.value];
  if (json == null) return null;
  return SuggestionRecord(
    id: SuggestionId(json['id']),
    kind: json['kind'],
    author: json['author'],
    createdAt: json['createdAt'],
    proposedAttrs: json['proposedAttrs'],
  );
}

List<SuggestionRecord> getSuggestions(State state) {
  final List<SuggestionRecord> out = [];
  for (final entry in state.doc.suggestions.entries) {
    out.add(SuggestionRecord(
      id: SuggestionId(entry.key),
      kind: entry.value['kind'],
      author: entry.value['author'],
      createdAt: entry.value['createdAt'],
      proposedAttrs: entry.value['proposedAttrs'] != null
          ? Map<String, dynamic>.from(entry.value['proposedAttrs'])
          : null,
    ));
  }
  return out;
}
