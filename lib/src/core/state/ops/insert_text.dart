/// Insert text into a block's inline content.
///
/// Port of `ops/insert-text.ts`.
library;

import '../attrs.dart';
import '../block_id.dart';
import '../block_position.dart';
import '../block_schema.dart';
import '../inline_content.dart';
import '../state.dart';
import '../tw_doc.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

/// Pre-computed mutation plan for `insertTextInTx`.
class InsertTextPlan {
  final BlockId blockId;
  final ResolvedBlockKind kind;
  final List<InlineItem> items;

  const InsertTextPlan({
    required this.blockId,
    required this.kind,
    required this.items,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Insert text into a leaf block's inlineContent at [position].
///
/// Returns an [OperationResult] with `dirtyIds = {position.blockId}`.
OperationResult insertText(
  State state,
  Position position,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  if (text.isEmpty) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final plan = planInsertText(
    state,
    position,
    text,
    attrs,
    customEquals: customEquals,
  );

  return applyOperation(state, (doc) {
    insertTextInTx(doc, plan);
  });
}

/// Apply a pre-computed [InsertTextPlan] to [doc].
///
/// MUST run inside an already-open transaction.
void insertTextInTx(TwDoc doc, InsertTextPlan plan) {
  Map<String, dynamic>? map;
  switch (plan.kind) {
    case ResolvedBlockKind.main:
      map = doc.getBlockMap(plan.blockId.value);
    case ResolvedBlockKind.embed:
      map = doc.getEmbedContentMap(plan.blockId.value);
    case ResolvedBlockKind.template:
      map = doc.getTemplateContentMap(plan.blockId.value);
  }

  if (map != null) {
    map[BlockFields.inlineContent] = InlineContent(plan.items);
    doc.markDirty(plan.blockId.value);
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

/// Validate [position] + [text] against [state] and produce an [InsertTextPlan].
InsertTextPlan planInsertText(
  State state,
  Position position,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final resolved = resolveBlock(state, position.blockId);
  if (resolved == null) {
    throw StateError('insertText: block "${position.blockId}" not found');
  }
  final block = resolved.block;
  if (block.inlineContent == null) {
    throw StateError(
      'insertText: block "${position.blockId}" is not a leaf (no inlineContent)',
    );
  }

  final totalLen = inlineContentLength(block.inlineContent!);
  if (position.offset < 0 || position.offset > totalLen) {
    throw StateError(
      'insertText: offset ${position.offset} out of range [0, $totalLen] '
      'for block "${position.blockId}"',
    );
  }

  return planInsertTextFullReplace(
    position.blockId,
    resolved.kind,
    block.inlineContent!.items,
    position.offset,
    text,
    attrs,
    customEquals: customEquals,
  );
}

/// Build a `full-replace` InsertTextPlan against a pre-computed `items` array.
///
/// Unlike Yjs which needs careful in-place surgery to preserve CRDT identity,
/// our Dart data model just replaces the immutable list of items.
InsertTextPlan planInsertTextFullReplace(
  BlockId blockId,
  ResolvedBlockKind kind,
  List<InlineItem> items,
  int offset,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final (left, right) =
      splitInlineContentAtOffset(InlineContent(items), offset);
  final newRun = TextItem(text: text, attrs: attrs);
  final merged = mergeAdjacentTextItems(
    [...left, newRun, ...right],
    customEquals: customEquals,
  );

  return InsertTextPlan(blockId: blockId, kind: kind, items: merged);
}
