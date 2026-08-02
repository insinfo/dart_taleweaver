/// Suggestion fragment operations.
library;


import '../../block_compare.dart';
import '../../block_id.dart';
import '../../block_position.dart';
import '../../inline_content.dart';
import '../../state.dart';
import '../../suggestions.dart';
import '../../tw_doc.dart';

import 'insert.dart';
import '../insert_blocks_after.dart'; // for SiblingBlockInit
import '../insert_new_blocks.dart';
import '../insert_items.dart';
import 'mark.dart';
import 'utils.dart';

class ReplaceFragmentPlan {
  final List<ResolveWrite> writes;
  final List<NewBlockSpec> newBlocks;
  final List<SuggestionRecord> records;
  final Position endPosition;
  final InsertItemsPlan? bInsertPlan;
  final int fragmentLength;

  const ReplaceFragmentPlan({
    required this.writes,
    required this.newBlocks,
    required this.records,
    required this.endPosition,
    this.bInsertPlan,
    required this.fragmentLength,
  });
}

List<InlineItem> _tagInsertionRuns(List<InlineItem> items, SuggestionId insId) {
  return items.map((it) {
    if (it is TextItem) {
      return TextItem(text: it.text, attrs: {...it.attrs, insertionSuggestionAttr: insId.value});
    }
    return it;
  }).toList();
}

EmbedItem _buildSplitSuggestionEmbed(SuggestionId insId) {
  return EmbedItem(
    embedType: blockSplitSuggestionEmbedType,
    attrs: const {},
    properties: {'suggestionId': insId.value},
  );
}

EmbedItem _buildJoinSuggestionEmbed(SuggestionId delId) {
  return EmbedItem(
    embedType: blockJoinSuggestionEmbedType,
    attrs: const {},
    properties: {'suggestionId': delId.value},
  );
}

List<InlineItem> _fragmentLineItems(SiblingBlockInit line, SuggestionId insId) {
  final items = line.inlineContent?.items ?? [];
  return _tagInsertionRuns(List<InlineItem>.from(items), insId);
}

int _fragmentLineLength(SiblingBlockInit line) {
  return inlineContentLength(line.inlineContent ?? const InlineContent([]));
}

