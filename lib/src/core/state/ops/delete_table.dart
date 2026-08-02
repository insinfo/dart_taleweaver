/// Delete a table with replacement.
///
/// Port of `ops/delete-table.ts`.
library;

import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import 'remove_block.dart';

class DeleteTableResult {
  final OperationResult result;
  final BlockId? newParagraphId;

  const DeleteTableResult(this.result, this.newParagraphId);
}

DeleteTableResult deleteTableWithReplacement(
  State state,
  BlockId tableId,
  IdAllocator allocator,
) {
  final table = getBlock(state, tableId);
  if (table == null) {
    throw StateError('deleteTableWithReplacement: block "$tableId" not found');
  }
  final parentId = table.parentId;
  if (parentId == null) {
    throw StateError('deleteTableWithReplacement: "$tableId" is the root');
  }

  final removePlan = planRemoveBlock(state, tableId);
  final isSoleChild = table.prevSiblingId == null && table.nextSiblingId == null;

  if (!isSoleChild) {
    final result = applyOperation(state, (doc) {
      removeBlockInTx(doc, removePlan);
    });
    return DeleteTableResult(result, null);
  }

  final newParagraphId = allocator.allocate();
  final result = applyOperation(state, (doc) {
    removeBlockInTx(doc, removePlan);
    
    doc.setBlockMap(newParagraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: parentId.value,
      BlockFields.inlineContent: const InlineContent([]),
    });
    
    final yParent = doc.getBlockMap(parentId.value);
    if (yParent != null) {
      yParent[BlockFields.firstChildId] = newParagraphId.value;
      yParent[BlockFields.lastChildId] = newParagraphId.value;
      doc.markDirty(parentId.value);
    }
  });

  return DeleteTableResult(result, newParagraphId);
}
