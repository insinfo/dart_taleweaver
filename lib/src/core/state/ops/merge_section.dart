/// Merge section with previous.
///
/// Port of `ops/merge-section.ts`.
library;

import '../block_id.dart';
import '../state.dart';
import 'reparent_children.dart';

OperationResult mergeSectionWithPrevious(
  State state,
  BlockId sectionId,
) {
  final section = getBlock(state, sectionId);
  if (section == null) {
    throw StateError('mergeSectionWithPrevious: section "$sectionId" not found');
  }
  if (section.type != 'section' || section.parentId != state.rootId) {
    throw StateError('mergeSectionWithPrevious: block "$sectionId" is not a flat doc-root section');
  }

  final pId = section.prevSiblingId;
  if (pId == null) {
    return OperationResult(state: state, dirtyIds: {});
  }

  final prevSection = getBlock(state, pId);
  if (prevSection == null || prevSection.type != 'section') {
    throw StateError('mergeSectionWithPrevious: previous sibling "$pId" is not a section');
  }

  final movedChildren = <BlockId>[];
  var cur = section.firstChildId;
  var guard = 0;
  // Use a reasonable max steps limit for our Dart version
  final maxSteps = 10000;
  while (cur != null) {
    if (++guard > maxSteps) {
      throw StateError('mergeSectionWithPrevious: cycle detected');
    }
    movedChildren.add(cur);
    final b = getBlock(state, cur);
    if (b == null) {
      throw StateError('mergeSectionWithPrevious: child "$cur" not found');
    }
    cur = b.nextSiblingId;
  }

  final sectionNextSiblingId = section.nextSiblingId;

  ReparentPlan? plan;
  if (movedChildren.isNotEmpty) {
    plan = ReparentPlan(
      computeReparentWrites(ComputeReparentWritesOpts(
        moved: movedChildren,
        sourceParentId: sectionId,
        sourceFirstChildId: section.firstChildId,
        sourceLastChildId: section.lastChildId,
        movedPrevSiblingId: null,
        movedNextSiblingId: null,
        newParentId: pId,
        newParentLastChildId: prevSection.lastChildId,
        beforeSiblingId: null,
        beforeSiblingPrevId: null,
      )),
    );
  }

  return applyOperation(state, (doc) {
    if (plan != null) {
      reparentChildrenInTx(doc, plan);
    }

    final yPrev = doc.getBlockMap(pId.value);
    if (yPrev != null) {
      yPrev['nextSiblingId'] = sectionNextSiblingId?.value;
      doc.markDirty(pId.value);
    }

    if (sectionNextSiblingId != null) {
      final yNext = doc.getBlockMap(sectionNextSiblingId.value);
      if (yNext != null) {
        yNext['prevSiblingId'] = pId.value;
        doc.markDirty(sectionNextSiblingId.value);
      }
    } else {
      doc.meta['lastChildId'] = pId.value;
      final yRoot = doc.getBlockMap(state.rootId.value);
      if (yRoot != null) {
        yRoot['lastChildId'] = pId.value;
        doc.markDirty(state.rootId.value);
      }
    }

    doc.deleteBlock(sectionId.value);
  });
}
