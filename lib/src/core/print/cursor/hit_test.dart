library;

import '../../state/block_position.dart';
import '../../state/block_id.dart';
import '../../state/state.dart';
import '../../cursor/selection.dart';
import '../layout/layout_box.dart';
import '../layout/page_box.dart';
import '../../styles/writing_mode.dart';

/// Physical rectangle for an atomic block (image or horizontal rule).
/// Coordinates use the same page space as [hitTestPage] and Canvas painting.
class AtomicBlockRect {
  final BlockId blockId;
  final double x;
  final double y;
  final double width;
  final double height;
  final int pageIndex;

  const AtomicBlockRect({
    required this.blockId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageIndex,
  });
}

/// Builds an object-selection index for atomic blocks on one page.
///
/// Atomic blocks do not produce [LineBox] children, so ordinary text hit-test
/// would otherwise fall through to a nearby caret. The index is deliberately
/// state-aware: a layout key is accepted only when it resolves to a live image
/// or horizontal-line block.
Map<BlockId, AtomicBlockRect> atomicBlockIndex(PageBox page, State state) {
  final result = <BlockId, AtomicBlockRect>{};
  for (final child in _pageChildrenForCursor(page)) {
    _collectAtomicBlocks(child, page.x, page.y, page.pageIndex, state, result);
  }
  return result;
}

void _collectAtomicBlocks(LayoutBox box, double parentX, double parentY,
    int pageIndex, State state, Map<BlockId, AtomicBlockRect> out) {
  final x = parentX + box.x;
  final y = parentY + box.y;
  if (box is BlockBox) {
    final id = BlockId(box.key);
    final block = getBlock(state, id);
    if (block != null &&
        (block.type == 'image' || block.type == 'horizontal-line')) {
      out[id] = AtomicBlockRect(
          blockId: id,
          x: x,
          y: y,
          width: box.width,
          height: box.height,
          pageIndex: pageIndex);
      return;
    }
  }
  final children = switch (box) {
    BlockBox(:final children) => children,
    LineBox(:final children) => children,
    TableBox(:final children) => children,
    TableRowBox(:final children) => children,
    TableCellBox(:final children) => children,
    _ => const <LayoutBox>[],
  };
  for (final child in children) {
    _collectAtomicBlocks(child, x, y, pageIndex, state, out);
  }
}

/// Returns the atomic block hit by a physical point, if any.
BlockId? hitTestAtomicBlock(PageBox page, State state, double x, double y) {
  final entries = atomicBlockIndex(page, state).values.toList().reversed;
  for (final rect in entries) {
    if (x >= rect.x &&
        x < rect.x + rect.width &&
        y >= rect.y &&
        y < rect.y + rect.height) {
      return rect.blockId;
    }
  }
  return null;
}

class CaretRect {
  final double x;
  final double y;
  final double height;
  const CaretRect(this.x, this.y, this.height);
}

class SelectionRect {
  final double x;
  final double y;
  final double width;
  final double height;
  const SelectionRect(this.x, this.y, this.width, this.height);
}

/// Include a named footnote slot when a PageBox uses the modern shape, while
/// avoiding duplicate traversal for legacy pages that already flatten its
/// children into [PageBox.children].
List<LayoutBox> _pageChildrenForCursor(PageBox page) {
  final result = <LayoutBox>[...page.children];
  for (final slot in [page.headerSlot, page.footerSlot, page.footnoteSlot]) {
    if (slot == null) continue;
    final flattened = slot.children.any(
        (child) => page.children.any((existing) => identical(existing, child)));
    if (!flattened) result.add(slot);
  }
  return result;
}

Position? hitTestPage(PageBox page, double x, double y, {State? state}) {
  if (state != null) {
    final atomic = hitTestAtomicBlock(page, state, x, y);
    if (atomic != null) return Position(blockId: atomic, offset: 0);
  }
  for (final child in _pageChildrenForCursor(page).reversed) {
    final hit = _hitTestText(child, page.x, page.y, x, y);
    if (hit != null) return hit;
  }
  return null;
}

