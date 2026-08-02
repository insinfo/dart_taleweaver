/// Inline render key utils.
///
/// Port of `render/inline-render-key.ts`.
library;

import '../state/block_id.dart';

const String inlineKeySeparator = '/inline/';

String inlineRenderKey(BlockId blockId, int i) {
  return '${blockId.value}$inlineKeySeparator$i';
}
