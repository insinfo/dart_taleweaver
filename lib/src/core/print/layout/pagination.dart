library;

import 'layout_box.dart';
import 'page_box.dart';
import 'page_config.dart';
import 'field_convergence.dart';
import 'template_layout.dart';
import '../../layout/hyphenator.dart';
import '../../layout/text_shaper.dart';
import '../../render/render_node.dart';
import '../../render/render.dart';
import '../../components/component_registry.dart';
import '../../state/state.dart';
import '../../styles/computed_style.dart';
import '../../footnotes/types.dart';
import '../../state/block_id.dart';

class FieldLayoutPass {
  final BlockBox block;
  final Map<String, double> maxValueWidths;
  final BlockBox? headerSlot;
  final BlockBox? footerSlot;

  const FieldLayoutPass({
    required this.block,
    required this.maxValueWidths,
    this.headerSlot,
    this.footerSlot,
  });
}

class ConvergedBlockPagination {
  final List<PageBox> pages;
  final FieldConvergenceOutcome<_PaginationFieldIteration> convergence;

  const ConvergedBlockPagination(
      {required this.pages, required this.convergence});
}

/// Materializes optional rendered template bodies and installs them into the
/// named page slots before ordinary pagination. The render trees are expected
/// to be already cascaded when their styles carry page-specific geometry.
List<PageBox> paginateBlockWithTemplateSlots({
  required BlockBox block,
  required PrintLayoutConfig config,
  RenderNode? headerRender,
  RenderNode? footerRender,
  required TextShaper shaper,
  required ComputedStyle fallbackStyle,
  Hyphenator? hyphenator,
  dynamic computedStyle,
  dynamic usedStyle,
}) {
  final header = headerRender == null
      ? null
      : layoutTemplateRenderNode(
          root: headerRender,
          shaper: shaper,
          inlineSize: config.contentWidth,
          fallbackStyle: fallbackStyle,
          hyphenator: hyphenator);
  final footer = footerRender == null
      ? null
      : layoutTemplateRenderNode(
          root: footerRender,
          shaper: shaper,
          inlineSize: config.contentWidth,
          fallbackStyle: fallbackStyle,
          hyphenator: hyphenator);
  return paginateBlock(
      block: block,
      config: config,
      computedStyle: computedStyle,
      usedStyle: usedStyle,
      headerSlot: header,
      footerSlot: footer);
}

/// Paginates the body once and materializes a distinct template slot for each
/// one-based page. The factories may render page-number/page-count fields with
/// the supplied values before [layoutTemplateRenderNode] measures the slot.
List<PageBox> paginateBlockWithPerPageTemplateSlots({
  required BlockBox block,
  required PrintLayoutConfig config,
  RenderNode? Function(int pageNumber, int pageCount)? headerRenderForPage,
  RenderNode? Function(int pageNumber, int pageCount)? footerRenderForPage,
  required TextShaper shaper,
  required ComputedStyle fallbackStyle,
  Hyphenator? hyphenator,
  dynamic computedStyle,
  dynamic usedStyle,
}) {
  final pages = paginateBlock(
      block: block,
      config: config,
      computedStyle: computedStyle,
      usedStyle: usedStyle);
  final pageCount = pages.length;
  return [
    for (final page in pages)
      createPageBox(
          key: page.key,
          inlineSize: page.inlineSize,
          blockSize: page.blockSize,
          blockOffset: page.blockOffset,
          writingMode: page.writingMode,
          direction: page.direction,
          containingInlineSize: page.inlineSize,
          children: page.children,
          headerSlot: _offsetTemplateSlot(
              _layoutPageTemplate(
                  headerRenderForPage?.call(page.pageIndex + 1, pageCount),
                  shaper,
                  config.contentWidth,
                  fallbackStyle,
                  hyphenator),
              0),
          footerSlot: (() {
            final footer = _layoutPageTemplate(
                footerRenderForPage?.call(page.pageIndex + 1, pageCount),
                shaper,
                config.contentWidth,
                fallbackStyle,
                hyphenator);
            return _offsetTemplateSlot(
                footer, config.contentHeight - (footer?.blockSize ?? 0));
          })(),
          footnoteSlot: page.footnoteSlot,
          pageIndex: page.pageIndex,
          computedStyle: page.computedStyle,
          usedStyle: page.usedStyle,
          effectiveTopInset: page.effectiveTopInset,
          effectiveBottomInset: page.effectiveBottomInset)
  ];
}