ReplaceFragmentPlan planReplaceWithSuggestedFragment(
  State state,
  Span span,
  List<SiblingBlockInit> fragment,
  ReplaceSuggestionInput input,
  IdAllocator allocator,
  [Map<String, dynamic>? customEquals]
) {
  final at = spanStart(state, span);
  final resolved = resolveBlock(state, at.blockId);
  if (resolved == null || resolved.block.inlineContent == null) {
    throw StateError('planReplaceWithSuggestedFragment: block "${at.blockId}" not found or not a leaf');
  }
  
  final kind = resolved.kind;
  final c = at.offset;
  final n = fragment.length;

  final delPlan = planMarkDeletion(state, span, SuggestionMintInput(
    id: input.deletionId,
    author: input.author,
    createdAt: input.createdAt,
  ));

  List<InlineItem> prefix;
  List<InlineItem> tailBundle;
  List<InlineItem> bStrikeItems;
  final extraWrites = <ResolveWrite>[];
  SuggestionRecord? delRecord;
  SuggestionId? bDeletionId;
  var bRangeStart = 0;
  var bRangeEnd = 0;
  var bAppendJoinEmbed = false;

  if (delPlan == null) {
    final split = splitInlineContentAtOffset(resolved.block.inlineContent!, c);
    prefix = split.$1.toList();
    tailBundle = split.$2.toList();
    bStrikeItems = resolved.block.inlineContent!.items.toList();
  } else {
    final end = spanEnd(state, span);
    final startBlockId = at.blockId;
    final endBlockId = end.blockId;
    final crossBlock = startBlockId != endBlockId;
    
    final bWrite = delPlan.writes.where((w) => w.blockId == startBlockId).firstOrNull;
    if (bWrite != null) {
      bRangeStart = bWrite.rangeStart;
      bRangeEnd = bWrite.rangeEnd;
    }
    bAppendJoinEmbed = crossBlock;
    bDeletionId = bWrite != null || crossBlock ? delPlan.id : null;
    
    final bItems = bWrite != null ? bWrite.items : resolved.block.inlineContent!.items.toList();
    bStrikeItems = bItems;
    
    final split = splitInlineContentAtOffset(InlineContent(bItems), c);
    prefix = split.$1.toList();
    final afterPrefix = split.$2.toList();
    
    tailBundle = crossBlock
        ? [...afterPrefix, _buildJoinSuggestionEmbed(delPlan.id)]
        : afterPrefix;
        
    for (final w in delPlan.writes) {
      if (w.blockId == startBlockId) continue;
      final appendJoinEmbed = w.blockId != endBlockId;
      final items = appendJoinEmbed
          ? mergeAdjacentTextItems([...w.items, _buildJoinSuggestionEmbed(delPlan.id)])
          : w.items;
          
      extraWrites.add(ResolveWrite(
        blockId: w.blockId,
        kind: delPlan.kind,
        items: items,
        rangeStart: w.rangeStart,
        rangeEnd: w.rangeEnd,
        deletionId: delPlan.id,
        appendJoinEmbed: appendJoinEmbed,
      ));
    }
    
    if (delPlan.taggedAny && !delPlan.reusing) {
      delRecord = SuggestionRecord(
        id: delPlan.id,
        kind: 'deletion',
        author: input.author,
        createdAt: input.createdAt,
      );
    }
  }

  ResolveWrite bWriteEntry(List<InlineItem> items) => ResolveWrite(
    blockId: at.blockId,
    kind: kind,
    items: items,
    rangeStart: bRangeStart,
    rangeEnd: bRangeEnd,
    deletionId: bDeletionId,
    appendJoinEmbed: bAppendJoinEmbed,
  );

  if (n == 0) {
    final bItems = mergeAdjacentTextItems([...prefix, ...tailBundle]);
    return ReplaceFragmentPlan(
      writes: [bWriteEntry(bItems), ...extraWrites],
      newBlocks: const [],
      records: delRecord == null ? [] : [delRecord],
      endPosition: at,
      bInsertPlan: null,
      fragmentLength: n,
    );
  }

  SuggestionId insId;
  SuggestionRecord? insRecord;
  
  if (n == 1) {
    final decision = resolveCoalesce(
      state,
      createSpan(at, at),
      input.insertionId,
      insertionSuggestionAttr,
      (rec) => rec.kind == 'insertion' && rec.author == input.author,
    );
    insId = decision.id;
    insRecord = decision.reusing
        ? null
        : SuggestionRecord(id: insId, kind: 'insertion', author: input.author, createdAt: input.createdAt);
  } else {
    insId = input.insertionId;
    insRecord = SuggestionRecord(id: insId, kind: 'insertion', author: input.author, createdAt: input.createdAt);
  }
  
  final records = <SuggestionRecord>[];
  if (insRecord != null) records.add(insRecord);
  if (delRecord != null) records.add(delRecord);

  if (n == 1) {
    final line0 = fragment[0];
    final bInsertPlan = planInsertItemsSplitInPlace(
      at.blockId,
      kind,
      bStrikeItems,
      c,
      _fragmentLineItems(line0, insId),
      customEquals,
    );
    
    final bItems = mergeAdjacentTextItems([
      ...prefix,
      ..._fragmentLineItems(line0, insId),
      ...tailBundle,
    ]);
    
    return ReplaceFragmentPlan(
      writes: [bWriteEntry(bItems), ...extraWrites],
      newBlocks: const [],
      records: records,
      endPosition: Position(blockId: at.blockId, offset: c + _fragmentLineLength(line0)),
      bInsertPlan: bInsertPlan,
      fragmentLength: n,
    );
  }

  final parentId = resolved.block.parentId;
  if (parentId == null) {
    throw StateError('planReplaceWithSuggestedFragment: block "${at.blockId}" is a root');
  }
  
  final oldNext = resolved.block.nextSiblingId;
  final line0 = fragment[0];
  final nbIds = <BlockId>[];
  for (var i = 1; i < n; i++) nbIds.add(allocator.allocate());

  final bInsertPlan = planReplaceBlockTailInPlace(
    at.blockId,
    kind,
    resolved.block.inlineContent!.items.toList(),
    c,
    [..._fragmentLineItems(line0, insId), _buildSplitSuggestionEmbed(insId)],
    customEquals,
  );

  final bItems = mergeAdjacentTextItems([
    ...prefix,
    ..._fragmentLineItems(line0, insId),
    _buildSplitSuggestionEmbed(insId),
  ]);

  final newBlocks = <NewBlockSpec>[];
  for (var i = 1; i < n; i++) {
    final isLast = i == n - 1;
    final fragLine = fragment[i];
    final nbId = nbIds[i - 1];
    final prevSiblingId = i == 1 ? at.blockId : nbIds[i - 2];
    final nextSiblingId = isLast ? oldNext : nbIds[i];
    
    final lineItems = _fragmentLineItems(fragLine, insId);
    final blockItems = mergeAdjacentTextItems(
      isLast ? [...lineItems, ...tailBundle] : [...lineItems, _buildSplitSuggestionEmbed(insId)],
    );
    
    newBlocks.add(NewBlockSpec(
      id: nbId,
      kind: kind,
      type: fragLine.type,
      attrs: fragLine.attrs,
      items: blockItems,
      parentId: parentId,
      prevSiblingId: prevSiblingId,
      nextSiblingId: nextSiblingId,
    ));
  }

  final lastNbId = nbIds[n - 2];
  final lastFragLine = fragment[n - 1];
  
  return ReplaceFragmentPlan(
    writes: [bWriteEntry(bItems), ...extraWrites],
    newBlocks: newBlocks,
    records: records,
    endPosition: Position(blockId: lastNbId, offset: _fragmentLineLength(lastFragLine)),
    bInsertPlan: bInsertPlan,
    fragmentLength: n,
  );
}

