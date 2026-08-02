/// Insert footnote operation.
///
/// Port of `state/ops/insert-footnote.ts`.
library;

import '../block_id.dart';
import '../block_position.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

/// The `embedType` discriminant for a footnote call marker.
const footnoteAnchorEmbedType = 'footnote-anchor';

const _footnoteBodyType = 'footnote-body';

class InsertFootnoteResult {
  final BlockId bodyRootId;
  final BlockId firstParagraphId;
  final Set<String> dirtyIds;

  const InsertFootnoteResult({
    required this.bodyRootId,
    required this.firstParagraphId,
    required this.dirtyIds,
  });
}

class _AnchorInsertPlan {
  final BlockId blockId;
  final String kind; // Tree kind: main, embed, template
  final List<InlineItem> items;

  const _AnchorInsertPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

/// Insert a footnote at [position].
InsertFootnoteResult insertFootnote(
  State state,
  Position position,
  IdAllocator allocator,
) {
  final bodyRootId = allocator.allocate();
  final firstParagraphId = allocator.allocate();

  final anchorPlan = _planAnchorInsert(state, position, bodyRootId);

  final dirtyIds = <String>{};

  applyOperation(state, (doc) {
    _insertFootnoteBodyInTx(doc, bodyRootId, firstParagraphId);
    _insertAnchorInTx(doc, anchorPlan);

    dirtyIds.add(bodyRootId.value);
    dirtyIds.add(firstParagraphId.value);
    dirtyIds.add(anchorPlan.blockId.value);
  });

  return InsertFootnoteResult(
    bodyRootId: bodyRootId,
    firstParagraphId: firstParagraphId,
    dirtyIds: dirtyIds,
  );
}

_AnchorInsertPlan _planAnchorInsert(
  State state,
  Position position,
  BlockId bodyRootId,
) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertFootnote: block "${position.blockId}" not found');
  }

  final block = resolved.block;
  final kind = switch (resolved.kind) {
    ResolvedBlockKind.main => 'main',
    ResolvedBlockKind.embed => 'embed',
    ResolvedBlockKind.template => 'template',
  };

  if (block.inlineContent == null) {
    throw StateError(
      'insertFootnote: block "${position.blockId}" is not a leaf',
    );
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw StateError(
      'insertFootnote: offset ${position.offset} out of range [0, $totalLen]',
    );
  }

  final anchor = EmbedItem(
    embedType: footnoteAnchorEmbedType,
    attrs: {},
    properties: {'contentBlockId': bodyRootId.value},
  );

  final split =
      splitInlineContentAtOffset(block.inlineContent!, position.offset);
  final left = split.$1;
  final right = split.$2;

  final items = mergeAdjacentTextItems([...left, anchor, ...right]);

  return _AnchorInsertPlan(blockId: position.blockId, kind: kind, items: items);
}

void _insertFootnoteBodyInTx(
  TwDoc doc,
  BlockId bodyRootId,
  BlockId firstParagraphId,
) {
  doc.embedContents[bodyRootId.value] = {
    'id': bodyRootId.value,
    'type': _footnoteBodyType,
    'attrs': {},
    'parentId': null,
    'prevSiblingId': null,
    'nextSiblingId': null,
    'firstChildId': firstParagraphId.value,
    'lastChildId': firstParagraphId.value,
    'inlineContent': null,
  };

  doc.embedContents[firstParagraphId.value] = {
    'id': firstParagraphId.value,
    'type': 'paragraph',
    'attrs': {},
    'parentId': bodyRootId.value,
    'prevSiblingId': null,
    'nextSiblingId': null,
    'firstChildId': null,
    'lastChildId': null,
    'inlineContent': InlineContent.empty,
  };
}

void _insertAnchorInTx(TwDoc doc, _AnchorInsertPlan plan) {
  Map<String, Map<String, dynamic>> tree;
  if (plan.kind == 'embed') {
    tree = doc.embedContents;
  } else if (plan.kind == 'template') {
    tree = doc.templateContents;
  } else {
    tree = doc.blocks;
  }

  final blockObj = tree[plan.blockId.value];
  if (blockObj == null) {
    throw StateError(
        'insertFootnote: Block ${plan.blockId} not found in tree ${plan.kind}');
  }

  blockObj['inlineContent'] = InlineContent(plan.items);
}
