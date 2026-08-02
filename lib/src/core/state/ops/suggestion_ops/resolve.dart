/// Suggestion resolve operations.
library;


import '../../attrs.dart';
import '../../block_id.dart';
import '../../block_traversal.dart'; // fallback if doc order not there // need iterateBlocksInDocumentOrder
import '../../inline_content.dart';
import '../../state.dart';
import '../../suggestions.dart';
import '../../tw_doc.dart';

import 'mark.dart' show mergeAdjacentSameAttrsTextItems;
import '../../block_schema.dart';
import 'utils.dart'; // for suggestionIdsOnItem

enum ResolveAction { strip, drop, applyStrip }

abstract class ScanItemResult {
  const ScanItemResult();
}

class ScanKeep extends ScanItemResult {
  const ScanKeep();
}

class ScanRewrite extends ScanItemResult {
  final ReadonlyAttrs attrs;
  const ScanRewrite(this.attrs);
}

class ScanDrop extends ScanItemResult {
  const ScanDrop();
}

class ScanBreakDrop extends ScanItemResult {
  final bool merge;
  const ScanBreakDrop(this.merge);
}

class ResolveDecisionWrite {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<ScanItemResult> decisions;

  const ResolveDecisionWrite({
    required this.blockId,
    required this.kind,
    required this.decisions,
  });
}

bool _isBreakEmbed(InlineItem item) {
  if (item is! EmbedItem) return false;
  return item.embedType == blockSplitSuggestionEmbedType ||
         item.embedType == blockJoinSuggestionEmbedType;
}

void applyResolveDecisionsInTx(
  TwDoc doc,
  BlockId blockId,
  ResolvedBlockKind kind,
  List<ScanItemResult> decisions,
  Map<String, AttrEqualsFn>? customEquals,
) {
  final targetMap = kind == ResolvedBlockKind.embed
      ? doc.getEmbedContentMap(blockId.value)
      : (kind == ResolvedBlockKind.template
          ? doc.getTemplateContentMap(blockId.value)
          : doc.getBlockMap(blockId.value));
  if (targetMap == null) return;
  final content = targetMap['inlineContent'];
  if (content is! InlineContent) return;
  
  final yItems = List<InlineItem>.from(content.items);
  var liveIndex = 0;
  
  for (final d in decisions) {
    if (d is ScanKeep) {
      liveIndex++;
    } else if (d is ScanRewrite) {
      final item = yItems[liveIndex];
      if (item is TextItem) {
        yItems[liveIndex] = TextItem(text: item.text, attrs: d.attrs);
      } else if (item is EmbedItem) {
        yItems[liveIndex] = EmbedItem(
          embedType: item.embedType,
          attrs: d.attrs,
          properties: item.properties,
        );
      }
      liveIndex++;
    } else if (d is ScanDrop || d is ScanBreakDrop) {
      yItems.removeAt(liveIndex);
    }
  }
  
  targetMap['inlineContent'] = InlineContent(mergeAdjacentSameAttrsTextItems(yItems, customEquals));
  doc.markDirty(blockId.value);
}

class _BlockScanResult {
  final List<ResolveDecisionWrite> writes;
  final List<_MergeOwner> mergeOwners;
  const _BlockScanResult(this.writes, this.mergeOwners);
}

class _MergeOwner {
  final BlockId ownerId;
  final ResolvedBlockKind kind;
  const _MergeOwner(this.ownerId, this.kind);
}

_BlockScanResult _resolveBlockScan(
  State state,
  ScanItemResult Function(InlineItem) classify,
) {
  final writes = <ResolveDecisionWrite>[];
  final mergeOwners = <_MergeOwner>[];
  
  for (final block in iterateBlocksInDocumentOrder(state)) {
    final content = block.inlineContent;
    if (content == null) continue;
    var touched = false;
    final decisions = <ScanItemResult>[];
    
    for (final item in content.items) {
      final r = classify(item);
      if (r is! ScanKeep) {
        touched = true;
        if (r is ScanBreakDrop && r.merge) {
          final kind = resolveBlock(state, block.id)?.kind ?? ResolvedBlockKind.main;
          mergeOwners.add(_MergeOwner(block.id, kind));
        }
      }
      decisions.add(r);
    }
    
    if (touched) {
      final kind = resolveBlock(state, block.id)?.kind ?? ResolvedBlockKind.main;
      writes.add(ResolveDecisionWrite(blockId: block.id, kind: kind, decisions: decisions));
    }
  }
  return _BlockScanResult(writes, mergeOwners);
}