class ReplaceFragmentResult {
  final OperationResult result;
  final Position endPosition;
  const ReplaceFragmentResult(this.result, this.endPosition);
}

ReplaceFragmentResult replaceWithSuggestedFragment(
  State state,
  Span span,
  List<SiblingBlockInit> fragment,
  ReplaceSuggestionInput input,
  IdAllocator allocator,
  [Map<String, dynamic>? customEquals]
) {
  final plan = planReplaceWithSuggestedFragment(state, span, fragment, input, allocator, customEquals);
  
  final result = applyOperation(state, (doc) {
    final firstWrite = plan.writes[0];
    final startBlockId = firstWrite.blockId;
    
    for (final w in plan.writes) {
      final isStart = w.blockId == startBlockId;
      if (isStart && plan.fragmentLength > 1) {
        insertItemsInTx(doc, plan.bInsertPlan!);
        continue;
      }
      
      final insertPlan = isStart ? plan.bInsertPlan : null;
      _applySurgicalFragmentWrite(doc, w, input.author, customEquals, insertPlan);
    }
    
    if (plan.newBlocks.isNotEmpty) {
      final firstNew = plan.newBlocks.first;
      final lastNew = plan.newBlocks.last;
      final kind = firstWrite.kind;
      
      final targetMap = kind == ResolvedBlockKind.embed
          ? doc.getEmbedContentMap(startBlockId.value)
          : (kind == ResolvedBlockKind.template
              ? doc.getTemplateContentMap(startBlockId.value)
              : doc.getBlockMap(startBlockId.value));
      if (targetMap != null) {
        targetMap['nextSiblingId'] = firstNew.id.value;
      }
      
      if (lastNew.nextSiblingId != null) {
        final nextMap = kind == ResolvedBlockKind.embed
            ? doc.getEmbedContentMap(lastNew.nextSiblingId!.value)
            : (kind == ResolvedBlockKind.template
                ? doc.getTemplateContentMap(lastNew.nextSiblingId!.value)
                : doc.getBlockMap(lastNew.nextSiblingId!.value));
        if (nextMap != null) {
          nextMap['prevSiblingId'] = lastNew.id.value;
        }
      } else {
        final parentMap = kind == ResolvedBlockKind.embed
            ? doc.getEmbedContentMap(firstNew.parentId.value)
            : (kind == ResolvedBlockKind.template
                ? doc.getTemplateContentMap(firstNew.parentId.value)
                : doc.getBlockMap(firstNew.parentId.value));
        if (parentMap != null) {
          parentMap['lastChildId'] = lastNew.id.value;
        }
      }
      
      insertNewBlocksInTx(doc, plan.newBlocks);
    }
    
    for (final rec in plan.records) {
      writeSuggestionRecordInTx(doc, rec);
    }
  });
  
  return ReplaceFragmentResult(result, plan.endPosition);
}

void _applySurgicalFragmentWrite(
  TwDoc doc,
  ResolveWrite w,
  String author,
  Map<String, dynamic>? customEquals,
  InsertItemsPlan? insertPlan,
) {
  if (w.deletionId != null && w.rangeStart < w.rangeEnd) {
    applyDeletionStrikeInTx(
      doc,
      w.blockId,
      w.kind,
      w.rangeStart,
      w.rangeEnd,
      w.deletionId!,
      author,
      customEquals,
      'replaceWithSuggestedFragment',
    );
  }
  
  if (insertPlan != null) {
    insertItemsInTx(doc, insertPlan);
  }
  
  if (w.appendJoinEmbed) {
    if (w.deletionId == null) {
      throw StateError('applySurgicalFragmentWrite: appendJoinEmbed requires a deletionId');
    }
    
    final targetMap = w.kind == ResolvedBlockKind.embed
        ? doc.getEmbedContentMap(w.blockId.value)
        : (w.kind == ResolvedBlockKind.template
            ? doc.getTemplateContentMap(w.blockId.value)
            : doc.getBlockMap(w.blockId.value));
            
    if (targetMap != null) {
      final content = targetMap['inlineContent'];
      if (content is InlineContent) {
        final newItems = List<InlineItem>.from(content.items)..add(_buildJoinSuggestionEmbed(w.deletionId!));
        targetMap['inlineContent'] = InlineContent(newItems);
      }
    }
  }
}

ReplaceFragmentResult insertFragmentAsSuggestion(
  State state,
  Position at,
  List<SiblingBlockInit> fragment,
  SuggestionMintInput input,
  IdAllocator allocator,
  [Map<String, dynamic>? customEquals]
) {
  return replaceWithSuggestedFragment(
    state,
    createSpan(at, at),
    fragment,
    ReplaceSuggestionInput(
      deletionId: input.id,
      insertionId: input.id,
      author: input.author,
      createdAt: input.createdAt,
    ),
    allocator,
    customEquals,
  );
}
