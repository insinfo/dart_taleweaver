/// Insert blocks after an anchor.
///
/// Port of `ops/insert-blocks-after.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

class SiblingBlockInit {
  final String type;
  final ReadonlyAttrs? attrs;
  final InlineContent? inlineContent;

  const SiblingBlockInit({
    required this.type,
    this.attrs,
    this.inlineContent,
  });
}

class _InsertBlocksAfterEntry {
  final BlockId id;
  final String type;
  final ReadonlyAttrs attrs;
  final InlineContent? inlineContent;

  const _InsertBlocksAfterEntry({
    required this.id,
    required this.type,
    required this.attrs,
    this.inlineContent,
  });
}

class InsertBlocksAfterPlan {
  final BlockId parentId;
  final BlockId afterBlockId;
  final BlockId? oldNextId;
  final List<_InsertBlocksAfterEntry> entries;

  const InsertBlocksAfterPlan({
    required this.parentId,
    required this.afterBlockId,
    this.oldNextId,
    required this.entries,
  });
}

class InsertBlocksAfterResult {
  final OperationResult result;
  final List<BlockId> newBlockIds;

  const InsertBlocksAfterResult(this.result, this.newBlockIds);
}

InsertBlocksAfterResult insertBlocksAfter(
  State state,
  BlockId afterBlockId,
  List<SiblingBlockInit> inits,
  IdAllocator allocator,
) {
  final plan = planInsertBlocksAfter(state, afterBlockId, inits, allocator);
  if (plan == null) {
    return InsertBlocksAfterResult(
        OperationResult(state: state, dirtyIds: const {}), const []);
  }

  final result = applyOperation(state, (doc) {
    insertBlocksAfterInTx(doc, plan);
  });

  return InsertBlocksAfterResult(
      result, plan.entries.map((e) => e.id).toList());
}

InsertBlocksAfterPlan? planInsertBlocksAfter(
  State state,
  BlockId afterBlockId,
  List<SiblingBlockInit> inits,
  IdAllocator allocator,
) {
  final afterBlock = getBlock(state, afterBlockId);
  if (afterBlock == null) {
    throw StateError('insertBlocksAfter: block not found');
  }
  if (afterBlock.parentId == null) {
    throw StateError('insertBlocksAfter: root has no parent');
  }
  if (inits.isEmpty) return null;

  final entries = inits
      .map((init) => _InsertBlocksAfterEntry(
            id: allocator.allocate(),
            type: init.type,
            attrs: init.attrs ?? const {},
            inlineContent: init.inlineContent,
          ))
      .toList();

  return InsertBlocksAfterPlan(
    parentId: afterBlock.parentId!,
    afterBlockId: afterBlockId,
    oldNextId: afterBlock.nextSiblingId,
    entries: entries,
  );
}

void insertBlocksAfterInTx(TwDoc doc, InsertBlocksAfterPlan plan) {
  final lastIndex = plan.entries.length - 1;
  for (int i = 0; i < plan.entries.length; i++) {
    final entry = plan.entries[i];
    final prevEntry = i == 0 ? null : plan.entries[i - 1];
    final nextEntry = i == lastIndex ? null : plan.entries[i + 1];

    final prevSiblingId = i == 0 ? plan.afterBlockId : prevEntry!.id;
    final nextSiblingId = i == lastIndex ? plan.oldNextId : nextEntry!.id;

    doc.setBlockMap(entry.id.value, {
      BlockFields.type: entry.type,
      BlockFields.attrs: entry.attrs,
      BlockFields.parentId: plan.parentId.value,
      BlockFields.prevSiblingId: prevSiblingId.value,
      if (nextSiblingId != null) BlockFields.nextSiblingId: nextSiblingId.value,
      if (entry.inlineContent != null)
        BlockFields.inlineContent: entry.inlineContent!,
    });
  }

  final firstEntry = plan.entries.first;
  final lastEntry = plan.entries.last;

  doc.getBlockMap(plan.afterBlockId.value)?[BlockFields.nextSiblingId] =
      firstEntry.id.value;
  doc.markDirty(plan.afterBlockId.value);

  final runTail = lastEntry.id;
  if (plan.oldNextId != null) {
    doc.getBlockMap(plan.oldNextId!.value)?[BlockFields.prevSiblingId] =
        runTail.value;
    doc.markDirty(plan.oldNextId!.value);
  } else {
    doc.getBlockMap(plan.parentId.value)?[BlockFields.lastChildId] =
        runTail.value;
    doc.markDirty(plan.parentId.value);
  }
}