OperationResult _runResolve(
  State state,
  List<SuggestionId> idsToDelete,
  ScanItemResult Function(InlineItem) classify,
  Map<String, AttrEqualsFn>? customEquals,
) {
  final scan = _resolveBlockScan(state, classify);
  return applyOperation(state, (d) {
    for (final write in scan.writes) {
      applyResolveDecisionsInTx(d, write.blockId, write.kind, write.decisions, customEquals);
    }
    for (var i = scan.mergeOwners.length - 1; i >= 0; i--) {
      final owner = scan.mergeOwners[i];
      mergeWithNextSiblingLiveInTx(d, owner.ownerId, owner.kind, customEquals);
    }
    for (final id in idsToDelete) {
      d.suggestions.remove(id.value);
    }
    if (scan.writes.isEmpty) {
      d.markDirty(state.rootId.value);
    }
  }); // Note: origin is suggestionResolveOrigin... Need to pass origin to applyOperation? No, in dart we haven't implemented origins for history.
}

OperationResult acceptSuggestion(State state, SuggestionId id, [Map<String, AttrEqualsFn>? customEquals]) {
  return _resolve(state, id, true, customEquals);
}

OperationResult rejectSuggestion(State state, SuggestionId id, [Map<String, AttrEqualsFn>? customEquals]) {
  return _resolve(state, id, false, customEquals);
}

OperationResult _resolve(
  State state,
  SuggestionId id,
  bool isAccept,
  Map<String, AttrEqualsFn>? customEquals,
) {
  final doc = state.doc;
  final record = readSuggestionRecord(doc, id);
  if (record == null) {
    return OperationResult(state: state, dirtyIds: {});
  }
  
  final attrKey = _attrKeyByKind(record.kind);
  final action = _resolveAction(record.kind, isAccept);
  final proposedAttrs = record.proposedAttrs ?? const {};
  
  final breakMerge = (record.kind == 'insertion' && !isAccept) ||
                     (record.kind == 'deletion' && isAccept);
                     
  ScanItemResult classify(InlineItem item) {
    if (_isBreakEmbed(item) && (item as EmbedItem).properties['suggestionId'] == id.value) {
      return ScanBreakDrop(breakMerge);
    }
    if (item is TextItem && item.attrs[attrKey] == id.value) {
      switch (action) {
        case ResolveAction.strip:
          return ScanRewrite(_attrsWithout(item.attrs, attrKey));
        case ResolveAction.drop:
          return const ScanDrop();
        case ResolveAction.applyStrip:
          return ScanRewrite(mergeAttrs(_attrsWithout(item.attrs, attrKey), proposedAttrs));
      }
    }
    if (item is EmbedItem) {
      final resolved = _resolveEmbedFormatting(item, isAccept, doc, id);
      if (resolved != null) return ScanRewrite(resolved.attrs);
    }
    return const ScanKeep();
  }
  
  final deletes = _collectResolveRecordDeletes(state, id, classify);
  return _runResolve(state, deletes, classify, customEquals);
}

List<SuggestionId> _collectResolveRecordDeletes(
  State state,
  SuggestionId id,
  ScanItemResult Function(InlineItem) classify,
) {
  final droppedCoTenants = <SuggestionId>{};
  final survivors = <SuggestionId>{};
  
  for (final block in iterateBlocksInDocumentOrder(state)) {
    final content = block.inlineContent;
    if (content == null) continue;
    for (final item in content.items) {
      final op = classify(item);
      final dropped = op is ScanDrop || op is ScanBreakDrop;
      for (final sid in suggestionIdsOnItem(item)) {
        if (sid == id) continue;
        if (dropped) {
          droppedCoTenants.add(sid);
        } else {
          survivors.add(sid);
        }
      }
    }
  }
  
  final out = <SuggestionId>[id];
  for (final c in droppedCoTenants) {
    if (!survivors.contains(c)) out.add(c);
  }
  return out;
}

