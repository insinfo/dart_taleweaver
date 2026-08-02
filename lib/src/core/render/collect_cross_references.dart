/// Collect cross references.
///
/// Port of `render/collect-cross-references.ts`.
library;

import '../state/block.dart';
import '../state/block_id.dart';
import '../state/block_traversal.dart';
import '../state/inline_content.dart';
import '../state/ops/insert_cross_reference.dart';
import '../state/state.dart';

Map<BlockId, List<BlockId>> buildCrossReferenceIndex(State state) {
  final index = <BlockId, List<BlockId>>{};
  
  for (final block in iterateBlocksInDocumentOrder(state)) {
    if (block.inlineContent == null) continue;
    
    for (final item in block.inlineContent!.items) {
      if (item is! EmbedItem) continue;
      if (item.embedType != crossReferenceEmbedType) continue;
      
      final targetIdRaw = item.properties['targetId'];
      if (targetIdRaw is! String) continue;
      
      final target = BlockId(targetIdRaw);
      final hosts = index[target];
      
      if (hosts == null) {
        index[target] = [block.id];
      } else if (hosts.isEmpty || hosts.last != block.id) {
        hosts.add(block.id);
      }
    }
  }
  
  return index.isNotEmpty ? index : emptyCrossReferenceIndex;
}

const emptyCrossReferenceIndex = <BlockId, List<BlockId>>{};

bool blockHasCrossReference(Block? block) {
  if (block == null || block.inlineContent == null) return false;
  
  for (final item in block.inlineContent!.items) {
    if (item is EmbedItem && item.embedType == crossReferenceEmbedType) {
      return true;
    }
  }
  
  return false;
}