/// End-to-end template pagination entry point. Template bodies are read from
/// `State`, rendered with the concrete page number/count, then materialized in
/// the corresponding named slots.
List<PageBox> paginateBlockWithStateTemplateSlots({
  required BlockBox block,
  required PrintLayoutConfig config,
  required State state,
  required ComponentRegistry registry,
  BlockId? headerBodyId,
  BlockId? footerBodyId,
  required TextShaper shaper,
  required ComputedStyle fallbackStyle,
  Hyphenator? hyphenator,
  dynamic computedStyle,
  dynamic usedStyle,
}) {
  var activeConfig = config;
  var lastHeaderHeight = 0.0;
  List<PageBox> materialize() {
    final bodyPages = paginateBlock(
        block: block,
        config: activeConfig,
        computedStyle: computedStyle,
        usedStyle: usedStyle);
    final pageCount = bodyPages.length;
    var maxHeader = 0.0;
    var maxFooter = 0.0;
    final slots = <({BlockBox? header, BlockBox? footer})>[];
    for (final page in bodyPages) {
      final header = headerBodyId == null
          ? null
          : layoutTemplateRenderNode(
              root: renderTemplateBody(state, headerBodyId, registry,
                      pageNumber: page.pageIndex + 1, pageCount: pageCount)
                  .root,
              shaper: shaper,
              inlineSize: activeConfig.contentWidth,
              fallbackStyle: fallbackStyle,
              hyphenator: hyphenator);
      final footer = footerBodyId == null
          ? null
          : layoutTemplateRenderNode(
              root: renderTemplateBody(state, footerBodyId, registry,
                      pageNumber: page.pageIndex + 1, pageCount: pageCount)
                  .root,
              shaper: shaper,
              inlineSize: activeConfig.contentWidth,
              fallbackStyle: fallbackStyle,
              hyphenator: hyphenator);
      if (header != null && header.blockSize > maxHeader) {
        maxHeader = header.blockSize;
      }
      if (footer != null && footer.blockSize > maxFooter) {
        maxFooter = footer.blockSize;
      }
      slots.add((header: header, footer: footer));
    }
    final pages = <PageBox>[];
    for (var i = 0; i < bodyPages.length; i++) {
      final page = bodyPages[i];
      final slot = slots[i];
      pages.add(createPageBox(
          key: page.key,
          inlineSize: page.inlineSize,
          blockSize: page.blockSize,
          blockOffset: page.blockOffset,
          writingMode: page.writingMode,
          direction: page.direction,
          containingInlineSize: activeConfig.pageSize.width,
          children: page.children
              .map((child) => _offsetLayoutBox(child, lastHeaderHeight))
              .toList(),
          headerSlot: _offsetTemplateSlot(slot.header, 0),
          footerSlot: _offsetTemplateSlot(slot.footer,
              activeConfig.contentHeight - (slot.footer?.blockSize ?? 0)),
          footnoteSlot: page.footnoteSlot,
          pageIndex: page.pageIndex,
          computedStyle: page.computedStyle,
          usedStyle: page.usedStyle,
          effectiveTopInset: page.effectiveTopInset,
          effectiveBottomInset: page.effectiveBottomInset));
    }
    final nextMargins = PrintPageMargins(
        top: config.margins.top + maxHeader,
        right: config.margins.right,
        bottom: config.margins.bottom + maxFooter,
        left: config.margins.left);
    lastHeaderHeight = maxHeader;
    activeConfig = PrintLayoutConfig(
        pageSize: config.pageSize,
        margins: nextMargins,
        pageGap: config.pageGap);
    return pages;
  }

  var pages = <PageBox>[];
  for (var pass = 0; pass < 3; pass++) {
    final before = activeConfig;
    pages = materialize();
    if ((before.margins.top - activeConfig.margins.top).abs() < 0.01 &&
        (before.margins.bottom - activeConfig.margins.bottom).abs() < 0.01) {
      break;
    }
  }
  return pages;
}

