/// Replace a block's attrs with a new set.
///
/// Port of `ops/set-block-attrs.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../state.dart';
import '../tw_doc.dart';

/// Replace a block's attrs with the given bag.
OperationResult setBlockAttrs(
  State state,
  BlockId blockId,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final resolved = resolveBlock(state, blockId);
  if (resolved == null) {
    throw StateError('setBlockAttrs: block "${blockId.value}" not found');
  }

  return applyOperation(state, (doc) {
    if (attrsEqual(resolved.block.attrs, attrs, customEquals: customEquals)) {
      return;
    }
    final map = _getMap(doc, blockId, resolved.kind);
    if (map != null) {
      map[BlockFields.attrs] = Map<String, dynamic>.of(attrs);
      doc.markDirty(blockId.value);
    }
  });
}

/// In-transaction block-attr REPLACE primitive.
void setBlockAttrsInTx(
  TwDoc doc,
  BlockId blockId,
  ReadonlyAttrs attrs,
) {
  final map = doc.getBlockMap(blockId.value);
  if (map != null) {
    map[BlockFields.attrs] = Map<String, dynamic>.of(attrs);
    doc.markDirty(blockId.value);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic>? _getMap(TwDoc doc, BlockId id, ResolvedBlockKind kind) {
  switch (kind) {
    case ResolvedBlockKind.main:
      return doc.getBlockMap(id.value);
    case ResolvedBlockKind.embed:
      return doc.getEmbedContentMap(id.value);
    case ResolvedBlockKind.template:
      return doc.getTemplateContentMap(id.value);
  }
}
