/// Resolve cross reference.
///
/// Port of `render/resolve-cross-reference.ts`.
library;

import '../numbering/types.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/extract_text.dart';
import '../state/inline_content.dart';
import '../state/state.dart';
import '../state/suggestions.dart';

const String brokenCrossReferenceText = 'Error! Reference source not found.';

class CrossReferenceProps {
  final BlockId targetId;
  final String refMode; // "number" | "text" | "page"

  const CrossReferenceProps({
    required this.targetId,
    required this.refMode,
  });
}

String resolveCrossReference(
  State state,
  Map<BlockId, CounterValue> numbering,
  CrossReferenceProps props, [
  SuggestionView view = SuggestionView.suggesting,
]) {
  final targetId = props.targetId;
  final refMode = props.refMode;
  
  if (refMode == 'number') {
    final counter = numbering[targetId];
    return counter == null ? brokenCrossReferenceText : counter.formatted;
  }
  
  // refMode == "text" (or fallback for "page" before we have pagination)
  final block = getBlock(state, targetId);
  if (block == null || block.inlineContent == null) {
    return brokenCrossReferenceText;
  }
  
  final length = inlineContentLength(block.inlineContent!);
  if (length == 0) return '';
  
  final span = createSpan(createPosition(targetId, 0), createPosition(targetId, length));
  return extractText(state, span, captionEmbedSerializer, view);
}