BlockBox? _offsetTemplateSlot(BlockBox? source, double blockOffset) {
  if (source == null) return null;
  return BlockBox(
      key: source.key,
      inlineOffset: source.inlineOffset,
      blockOffset: blockOffset,
      inlineSize: source.inlineSize,
      blockSize: source.blockSize,
      x: source.x,
      y: blockOffset,
      width: source.width,
      height: source.height,
      writingMode: source.writingMode,
      direction: source.direction,
      computedStyle: source.computedStyle,
      usedStyle: source.usedStyle,
      children: source.children,
      ownerBlockId: source.ownerBlockId);
}

LayoutBox _offsetLayoutBox(LayoutBox source, double delta) {
  if (delta == 0) return source;
  if (source is BlockBox) {
    return _offsetTemplateSlot(source, source.blockOffset + delta)!;
  }
  if (source is LineBox) {
    return LineBox(
        key: source.key,
        inlineOffset: source.inlineOffset,
        blockOffset: source.blockOffset + delta,
        inlineSize: source.inlineSize,
        blockSize: source.blockSize,
        x: source.x,
        y: source.y + delta,
        width: source.width,
        height: source.height,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        children: source.children,
        baseline: source.baseline,
        ownerBlockId: source.ownerBlockId,
        offsetStart: source.offsetStart,
        endsWithHyphen: source.endsWithHyphen);
  }
  if (source is TableBox) {
    // Table descendants use coordinates relative to the table; moving the
    // containing table is therefore sufficient to reserve the header inset
    // without rewriting every row/cell coordinate.
    return TableBox(
        key: source.key,
        inlineOffset: source.inlineOffset,
        blockOffset: source.blockOffset + delta,
        inlineSize: source.inlineSize,
        blockSize: source.blockSize,
        x: source.x,
        y: source.y + delta,
        width: source.width,
        height: source.height,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        children: source.children,
        columnWidths: source.columnWidths,
        rowHeights: source.rowHeights,
        headerRowCount: source.headerRowCount);
  }
  return source;
}

BlockBox? _layoutPageTemplate(RenderNode? render, TextShaper shaper,
    double inlineSize, ComputedStyle fallbackStyle, Hyphenator? hyphenator) {
  if (render == null) return null;
  return layoutTemplateRenderNode(
      root: render,
      shaper: shaper,
      inlineSize: inlineSize,
      fallbackStyle: fallbackStyle,
      hyphenator: hyphenator);
}

class _PaginationFieldIteration extends ConvergenceIteration {
  final List<PageBox> pages;

  _PaginationFieldIteration({
    required this.pages,
    required int pageCount,
    required Map<String, double> maxValueWidthByKey,
  }) : super(pageCount, maxValueWidthByKey);
}

