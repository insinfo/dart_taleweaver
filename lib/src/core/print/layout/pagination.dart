library;

import 'layout_box.dart';
import 'page_box.dart';
import 'page_config.dart';

List<PageBox> paginateBlock(
    {required BlockBox block,
    required PrintLayoutConfig config,
    dynamic computedStyle,
    dynamic usedStyle}) {
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
        effectiveTopInset: config.margins.top,
        effectiveBottomInset: config.margins.bottom));
    pageIndex++;
    pageChildren = <LayoutBox>[];
    consumed = 0;
  }

  for (final child in block.children) {
    if (pageChildren.isNotEmpty && consumed + child.blockSize > pageHeight)
      flush();
    pageChildren.add(child);
    consumed += child.blockSize;
  }
  if (pageChildren.isNotEmpty || pages.isEmpty) flush();
  return pages;
}