Position? _hitTestText(
    LayoutBox box, double parentX, double parentY, double x, double y) {
  final boxX = parentX + box.x;
  final boxY = parentY + box.y;
  if (box is LineBox) {
    final vertical = box.writingMode != WritingMode.horizontalTb;
    if (box.ownerBlockId == null ||
        x < boxX ||
        x > boxX + box.width ||
        y < boxY ||
        y > boxY + box.height) {
      return null;
    }
    var offset = box.offsetStart;
    final runs = box.children.whereType<TextRunBox>().toList();
    for (var index = 0; index < runs.length; index++) {
      final leaf = runs[index];
      final start = vertical ? boxY + leaf.y : boxX + leaf.x;
      final extent = vertical ? leaf.height : leaf.width;
      final coordinate = vertical ? y : x;
      final right = start + extent;
      if (coordinate > right && index < runs.length - 1) {
        offset += leaf.offsetLength;
        continue;
      }
      final inlineReversed = vertical
          ? box.direction == Direction.rtl
          : leaf.direction == Direction.rtl;
      final localX = (!inlineReversed ? coordinate - start : right - coordinate)
          .clamp(0, extent);
      final units = leaf.text.isEmpty || extent <= 0
          ? 0
          : (localX / extent * leaf.offsetLength).round();
      return Position(
          blockId: box.ownerBlockId!,
          offset: (offset + units).clamp(offset, offset + leaf.offsetLength));
    }
    if (runs.isNotEmpty) {
      final lastRun = runs.last;
      return Position(
          blockId: box.ownerBlockId!,
          offset: offset.clamp(
              box.offsetStart, box.offsetStart + lastRun.offsetLength));
    }
    return Position(blockId: box.ownerBlockId!, offset: box.offsetStart);
  }
  final children = switch (box) {
    BlockBox(:final children) => children,
    TableBox(:final children) => children,
    TableRowBox(:final children) => children,
    TableCellBox(:final children) => children,
    _ => const <LayoutBox>[],
  };
  for (final child in children.reversed) {
    final hit = _hitTestText(child, boxX, boxY, x, y);
    if (hit != null) return hit;
  }
  return null;
}

/// Returns the deepest image box containing the physical point, or `null`.
/// Coordinates are interpreted in the same page space used by Canvas
/// painting, and nested table/cell boxes are traversed recursively.
ImageBox? hitTestImage(PageBox page, double x, double y) {
  for (final child in _pageChildrenForCursor(page).reversed) {
    final hit = _hitTestImage(child, page.x, page.y, x, y);
    if (hit != null) return hit;
  }
  return null;
}

ImageBox? _hitTestImage(
    LayoutBox box, double parentX, double parentY, double x, double y) {
  final left = parentX + box.x;
  final top = parentY + box.y;
  if (box is ImageBox) {
    final inside =
        x >= left && x <= left + box.width && y >= top && y <= top + box.height;
    return inside ? box : null;
  }
  final children = switch (box) {
    BlockBox(:final children) => children,
    LineBox(:final children) => children,
    TableBox(:final children) => children,
    TableRowBox(:final children) => children,
    TableCellBox(:final children) => children,
    _ => const <LayoutBox>[],
  };
  for (final child in children.reversed) {
    final hit = _hitTestImage(child, left, top, x, y);
    if (hit != null) return hit;
  }
  return null;
}

CaretRect? caretRectForPosition(PageBox page, Position position,
    [CaretAffinity? affinity]) {
  for (final child in _pageChildrenForCursor(page)) {
    final caret =
        _caretInBox(child, page.x, page.y, position, affinity ?? 'before');
    if (caret != null) return caret;
  }
  return null;
}

CaretRect? _caretInBox(LayoutBox box, double parentX, double parentY,
    Position position, CaretAffinity affinity) {
  final boxX = parentX + box.x;
  final boxY = parentY + box.y;
  if (box is LineBox) {
    if (box.ownerBlockId != position.blockId) return null;
    final vertical = box.writingMode != WritingMode.horizontalTb;
    var offset = box.offsetStart;
    for (final leaf in box.children) {
      if (leaf is! TextRunBox) continue;
      final end = offset + leaf.offsetLength;
      if (position.offset < end ||
          (position.offset == end && affinity != 'after')) {
        final fraction = leaf.offsetLength == 0
            ? 0.0
            : ((position.offset - offset) / leaf.offsetLength).clamp(0.0, 1.0);
        final inlineReversed = vertical
            ? box.direction == Direction.rtl
            : leaf.direction == Direction.rtl;
        final visualFraction = inlineReversed ? 1 - fraction : fraction;
        final local = vertical
            ? leaf.height * visualFraction
            : leaf.width * visualFraction;
        return CaretRect(
            vertical ? boxY + leaf.y + local : boxX + leaf.x + local,
            vertical ? boxX : boxY,
            vertical ? leaf.width : box.height);
      }
      offset = end;
    }
    if (position.offset == offset && affinity != 'after') {
      return vertical
          ? CaretRect(boxY + box.height, boxX, box.width)
          : CaretRect(boxX + box.width, boxY, box.height);
    }
    return null;
  }
  final children = switch (box) {
    BlockBox(:final children) => children,
    TableBox(:final children) => children,
    TableRowBox(:final children) => children,
    TableCellBox(:final children) => children,
    _ => const <LayoutBox>[],
  };
  for (final child in children) {
    final caret = _caretInBox(child, boxX, boxY, position, affinity);
    if (caret != null) return caret;
  }
  return null;
}