/// Layout and paginate a document repeatedly while page-field reservations
/// converge. The callback owns the actual block/template layout and receives
/// only the overrides used by that pass; the returned pages and convergence
/// outcome always refer to the same final pass.
ConvergedBlockPagination paginateBlockWithFieldConvergence({
  required PrintLayoutConfig config,
  required List<ConvergenceField> fields,
  required FieldLayoutPass Function(Map<String, double> grownWidths) layout,
  int maxIterations = maxFieldConvergenceIterations,
  dynamic computedStyle,
  dynamic usedStyle,
}) {
  final outcome =
      runFieldConvergence<_PaginationFieldIteration>(fields, (grownWidths) {
    final pass = layout(grownWidths);
    final pages = paginateBlock(
        block: pass.block,
        config: config,
        computedStyle: computedStyle,
        usedStyle: usedStyle,
        headerSlot: pass.headerSlot,
        footerSlot: pass.footerSlot);
    return _PaginationFieldIteration(
        pages: pages,
        pageCount: pages.length,
        maxValueWidthByKey: pass.maxValueWidths);
  }, maxIterations: maxIterations);
  return ConvergedBlockPagination(
      pages: outcome.result.pages, convergence: outcome);
}

List<PageBox> paginateBlock(
    {required BlockBox block,
    required PrintLayoutConfig config,
    dynamic computedStyle,
    dynamic usedStyle,
    BlockBox? headerSlot,
    BlockBox? footerSlot}) {
  final pages = <PageBox>[];
  final pageHeight = config.contentHeight;
  var pageChildren = <LayoutBox>[];
  var consumed = 0.0;
  var pageIndex = 0;
  void flush() {
    pages.add(createPageBox(
        key: '${block.key}-page-$pageIndex',
        inlineSize: config.contentWidth,
        blockSize: pageHeight,
        blockOffset: pageIndex * (config.pageSize.height + config.pageGap),
        writingMode: block.writingMode,
        direction: block.direction,
        containingInlineSize: config.pageSize.width,
        children: pageChildren,
        pageIndex: pageIndex,
        computedStyle: computedStyle ?? block.computedStyle,
        usedStyle: usedStyle ?? block.usedStyle,
        headerSlot: headerSlot,
        footerSlot: footerSlot,
        effectiveTopInset: config.margins.top,
        effectiveBottomInset: config.margins.bottom));
    pageIndex++;
    pageChildren = <LayoutBox>[];
    consumed = 0;
  }

  void addChild(LayoutBox child) {
    if (child is BlockBox &&
        child.children.length > 1 &&
        child.blockSize > pageHeight) {
      var start = 0;
      while (start < child.children.length) {
        var end = start;
        var height = 0.0;
        while (end < child.children.length) {
          final item = child.children[end];
          if (end > start && consumed + height + item.blockSize > pageHeight)
            break;
          height += item.blockSize;
          end++;
        }
        addChild(BlockBox(
            key: '${child.key}-fragment-$start',
            inlineOffset: child.inlineOffset,
            blockOffset: child.blockOffset,
            inlineSize: child.inlineSize,
            blockSize: height,
            x: child.x,
            y: child.y,
            width: child.width,
            height: height,
            writingMode: child.writingMode,
            direction: child.direction,
            computedStyle: child.computedStyle,
            usedStyle: child.usedStyle,
            children: child.children.sublist(start, end),
            ownerBlockId: child.ownerBlockId));
        start = end;
      }
      return;
    }
    if (child is! TableBox || child.children.length <= 1) {
      if (pageChildren.isNotEmpty && consumed + child.blockSize > pageHeight) {
        flush();
      }
      pageChildren.add(child);
      consumed += child.blockSize;
      return;
    }
    // Fragment tables at row boundaries when a table crosses a page. Row and
    // cell coordinates remain relative to each fragment, so Canvas consumers
    // retain the same nested geometry while pagination can continue.
    var start = 0;
    while (start < child.children.length) {
      var end = start;
      var height = 0.0;
      final repeatedHeight = start > 0
          ? child.rowHeights
              .take(child.headerRowCount)
              .fold(0.0, (sum, value) => sum + value)
          : 0.0;
      while (end < child.children.length) {
        final rowHeight = end < child.rowHeights.length
            ? child.rowHeights[end]
            : child.children[end].blockSize;
        if (end > start &&
            consumed + repeatedHeight + height + rowHeight > pageHeight) {
          break;
        }
        height += rowHeight;
        end++;
      }
      final repeatHeaders = start > 0
          ? child.children.take(child.headerRowCount).toList()
          : const <LayoutBox>[];
      final repeatHeights = start > 0
          ? child.rowHeights.take(child.headerRowCount).toList()
          : const <double>[];
      final fragmentChildren = [
        ...repeatHeaders,
        ...child.children.sublist(start, end)
      ];
      final fragmentHeights = [
        ...repeatHeights,
        ...child.rowHeights.sublist(start, end)
      ];
      final fragmentSize =
          fragmentHeights.fold(0.0, (sum, value) => sum + value);
      final fragment = TableBox(
          key: '${child.key}-fragment-$start',
          inlineOffset: child.inlineOffset,
          blockOffset: child.blockOffset,
          inlineSize: child.inlineSize,
          blockSize: fragmentSize,
          x: child.x,
          y: child.y,
          width: child.width,
          height: fragmentSize,
          writingMode: child.writingMode,
          direction: child.direction,
          computedStyle: child.computedStyle,
          usedStyle: child.usedStyle,
          children: fragmentChildren,
          columnWidths: child.columnWidths,
          rowHeights: fragmentHeights,
          headerRowCount: child.headerRowCount);
      if (pageChildren.isNotEmpty &&
          consumed + fragment.blockSize > pageHeight) {
        flush();
      }
      pageChildren.add(fragment);
      consumed += fragment.blockSize;
      start = end;
    }
  }

  for (final child in block.children) {
    addChild(child);
  }
  if (pageChildren.isNotEmpty || pages.isEmpty) flush();
  return pages;
}

