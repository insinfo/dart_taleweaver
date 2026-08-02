/// Set list restart.
///
/// Port of `ops/set-list-restart.ts`.
library;

import '../block_id.dart';
import '../state.dart';
import 'merge_block_attrs.dart';

OperationResult setListRestart(
  State state,
  BlockId blockId,
  int? value,
) {
  return mergeBlockAttrs(state, blockId, {'listCounterOverride': value});
}
