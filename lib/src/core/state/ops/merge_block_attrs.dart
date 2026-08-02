/// Merge block attributes.
///
/// Port of `ops/merge-block-attrs.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../state.dart';

OperationResult mergeBlockAttrs(
  State state,
  BlockId blockId,
  ReadonlyAttrs incoming, [
  Map<String, AttrEqualsFn>? customEquals,
]) {
  final resolved = resolveBlock(state, blockId);
  if (resolved == null) {
    throw StateError('mergeBlockAttrs: block "$blockId" not found');
  }
  
  final block = resolved.block;
  final merged = mergeAttrs(block.attrs, incoming);
  
  return applyOperation(state, (doc) {
    if (attrsEqual(block.attrs, merged, customEquals: customEquals)) {
      return;
    }
    
    final yBlock = resolved.kind == ResolvedBlockKind.embed 
        ? doc.getEmbedContentMap(blockId.value)
        : (resolved.kind == ResolvedBlockKind.template 
            ? doc.getTemplateContentMap(blockId.value) 
            : doc.getBlockMap(blockId.value));
            
    if (yBlock != null) {
      yBlock['attrs'] = merged;
      doc.markDirty(blockId.value);
    }
  });
}