String _attrKeyByKind(String kind) {
  switch (kind) {
    case 'insertion': return insertionSuggestionAttr;
    case 'deletion': return deletionSuggestionAttr;
    case 'formatting': return formattingSuggestionAttr;
    default: return '';
  }
}

ResolveAction _resolveAction(String kind, bool isAccept) {
  switch (kind) {
    case 'insertion':
      return isAccept ? ResolveAction.strip : ResolveAction.drop;
    case 'deletion':
      return isAccept ? ResolveAction.drop : ResolveAction.strip;
    case 'formatting':
      return isAccept ? ResolveAction.applyStrip : ResolveAction.strip;
    default:
      return ResolveAction.strip;
  }
}

ReadonlyAttrs _attrsWithout(ReadonlyAttrs attrs, String key) {
  final copy = Map<String, dynamic>.from(attrs);
  copy.remove(key);
  return copy;
}

EmbedItem? _resolveEmbedFormatting(
  EmbedItem item,
  bool isAccept,
  TwDoc doc,
  [SuggestionId? onlyId]
) {
  final fmtRaw = item.attrs[formattingSuggestionAttr];
  if (fmtRaw is! String) return null;
  if (onlyId != null && fmtRaw != onlyId.value) return null;
  
  var attrs = _attrsWithout(item.attrs, formattingSuggestionAttr);
  if (isAccept) {
    final record = readSuggestionRecord(doc, SuggestionId(fmtRaw));
    attrs = mergeAttrs(attrs, record?.proposedAttrs ?? const {});
  }
  return EmbedItem(embedType: item.embedType, attrs: attrs, properties: item.properties);
}

OperationResult acceptAll(State state, [Map<String, AttrEqualsFn>? customEquals]) {
  return _resolveAll(state, true, customEquals);
}

OperationResult rejectAll(State state, [Map<String, AttrEqualsFn>? customEquals]) {
  return _resolveAll(state, false, customEquals);
}

OperationResult _resolveAll(State state, bool isAccept, Map<String, AttrEqualsFn>? customEquals) {
  final doc = state.doc;
  final ids = doc.suggestions.keys.map((k) => SuggestionId(k)).toList();
  if (ids.isEmpty) return OperationResult(state: state, dirtyIds: {});
  
  return _runResolve(state, ids, (item) {
    if (_isBreakEmbed(item)) {
      final sidRaw = (item as EmbedItem).properties['suggestionId'];
      var merge = false;
      if (sidRaw is String) {
        final record = readSuggestionRecord(doc, SuggestionId(sidRaw));
        merge = record != null && (
          (record.kind == 'insertion' && !isAccept) ||
          (record.kind == 'deletion' && isAccept)
        );
      }
      return ScanBreakDrop(merge);
    }
    
    if (item is TextItem) {
      final rewrite = isAccept ? _acceptAllRun(item, doc) : _rejectAllRun(item);
      if (!rewrite.touched) return const ScanKeep();
      return rewrite.keep && rewrite.item != null
          ? ScanRewrite(rewrite.item!.attrs)
          : const ScanDrop();
    }
    
    if (item is EmbedItem) {
      final resolved = _resolveEmbedFormatting(item, isAccept, doc);
      if (resolved != null) return ScanRewrite(resolved.attrs);
    }
    return const ScanKeep();
  }, customEquals);
}

class _AllRewrite {
  final bool touched;
  final bool keep;
  final TextItem? item;
  const _AllRewrite({required this.touched, required this.keep, this.item});
}

_AllRewrite _acceptAllRun(TextItem item, TwDoc doc) {
  final hasInsertion = item.attrs[insertionSuggestionAttr] is String;
  final hasDeletion = item.attrs[deletionSuggestionAttr] is String;
  final fmtRaw = item.attrs[formattingSuggestionAttr];
  final hasFormatting = fmtRaw is String;
  
  if (!hasInsertion && !hasDeletion && !hasFormatting) {
    return _AllRewrite(touched: false, keep: true, item: item);
  }
  if (hasDeletion) {
    return const _AllRewrite(touched: true, keep: false);
  }
  
  var attrs = _attrsWithout(item.attrs, insertionSuggestionAttr);
  if (hasFormatting) {
    final record = readSuggestionRecord(doc, SuggestionId(fmtRaw));
    final proposed = record?.proposedAttrs ?? const {};
    attrs = mergeAttrs(_attrsWithout(attrs, formattingSuggestionAttr), proposed);
  }
  return _AllRewrite(touched: true, keep: true, item: TextItem(text: item.text, attrs: attrs));
}

