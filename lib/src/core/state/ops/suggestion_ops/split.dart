/// Suggestion split operations.
library;

import '../../attrs.dart';
import '../../block_compare.dart';
import '../../block_id.dart';
import '../../block_position.dart';
import '../../inline_content.dart';
import '../../state.dart';
import '../../suggestions.dart';

import 'insert.dart'; // for ReplaceSuggestionInput
import 'mark.dart';
import '../split_block.dart'; // needs planSplitBlockAtPosition, splitBlockAtPositionInTx, splitWithSuggestion

OperationResult splitWithSuggestionOverSelection(
    State state, Span span, IdAllocator allocator, ReplaceSuggestionInput input,
    [Map<String, dynamic>? newBlockInit,
    Map<String, AttrEqualsFn>? customEquals]) {
  final start = spanStart(state, span);
  final end = spanEnd(state, span);
  final blockB = start.blockId;

  final delPlan = planMarkDeletion(
      state,
      span,
      SuggestionMintInput(
        id: input.deletionId,
        author: input.author,
        createdAt: input.createdAt,
      ));

  if (delPlan == null) {
    return splitWithSuggestion(
        state,
        start,
        allocator,
        SuggestionMintInput(
          id: input.insertionId,
          author: input.author,
          createdAt: input.createdAt,
        ),
        newBlockInit);
  }

  final resolvedB = resolveBlock(state, blockB);
  if (resolvedB == null || resolvedB.block.inlineContent == null) {
    throw StateError(
        'splitWithSuggestionOverSelection: block "$blockB" not found or not a leaf');
  }

  final bWrite = delPlan.writes.where((w) => w.blockId == blockB).firstOrNull;
  final bItems =
      bWrite != null ? bWrite.items : resolvedB.block.inlineContent!.items;

  final preLen = inlineContentLength(resolvedB.block.inlineContent!);
  final tailLen = preLen - end.offset;
  final postLen = inlineContentLength(InlineContent(bItems));
  final splitOffset = postLen - tailLen;

  final splitPlan = planSplitBlockAtPosition(
    state,
    Position(blockId: blockB, offset: splitOffset),
    allocator,
    newType: newBlockInit?['type'] as String?,
    newAttrs: newBlockInit?['attrs'] as Map<String, dynamic>?,
  );

  final embed = EmbedItem(
    embedType: blockSplitSuggestionEmbedType,
    attrs: const {},
    properties: {'suggestionId': input.insertionId.value},
  );

  return applyOperation(state, (doc) {
    for (final w in delPlan.writes) {
      applyDeletionStrikeInTx(
        doc,
        w.blockId,
        delPlan.kind,
        w.rangeStart,
        w.rangeEnd,
        delPlan.id,
        input.author,
        customEquals,
        'splitWithSuggestionOverSelection',
      );
    }

    splitBlockAtPositionInTx(doc, splitPlan);

    final targetMap = splitPlan.kind == ResolvedBlockKind.embed
        ? doc.getEmbedContentMap(blockB.value)
        : (splitPlan.kind == ResolvedBlockKind.template
            ? doc.getTemplateContentMap(blockB.value)
            : doc.getBlockMap(blockB.value));

    if (targetMap != null) {
      final yItems = targetMap['inlineContent'];
      if (yItems is InlineContent) {
        final newItems = List<InlineItem>.from(yItems.items)..add(embed);
        targetMap['inlineContent'] = InlineContent(newItems);
        doc.markDirty(blockB.value);
      }
    }

    if (delPlan.taggedAny && !delPlan.reusing) {
      writeSuggestionRecordInTx(
          doc,
          SuggestionRecord(
            id: delPlan.id,
            kind: 'deletion',
            author: input.author,
            createdAt: input.createdAt,
          ));
    }

    writeSuggestionRecordInTx(
        doc,
        SuggestionRecord(
          id: input.insertionId,
          kind: 'insertion',
          author: input.author,
          createdAt: input.createdAt,
        ));
  });
}
