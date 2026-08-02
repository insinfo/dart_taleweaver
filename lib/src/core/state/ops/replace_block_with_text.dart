/// Replace a whole block with text inserted into a sibling.
///
/// Port of `ops/replace-block-with-text.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../state.dart';
import 'insert_text.dart';
import 'remove_block.dart';

/// Replace a whole block with text inserted into a sibling text block.
OperationResult replaceBlockWithText(
  State state,
  BlockId removeBlockId,
  Position insertAt,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final removePlan = planRemoveBlock(state, removeBlockId);
  final insertPlan = planInsertText(
    state,
    insertAt,
    text,
    attrs,
    customEquals: customEquals,
  );

  return applyOperation(state, (doc) {
    removeBlockInTx(doc, removePlan);
    insertTextInTx(doc, insertPlan);
  });
}
