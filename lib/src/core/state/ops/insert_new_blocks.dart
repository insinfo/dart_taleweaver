/// Insert new blocks fully resolved.
///
/// Port of `ops/insert-new-blocks.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

class NewBlockSpec {
  final BlockId id;
  final ResolvedBlockKind kind;
  final String type;
  final ReadonlyAttrs attrs;
  final List<InlineItem> items;
  final BlockId parentId;
  final BlockId prevSiblingId;
  final BlockId? nextSiblingId;

  const NewBlockSpec({
    required this.id,
    required this.kind,
    required this.type,
    required this.attrs,
    required this.items,
    required this.parentId,
    required this.prevSiblingId,
    this.nextSiblingId,
  });
}

void insertNewBlocksInTx(TwDoc doc, List<NewBlockSpec> specs) {
  for (final s in specs) {
    final map = <String, dynamic>{
      BlockFields.type: s.type,
      BlockFields.attrs: Map<String, dynamic>.of(s.attrs),
      BlockFields.parentId: s.parentId.value,
      BlockFields.prevSiblingId: s.prevSiblingId.value,
      if (s.nextSiblingId != null)
        BlockFields.nextSiblingId: s.nextSiblingId!.value,
      BlockFields.inlineContent: InlineContent(List.of(s.items)),
    };

    switch (s.kind) {
      case ResolvedBlockKind.main:
        doc.setBlockMap(s.id.value, map);
        break;
      case ResolvedBlockKind.embed:
        doc.setEmbedContentMap(s.id.value, map);
        break;
      case ResolvedBlockKind.template:
        doc.setTemplateContentMap(s.id.value, map);
        break;
    }
  }
}