/// Builds a stable block-to-page index from paginated layout boxes. Nested
/// table/cell/line descendants are included, allowing page cross-references
/// to resolve without coupling the render tree to pagination internals.
Map<BlockId, int> buildPageIndex(Iterable<PageBox> pages) {
  final result = <BlockId, int>{};
  void visit(LayoutBox box, int page) {
    if (box is BlockBox && box.ownerBlockId != null) {
      result.putIfAbsent(box.ownerBlockId!, () => page);
    }
    if (box is LineBox && box.ownerBlockId != null) {
      result.putIfAbsent(box.ownerBlockId!, () => page);
    }
    final children = switch (box) {
      BlockBox(:final children) ||
      TableBox(:final children) ||
      TableRowBox(:final children) ||
      TableCellBox(:final children) ||
      LineBox(:final children) =>
        children,
      _ => const <LayoutBox>[],
    };
    for (final child in children) visit(child, page);
  }

  for (final page in pages) {
    for (final child in page.children) visit(child, page.pageIndex);
    for (final slot in [page.headerSlot, page.footerSlot, page.footnoteSlot]) {
      if (slot != null) visit(slot, page.pageIndex);
    }
  }
  return result;
}

/// Paginates a block and reserves a bottom slot for its footnote bodies.
///
/// Anchors are assigned to the page containing their top-level host block.
/// Bodies that do not fit in the current slot are fragmented at child/line
/// boundaries and carried to following pages; a final continuation page is
/// created when necessary, and no body content is silently dropped.
List<PageBox> paginateBlockWithFootnotes({
  required BlockBox block,
  required PrintLayoutConfig config,
  required Iterable<FootnoteAnchorRef> anchors,
  required Map<BlockId, BlockBox> bodies,
  dynamic computedStyle,
  dynamic usedStyle,
  BlockBox? headerSlot,
  BlockBox? footerSlot,
}) {
  final pages = paginateBlock(
      block: block,
      config: config,
      computedStyle: computedStyle,
      usedStyle: usedStyle,
      headerSlot: headerSlot,
      footerSlot: footerSlot);
  final assigned = <int, List<BlockId>>{};
  for (final anchor in anchors) {
    // Anchors may live below tables, embeds, or other nested layout boxes.
    // Walk each page recursively instead of checking only direct children.
    final pageIndex = anchor.blockId.value == block.key
        ? 0
        : pages.indexWhere(
            (page) => _pageContainsLayoutKey(page, anchor.blockId.value));
    if (pageIndex >= 0 && bodies.containsKey(anchor.contentBlockId)) {
      assigned.putIfAbsent(pageIndex, () => []).add(anchor.contentBlockId);
    }
  }

  final result = <PageBox>[];
  final carry = <BlockId>[];
  var fragmentSerial = 0;
  var pageIndex = 0;
  while (pageIndex < pages.length || carry.isNotEmpty) {
    final source = pageIndex < pages.length ? pages[pageIndex] : null;
    final ids = <BlockId>[...carry, ...?assigned[pageIndex]];
    carry.clear();
    final slot = <LayoutBox>[];
    var usedHeight = 0.0;
    final availableHeight = source == null
        ? config.contentHeight
        : (config.contentHeight - _contentExtent(source))
            .clamp(0.0, config.contentHeight);
    for (final id in ids) {
      final body = bodies[id];
      if (body == null) continue;
      if (usedHeight + body.blockSize > availableHeight) {
        final remaining = availableHeight - usedHeight;
        if (body.children.length > 1 && remaining > 0) {
          var split = 0;
          var splitHeight = 0.0;
          while (split < body.children.length) {
            final child = body.children[split];
            if (split > 0 && splitHeight + child.blockSize > remaining) {
              break;
            }
            splitHeight += child.blockSize;
            split++;
          }
          if (split > 0 && split < body.children.length) {
            final first = _fragmentBlock(
                body, 0, split, splitHeight, '$id-prefix-${fragmentSerial++}');
            final restHeight = body.children
                .skip(split)
                .fold(0.0, (sum, child) => sum + child.blockSize);
            final rest = _fragmentBlock(body, split, body.children.length,
                restHeight, '$id-rest-${fragmentSerial++}');
            final restId = BlockId(rest.key);
            bodies[restId] = rest;
            final top = config.contentHeight - usedHeight - first.blockSize;
            slot.add(_offsetBlock(first, top));
            usedHeight += first.blockSize;
            carry.add(restId);
            continue;
          }
        }
        carry.add(id);
        continue;
      }
      final top = config.contentHeight - usedHeight - body.blockSize;
      slot.add(_offsetBlock(body, top));
      usedHeight += body.blockSize;
    }
    if (source == null) {
      final footnote =
          _makeFootnoteSlot(block, config, slot, usedHeight, pageIndex);
      result.add(createPageBox(
          key: '${block.key}-page-$pageIndex',
          inlineSize: config.contentWidth,
          blockSize: config.contentHeight,
          blockOffset: pageIndex * (config.pageSize.height + config.pageGap),
          writingMode: block.writingMode,
          direction: block.direction,
          containingInlineSize: config.pageSize.width,
          children: const [],
          footnoteSlot: footnote,
          headerSlot: headerSlot,
          footerSlot: footerSlot,
          pageIndex: pageIndex,
          computedStyle: computedStyle ?? block.computedStyle,
          usedStyle: usedStyle ?? block.usedStyle,
          effectiveTopInset: config.margins.top,
          effectiveBottomInset: config.margins.bottom));
    } else {
      final footnote =
          _makeFootnoteSlot(block, config, slot, usedHeight, source.pageIndex);
      result.add(createPageBox(
          key: source.key,
          inlineSize: source.inlineSize,
          blockSize: source.blockSize,
          blockOffset: source.blockOffset,
          writingMode: source.writingMode,
          direction: source.direction,
          containingInlineSize: config.pageSize.width,
          children: source.children,
          footnoteSlot: footnote,
          headerSlot: source.headerSlot ?? headerSlot,
          footerSlot: source.footerSlot ?? footerSlot,
          pageIndex: source.pageIndex,
          computedStyle: source.computedStyle,
          usedStyle: source.usedStyle,
          effectiveTopInset: source.effectiveTopInset,
          effectiveBottomInset: source.effectiveBottomInset));
    }
    pageIndex++;
  }
  return result;
}

