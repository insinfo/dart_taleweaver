/// Replace the inline content within a Span with the given text + attrs.
///
/// Port of `ops/replace-range.ts`.
library;

import '../attrs.dart';
import '../block_position.dart';
import '../span_iteration.dart';
import '../state.dart';
import '../tw_doc.dart';
import 'delete_range.dart';
import 'insert_text.dart';

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class ReplaceRangePlan {
  final DeleteRangePlan? deletePlan;
  final InsertTextPlan? insertPlan;

  const ReplaceRangePlan({
    this.deletePlan,
    this.insertPlan,
  });
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// Replace the inline content within [span] with [text] and [attrs].
OperationResult replaceRange(
  State state,
  Span span,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final plan = planReplaceRange(
    state,
    span,
    text,
    attrs,
    customEquals: customEquals,
  );
  if (plan == null) {
    return OperationResult(state: state, dirtyIds: {});
  }

  return applyOperation(state, (doc) {
    replaceRangeInTx(doc, plan);
  });
}

void replaceRangeInTx(TwDoc doc, ReplaceRangePlan plan) {
  if (plan.deletePlan != null) {
    deleteRangeInTx(doc, plan.deletePlan!);
  }
  if (plan.insertPlan != null) {
    insertTextInTx(doc, plan.insertPlan!);
  }
}

// ---------------------------------------------------------------------------
// Planner
// ---------------------------------------------------------------------------

ReplaceRangePlan? planReplaceRange(
  State state,
  Span span,
  String text,
  ReadonlyAttrs attrs, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final isCollapsed = span.anchor.blockId == span.focus.blockId &&
      span.anchor.offset == span.focus.offset;

  if (isCollapsed) {
    if (text.isEmpty) return null;
    return ReplaceRangePlan(
      deletePlan: null,
      insertPlan: planInsertText(
        state,
        span.anchor,
        text,
        attrs,
        customEquals: customEquals,
      ),
    );
  }

  assertDeleteRangeEndpoints(state, span);
  final normalized = normalizeSpan(state, span);
  final deletePlan = planDeleteRange(state, span, customEquals: customEquals);

  if (text.isEmpty) {
    if (deletePlan == null) return null;
    return ReplaceRangePlan(deletePlan: deletePlan, insertPlan: null);
  }

  if (deletePlan == null) {
    return ReplaceRangePlan(
      deletePlan: null,
      insertPlan: planInsertText(
        state,
        normalized.anchor,
        text,
        attrs,
        customEquals: customEquals,
      ),
    );
  }

  final cursorOffset = normalized.anchor.offset;
  final anchorBlockId = deletePlan is SameBlockDeletePlan
      ? deletePlan.blockId
      : (deletePlan as CrossBlockDeletePlan).anchorId;
  final kind = deletePlan is SameBlockDeletePlan
      ? deletePlan.kind
      : (deletePlan as CrossBlockDeletePlan).kind;
  final mergedItems = deletePlan is SameBlockDeletePlan
      ? deletePlan.mergedItems
      : (deletePlan as CrossBlockDeletePlan).mergedItems;

  final insertPlan = planInsertTextFullReplace(
    anchorBlockId,
    kind,
    mergedItems,
    cursorOffset,
    text,
    attrs,
    customEquals: customEquals,
  );

  return ReplaceRangePlan(deletePlan: deletePlan, insertPlan: insertPlan);
}