_AllRewrite _rejectAllRun(TextItem item) {
  final hasInsertion = item.attrs[insertionSuggestionAttr] is String;
  final hasDeletion = item.attrs[deletionSuggestionAttr] is String;
  final hasFormatting = item.attrs[formattingSuggestionAttr] is String;
  
  if (!hasInsertion && !hasDeletion && !hasFormatting) {
    return _AllRewrite(touched: false, keep: true, item: item);
  }
  if (hasInsertion) {
    return const _AllRewrite(touched: true, keep: false);
  }
  
  var attrs = item.attrs;
  if (hasDeletion) attrs = _attrsWithout(attrs, deletionSuggestionAttr);
  if (hasFormatting) attrs = _attrsWithout(attrs, formattingSuggestionAttr);
  return _AllRewrite(touched: true, keep: true, item: TextItem(text: item.text, attrs: attrs));
}


void mergeWithNextSiblingLiveInTx(TwDoc doc, BlockId blockId, ResolvedBlockKind kind, [Map<String, AttrEqualsFn>? customEquals]) {
  final leftMap = kind == ResolvedBlockKind.embed
      ? doc.getEmbedContentMap(blockId.value)
      : (kind == ResolvedBlockKind.template
          ? doc.getTemplateContentMap(blockId.value)
          : doc.getBlockMap(blockId.value));
  if (leftMap == null) return;
  
  final rightIdVal = leftMap[BlockFields.nextSiblingId];
  if (rightIdVal is! String) return;
  final rightId = BlockId(rightIdVal);

  final rightMap = kind == ResolvedBlockKind.embed
      ? doc.getEmbedContentMap(rightId.value)
      : (kind == ResolvedBlockKind.template
          ? doc.getTemplateContentMap(rightId.value)
          : doc.getBlockMap(rightId.value));
  if (rightMap == null) return;

  final leftItems = (leftMap[BlockFields.inlineContent] as InlineContent).items;
  final rightItems = (rightMap[BlockFields.inlineContent] as InlineContent).items;

  final merged = mergeAdjacentSameAttrsTextItems(
    [...leftItems, ...rightItems],
    customEquals,
  );

  leftMap[BlockFields.inlineContent] = InlineContent(merged);
  final rightNextIdVal = rightMap[BlockFields.nextSiblingId];
  leftMap[BlockFields.nextSiblingId] = rightNextIdVal;
  doc.markDirty(blockId.value);

  if (rightNextIdVal is String) {
    final nextMap = kind == ResolvedBlockKind.embed
        ? doc.getEmbedContentMap(rightNextIdVal)
        : (kind == ResolvedBlockKind.template
            ? doc.getTemplateContentMap(rightNextIdVal)
            : doc.getBlockMap(rightNextIdVal));
    if (nextMap != null) {
      nextMap[BlockFields.prevSiblingId] = blockId.value;
      doc.markDirty(rightNextIdVal);
    }
  } else {
    final parentIdVal = leftMap[BlockFields.parentId];
    if (parentIdVal is String) {
      final parentMap = kind == ResolvedBlockKind.embed
          ? doc.getEmbedContentMap(parentIdVal)
          : (kind == ResolvedBlockKind.template
              ? doc.getTemplateContentMap(parentIdVal)
              : doc.getBlockMap(parentIdVal));
      if (parentMap != null) {
        parentMap[BlockFields.lastChildId] = blockId.value;
        doc.markDirty(parentIdVal);
      }
    }
  }

  if (kind == ResolvedBlockKind.main) {
    doc.deleteBlock(rightId.value);
  } else if (kind == ResolvedBlockKind.embed) {
    doc.deleteEmbedContent(rightId.value);
  } else if (kind == ResolvedBlockKind.template) {
    doc.deleteTemplateContent(rightId.value);
  }
}