bool _containsLayoutKey(LayoutBox box, String key) {
  if (box.key == key) return true;
  if (box is BlockBox && box.ownerBlockId?.value == key) return true;
  if (box is LineBox && box.ownerBlockId?.value == key) return true;
  final children = switch (box) {
    BlockBox(:final children) ||
    TableBox(:final children) ||
    TableRowBox(:final children) ||
    TableCellBox(:final children) ||
    LineBox(:final children) =>
      children,
    _ => const <LayoutBox>[],
  };
  return children.any((child) => _containsLayoutKey(child, key));
}

double _contentExtent(PageBox page) {
  var extent = 0.0;
  for (final child in page.children) {
    // A legacy page may flatten the same bodies that are also exposed through
    // footnoteSlot; the named slot must not reduce the body content band.
    final namedSlots = [page.headerSlot, page.footerSlot, page.footnoteSlot];
    if (namedSlots.any((slot) =>
        slot != null &&
        slot.children.any((slotChild) => identical(slotChild, child)))) {
      continue;
    }
    final childExtent = child.blockOffset + child.blockSize;
    if (childExtent > extent) extent = childExtent;
  }
  return extent;
}

bool _pageContainsLayoutKey(PageBox page, String key) {
  final seen = <LayoutBox>{};
  final candidates = <LayoutBox>[...page.children];
  candidates.addAll([
    if (page.headerSlot != null) page.headerSlot!,
    if (page.footerSlot != null) page.footerSlot!,
    if (page.footnoteSlot != null) page.footnoteSlot!,
  ]);
  return candidates.any((child) {
    if (!seen.add(child)) return false;
    return _containsLayoutKey(child, key);
  });
}

