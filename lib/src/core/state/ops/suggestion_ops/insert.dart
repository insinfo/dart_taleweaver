/// Suggestion insert operations.
library;

import '../../attrs.dart';
import '../../block_compare.dart';
import '../../block_position.dart';
import '../../state.dart';
import '../../suggestions.dart';

import '../insert_text.dart'; // need to import planInsertText, insertTextInTx etc
import 'mark.dart';
import 'utils.dart';

OperationResult mintInsertion(
  State state,
  Position position,
  String text,
  ReadonlyAttrs attrs,
  SuggestionMintInput input,
) {
  if (text.isEmpty) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final decision = resolveCoalesce(
    state,
    createSpan(position, position),
    input.id,
    insertionSuggestionAttr,
    (record) => record.kind == 'insertion' && record.author == input.author,
  );

  final insertAttrs = {...attrs, insertionSuggestionAttr: decision.id.value};
  final plan = planInsertText(state, position, text, insertAttrs);

  return applyOperation(state, (doc) {
    insertTextInTx(doc, plan);
    if (!decision.reusing) {
      writeSuggestionRecordInTx(
          doc,
          SuggestionRecord(
            id: decision.id,
            kind: 'insertion',
            author: input.author,
            createdAt: input.createdAt,
          ));
    }
  });
}

class ReplaceSuggestionInput {
  final SuggestionId deletionId;
  final SuggestionId insertionId;
  final String author;
  final int createdAt;

  const ReplaceSuggestionInput({
    required this.deletionId,
    required this.insertionId,
    required this.author,
    required this.createdAt,
  });
}

OperationResult replaceWithSuggestion(State state, Span span, String text,
    ReadonlyAttrs attrs, ReplaceSuggestionInput input,
    [Map<String, AttrEqualsFn>? customEquals]) {
  if (text.isEmpty) {
    return markDeletion(
        state,
        span,
        SuggestionMintInput(
          id: input.deletionId,
          author: input.author,
          createdAt: input.createdAt,
        ),
        customEquals);
  }

  if (span.anchor.blockId == span.focus.blockId &&
      span.anchor.offset == span.focus.offset) {
    return mintInsertion(
        state,
        span.anchor,
        text,
        attrs,
        SuggestionMintInput(
          id: input.insertionId,
          author: input.author,
          createdAt: input.createdAt,
        ));
  }

  final delPlan = planMarkDeletion(
      state,
      span,
      SuggestionMintInput(
        id: input.deletionId,
        author: input.author,
        createdAt: input.createdAt,
      ));

  final start = spanStart(state, span);
  if (delPlan == null) {
    return mintInsertion(
        state,
        start,
        text,
        attrs,
        SuggestionMintInput(
          id: input.insertionId,
          author: input.author,
          createdAt: input.createdAt,
        ));
  }

  final decisionIns = resolveCoalesce(
    state,
    createSpan(start, start),
    input.insertionId,
    insertionSuggestionAttr,
    (record) => record.kind == 'insertion' && record.author == input.author,
  );

  final insertAttrs = {...attrs, insertionSuggestionAttr: decisionIns.id.value};

  final startWrite =
      delPlan.writes.where((w) => w.blockId == start.blockId).firstOrNull;
  final insertPlan = startWrite != null
      ? planInsertTextFullReplace(
          start.blockId,
          delPlan.kind,
          startWrite.items,
          start.offset,
          text,
          insertAttrs,
          customEquals: customEquals,
        )
      : planInsertText(state, start, text, insertAttrs,
          customEquals: customEquals);

  return applyOperation(state, (d) {
    for (final write in delPlan.writes) {
      if (startWrite != null && write.blockId == start.blockId) continue;
      applyDeletionStrikeInTx(
        d,
        write.blockId,
        delPlan.kind,
        write.rangeStart,
        write.rangeEnd,
        delPlan.id,
        input.author,
        customEquals,
        'replaceWithSuggestion',
      );
    }

    if (startWrite != null) {
      applyDeletionStrikeInTx(
        d,
        startWrite.blockId,
        delPlan.kind,
        startWrite.rangeStart,
        startWrite.rangeEnd,
        delPlan.id,
        input.author,
        customEquals,
        'replaceWithSuggestion',
      );
    }

    insertTextInTx(d, insertPlan);

    if (delPlan.taggedAny && !delPlan.reusing) {
      writeSuggestionRecordInTx(
          d,
          SuggestionRecord(
            id: delPlan.id,
            kind: 'deletion',
            author: input.author,
            createdAt: input.createdAt,
          ));
    }

    if (!decisionIns.reusing) {
      writeSuggestionRecordInTx(
          d,
          SuggestionRecord(
            id: decisionIns.id,
            kind: 'insertion',
            author: input.author,
            createdAt: input.createdAt,
          ));
    }
  });
}
