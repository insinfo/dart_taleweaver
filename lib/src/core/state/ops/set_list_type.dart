/// Set list type.
///
/// Port of `ops/set-list-type.ts`.
library;

import '../block_id.dart';
import '../block_traversal.dart';
import '../list_defs.dart';
import '../state.dart';

final ListDef orderedDef = ListDef(
  levels: List.generate(
      9,
      (i) => ListLevelConfig(
            style: i % 2 == 0 ? 'decimal' : 'lower-alpha',
            start: 1,
            restart: 'after-break',
          )),
);

final ListDef unorderedDef = ListDef(
  levels: List.generate(
      9,
      (i) => ListLevelConfig(
            style: i % 3 == 0 ? 'disc' : (i % 3 == 1 ? 'circle' : 'square'),
            start: 1,
            restart: 'after-break',
          )),
);

enum ListType { ordered, unordered }

OperationResult setListType(
  State state,
  String listId,
  ListType listType,
) {
  final def = listType == ListType.ordered ? orderedDef : unorderedDef;
  final affected = <BlockId>{};

  for (final block in iterateBlocksInDocumentOrder(state)) {
    if (block.type != 'list-item') continue;
    final blockListId = block.attrs['listId'];
    if (blockListId is String && blockListId == listId) {
      affected.add(block.id);
    }
  }

  return applyOperation(state, (doc) {
    writeListDefInTx(doc, listId, def);
    for (final id in affected) {
      doc.markDirty(id.value);
    }
  });
}