/// Returns the highlight rectangle for a same-block selection on one line.
/// Multi-line selection fragmentation remains a responsibility of pagination.
SelectionRect? selectionRectForRange(
    PageBox page, Position anchor, Position focus) {
  final rects = selectionRectsForRange(page, anchor, focus);
  return rects.length == 1 ? rects.single : null;
}

/// Returns one highlight rectangle per visual line for a same-block range on
/// this page. Offsets are UTF-16 and are accumulated across text runs in the
/// order produced by IFC. A range that spans another page naturally returns
/// only the fragments present on this page.
List<SelectionRect> selectionRectsForRange(
    PageBox page, Position anchor, Position focus) {
  if (anchor.blockId != focus.blockId || anchor.offset == focus.offset) {
    return const [];
  }
  final startOffset =
      anchor.offset < focus.offset ? anchor.offset : focus.offset;
  final endOffset = anchor.offset < focus.offset ? focus.offset : anchor.offset;
  final rects = <SelectionRect>[];
  final lines = <_LinePlacement>[];
  for (final child in _pageChildrenForCursor(page)) {
    _collectLines(child, page.x, page.y, lines);
  }
  for (final placement in lines) {
    final child = placement.line;
    if (child.ownerBlockId != anchor.blockId) continue;
    final lineStart = child.offsetStart;
    final lineLength = child.children
        .whereType<TextRunBox>()
        .fold<int>(0, (sum, run) => sum + run.offsetLength);
    final lineEnd = lineStart + lineLength;
    final overlapStart = startOffset > lineStart ? startOffset : lineStart;
    final overlapEnd = endOffset < lineEnd ? endOffset : lineEnd;
    if (overlapStart < overlapEnd) {
      if (child.writingMode == WritingMode.horizontalTb) {
        final left =
            _lineXForOffset(placement.x, child, lineStart, overlapStart);
        final right =
            _lineXForOffset(placement.x, child, lineStart, overlapEnd);
        final rectLeft = left < right ? left : right;
        rects.add(SelectionRect(
          rectLeft,
          placement.y,
          (right - left).abs(),
          child.height,
        ));
      } else {
        final top =
            _lineInlineForOffset(placement.y, child, lineStart, overlapStart);
        final bottom =
            _lineInlineForOffset(placement.y, child, lineStart, overlapEnd);
        final rectTop = top < bottom ? top : bottom;
        rects.add(SelectionRect(
          placement.x,
          rectTop,
          child.width,
          (bottom - top).abs(),
        ));
      }
    }
  }
  return rects;
}

class _LinePlacement {
  final LineBox line;
  final double x;
  final double y;

  const _LinePlacement(this.line, this.x, this.y);
}

void _collectLines(
    LayoutBox box, double parentX, double parentY, List<_LinePlacement> out) {
  final x = parentX + box.x;
  final y = parentY + box.y;
  if (box is LineBox) {
    out.add(_LinePlacement(box, x, y));
    return;
  }
  final children = switch (box) {
    BlockBox(:final children) => children,
    TableBox(:final children) => children,
    TableRowBox(:final children) => children,
    TableCellBox(:final children) => children,
    _ => const <LayoutBox>[],
  };
  for (final child in children) {
    _collectLines(child, x, y, out);
  }
}

