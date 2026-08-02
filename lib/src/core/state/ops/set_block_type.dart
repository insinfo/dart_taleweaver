/// Change a block's type.
///
/// Port of `ops/set-block-type.ts`.
library;

import '../block_id.dart';
import '../block_kinds.dart';
import '../state.dart';

/// Change a block's type.
OperationResult setBlockType(
  State state,
  BlockId blockId,
  String type,
  BlockKindResolver resolver,
) {
  final resolved = resolveBlock(state, blockId);
  if (resolved == null) {
    throw StateError('setBlockType: block "$blockId" not found');
  }

  final block = resolved.block;
  final oldKind = resolver.getBlockKind(block.type);
  if (oldKind == null) {
    throw StateError(
      'setBlockType: existing block\'s type "${block.type}" is not registered',
    );
  }

  final newKind = resolver.getBlockKind(type);
  if (newKind == null) {
    throw StateError('setBlockType: new type "$type" is not registered');
  }

  if (oldKind != newKind) {
    throw StateError(
      'setBlockType: cross-kind change refused — '
      'block "$blockId" is $oldKind ("${block.type}"), '
      'new type "$type" is $newKind. '
      'Compose remove + insert instead of changing kind.',
    );
  }

  if (type == block.type) {
    return OperationResult(state: state, dirtyIds: const {});
  }

  return applyOperation(state, (doc) {
    switch (resolved.kind) {
      case ResolvedBlockKind.main:
        doc.getBlockMap(blockId.value)?['type'] = type;
        break;
      case ResolvedBlockKind.embed:
        doc.getEmbedContentMap(blockId.value)?['type'] = type;
        break;
      case ResolvedBlockKind.template:
        doc.getTemplateContentMap(blockId.value)?['type'] = type;
        break;
    }
    doc.markDirty(blockId.value);
  });
}
