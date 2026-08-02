/// Insert template body.
///
/// Port of `ops/insert-template-body.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';

class InsertTemplateBodyArgs {
  final String region; // "header" or "footer"
  final BlockId sectionBlockId;

  const InsertTemplateBodyArgs({
    required this.region,
    required this.sectionBlockId,
  });
}

class InsertTemplateBodyResult {
  final State state;
  final Set<String> dirtyIds;
  final BlockId bodyRootId;
  final BlockId firstParagraphId;

  const InsertTemplateBodyResult({
    required this.state,
    required this.dirtyIds,
    required this.bodyRootId,
    required this.firstParagraphId,
  });
}

const _regionAttrKey = {
  'header': 'headerBlockId',
  'footer': 'footerBlockId',
};

InsertTemplateBodyResult insertTemplateBody(
  State state,
  InsertTemplateBodyArgs args,
  IdAllocator allocator,
) {
  final region = args.region;
  final sectionBlockId = args.sectionBlockId;

  final resolved = resolveBlock(state, sectionBlockId);
  if (resolved == null) {
    throw StateError(
        'insertTemplateBody: section block "$sectionBlockId" not found');
  }
  if (resolved.kind != ResolvedBlockKind.main) {
    throw StateError(
        'insertTemplateBody: section block "$sectionBlockId" must be in main tree');
  }

  final attrKey = _regionAttrKey[region];
  if (attrKey == null) {
    throw ArgumentError('insertTemplateBody: invalid region "$region"');
  }

  final bodyRootId = allocator.allocate();
  final firstParagraphId = allocator.allocate();

  final result = applyOperation(state, (doc) {
    doc.setTemplateContentMap(bodyRootId.value, {
      BlockFields.type: 'template-body',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: null,
      BlockFields.prevSiblingId: null,
      BlockFields.nextSiblingId: null,
      BlockFields.firstChildId: firstParagraphId.value,
      BlockFields.lastChildId: firstParagraphId.value,
      BlockFields.inlineContent: null,
    });

    doc.setTemplateContentMap(firstParagraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: bodyRootId.value,
      BlockFields.prevSiblingId: null,
      BlockFields.nextSiblingId: null,
      BlockFields.firstChildId: null,
      BlockFields.lastChildId: null,
      BlockFields.inlineContent: const InlineContent([]),
    });

    final merged = mergeAttrs(resolved.block.attrs, {
      attrKey: bodyRootId.value,
    });

    final ySection = doc.getBlockMap(sectionBlockId.value);
    if (ySection != null) {
      ySection[BlockFields.attrs] = merged;
      doc.markDirty(sectionBlockId.value);
    }
  });

  return InsertTemplateBodyResult(
    state: result.state,
    dirtyIds: result.dirtyIds,
    bodyRootId: bodyRootId,
    firstParagraphId: firstParagraphId,
  );
}