/// Fragments a selection across all supplied pages, preserving document/page
/// order. Each rectangle remains in the coordinate space of its [PageBox],
/// matching the Canvas renderer's per-page painting contract.
List<SelectionRect> selectionRectsAcrossPages(
    Iterable<PageBox> pages, Position anchor, Position focus) {
  final pageList = List<PageBox>.of(pages);
  if (anchor.blockId == focus.blockId) {
    return [
      for (final page in pageList)
        ...selectionRectsForRange(page, anchor, focus),
    ];
  }
  final lines = <_PlacedPageLine>[];
  final blockOrder = <BlockId>[];
  final seen = <BlockId>{};
  for (final page in pageList) {
    final pageLines = <_LinePlacement>[];
    for (final child in _pageChildrenForCursor(page)) {
      _collectLines(child, page.x, page.y, pageLines);
    }
    for (final placement in pageLines) {
      final owner = placement.line.ownerBlockId;
      if (owner == null) continue;
      if (seen.add(owner)) blockOrder.add(owner);
      lines.add(_PlacedPageLine(page, placement));
    }
  }
  final anchorIndex = blockOrder.indexOf(anchor.blockId);
  final focusIndex = blockOrder.indexOf(focus.blockId);
  if (anchorIndex < 0 || focusIndex < 0) return const [];
  final forward = anchorIndex < focusIndex;
  final firstBlock = forward ? anchor.blockId : focus.blockId;
  final lastBlock = forward ? focus.blockId : anchor.blockId;
  final firstIndex = forward ? anchorIndex : focusIndex;
  final lastIndex = forward ? focusIndex : anchorIndex;
  final firstOffset = forward ? anchor.offset : focus.offset;
  final lastOffset = forward ? focus.offset : anchor.offset;
  final result = <SelectionRect>[];
  for (final placed in lines) {
    final line = placed.placement.line;
    final owner = line.ownerBlockId!;
    final index = blockOrder.indexOf(owner);
    if (index < firstIndex || index > lastIndex) continue;
    final lineStart = line.offsetStart;
    final lineLength = line.children
        .whereType<TextRunBox>()
        .fold<int>(0, (sum, run) => sum + run.offsetLength);
    final lineEnd = lineStart + lineLength;
    final rangeStart = owner == firstBlock ? firstOffset : lineStart;
    final rangeEnd = owner == lastBlock ? lastOffset : lineEnd;
    final overlapStart = rangeStart > lineStart ? rangeStart : lineStart;
    final overlapEnd = rangeEnd < lineEnd ? rangeEnd : lineEnd;
    if (overlapStart >= overlapEnd) continue;
    if (line.writingMode == WritingMode.horizontalTb) {
      final left =
          _lineXForOffset(placed.placement.x, line, lineStart, overlapStart);
      final right =
          _lineXForOffset(placed.placement.x, line, lineStart, overlapEnd);
      final rectLeft = left < right ? left : right;
      result.add(SelectionRect(
          rectLeft, placed.placement.y, (right - left).abs(), line.height));
    } else {
      final top = _lineInlineForOffset(
          placed.placement.y, line, lineStart, overlapStart);
      final bottom =
          _lineInlineForOffset(placed.placement.y, line, lineStart, overlapEnd);
      final rectTop = top < bottom ? top : bottom;
      result.add(SelectionRect(
          placed.placement.x, rectTop, line.width, (bottom - top).abs()));
    }
  }
  return result;
}

class _PlacedPageLine {
  final PageBox page;
  final _LinePlacement placement;

  const _PlacedPageLine(this.page, this.placement);
}

double _lineXForOffset(
    double lineX, LineBox line, int lineStart, int absoluteOffset) {
  var offset = lineStart;
  for (final child in line.children) {
    if (child is! TextRunBox) continue;
    final end = offset + child.offsetLength;
    if (absoluteOffset <= end) {
      final within = absoluteOffset - offset;
      final fraction = child.offsetLength == 0
          ? 0.0
          : (within / child.offsetLength).clamp(0.0, 1.0);
      final visualFraction =
          child.direction == Direction.rtl ? 1 - fraction : fraction;
      return lineX + child.x + child.width * visualFraction;
    }
    offset = end;
  }
  return lineX + line.width;
}

double _lineInlineForOffset(
    double lineY, LineBox line, int lineStart, int absoluteOffset) {
  var offset = lineStart;
  for (final child in line.children) {
    if (child is! TextRunBox) continue;
    final end = offset + child.offsetLength;
    if (absoluteOffset <= end) {
      final within = absoluteOffset - offset;
      final fraction = child.offsetLength == 0
          ? 0.0
          : (within / child.offsetLength).clamp(0.0, 1.0);
      final visualFraction =
          line.direction == Direction.rtl ? 1 - fraction : fraction;
      return lineY + child.y + child.height * visualFraction;
    }
    offset = end;
  }
  return lineY + line.height;
}
