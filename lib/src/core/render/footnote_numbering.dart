/// Deterministic footnote numbering derived from document-order anchors.
library;

import '../state/block_id.dart';
import '../state/block_traversal.dart';
import '../state/inline_content.dart';
import '../state/ops/insert_footnote.dart';
import '../state/state.dart';
import '../styles/format_counter.dart';

Map<BlockId, String> buildFootnoteNumberIndex(State state,
    {String? reset, String? format, Map<BlockId, int>? pageByBlock}) {
  final result = <BlockId, String>{};
  final root = getBlock(state, state.rootId);
  final rawReset = root?.attrs['footnoteNumberingReset'];
  final rawFormat = root?.attrs['footnoteNumberingFormat'];
  final policyReset = reset ?? (rawReset is String ? rawReset : null);
  final policyFormat = format ?? (rawFormat is String ? rawFormat : null);
  final safeFormat = const {
    'decimal',
    'lower-alpha',
    'upper-alpha',
    'lower-roman',
    'upper-roman',
  }.contains(policyFormat)
      ? policyFormat!
      : 'decimal';
  var number = 0;
  Object? previousSection;
  int? previousPage;
  for (final block in iterateBlocksInDocumentOrder(state)) {
    final content = block.inlineContent;
    if (content == null) continue;
    for (final item in content.items) {
      if (item is! EmbedItem || item.embedType != footnoteAnchorEmbedType) {
        continue;
      }
      final raw = item.properties['contentBlockId'];
      if (raw is! String) continue;
      Object? section;
      var ancestor = block.parentId;
      while (ancestor != null) {
        final parent = getBlock(state, ancestor);
        if (parent == null) break;
        if (parent.type == 'section' || parent.attrs['sectionId'] != null) {
          section = parent.id.value;
          break;
        }
        ancestor = parent.parentId;
      }
      final page = pageByBlock?[block.id];
      if ((policyReset == 'restart-per-section' &&
              section != previousSection) ||
          (policyReset == 'restart-per-page' && page != previousPage)) {
        number = 0;
      }
      number++;
      result[BlockId(raw)] = formatCounter(number, safeFormat);
      previousSection = section;
      previousPage = page;
    }
  }
  return result;
}