BlockBox _offsetBlock(BlockBox source, double blockOffset) => BlockBox(
    key: source.key,
    inlineOffset: source.inlineOffset,
    blockOffset: blockOffset,
    inlineSize: source.inlineSize,
    blockSize: source.blockSize,
    x: source.x,
    y: blockOffset,
    width: source.width,
    height: source.height,
    writingMode: source.writingMode,
    direction: source.direction,
    computedStyle: source.computedStyle,
    usedStyle: source.usedStyle,
    children: source.children,
    ownerBlockId: source.ownerBlockId);

BlockBox _fragmentBlock(
        BlockBox source, int start, int end, double blockSize, String key) =>
    BlockBox(
        key: key,
        inlineOffset: source.inlineOffset,
        blockOffset: source.blockOffset,
        inlineSize: source.inlineSize,
        blockSize: blockSize,
        x: source.x,
        y: source.y,
        width: source.width,
        height: blockSize,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        children: source.children.sublist(start, end),
        ownerBlockId: source.ownerBlockId);

BlockBox? _makeFootnoteSlot(BlockBox owner, PrintLayoutConfig config,
    List<LayoutBox> children, double height, int pageIndex) {
  if (children.isEmpty) return null;
  final blockSize = height.clamp(0.0, config.contentHeight);
  final blockOffset = config.contentHeight - blockSize;
  return BlockBox(
    key: '${owner.key}-page-$pageIndex-footnote-slot',
    inlineOffset: 0,
    blockOffset: blockOffset,
    inlineSize: config.contentWidth,
    blockSize: blockSize,
    x: 0,
    y: blockOffset,
    width: config.contentWidth,
    height: blockSize,
    writingMode: owner.writingMode,
    direction: owner.direction,
    computedStyle: owner.computedStyle,
    usedStyle: owner.usedStyle,
    children: children,
  );
}
