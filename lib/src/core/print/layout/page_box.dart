library;

import '../../styles/writing_mode.dart';
import 'layout_box.dart';

class PageBox extends LayoutBox {
  final List<LayoutBox> children;
  final int pageIndex;
  final double effectiveTopInset;
  final double effectiveBottomInset;

  const PageBox(
      {required super.key,
      required super.inlineOffset,
      required super.blockOffset,
      required super.inlineSize,
      required super.blockSize,
      required super.x,
      required super.y,
      required super.width,
      required super.height,
      required super.writingMode,
      required super.direction,
      super.computedStyle,
      super.usedStyle,
      this.children = const [],
      required this.pageIndex,
      required this.effectiveTopInset,
      required this.effectiveBottomInset})
      : super(type: 'page');
}

PageBox createPageBox(
    {required String key,
    required double inlineSize,
    required double blockSize,
    required double blockOffset,
    required WritingMode writingMode,
    required Direction direction,
    required double containingInlineSize,
    required List<LayoutBox> children,
    required int pageIndex,
    dynamic computedStyle,
    dynamic usedStyle,
    double effectiveTopInset = 0,
    double effectiveBottomInset = 0}) {
  final physical = logicalToPhysical(
      LogicalRect(
          inlineOffset: 0,
          blockOffset: blockOffset,
          inlineSize: inlineSize,
          blockSize: blockSize),
      writingMode,
      direction,
      containingInlineSize);
  return PageBox(
      key: key,
      inlineOffset: 0,
      blockOffset: blockOffset,
      inlineSize: inlineSize,
      blockSize: blockSize,
      x: physical.x,
      y: physical.y,
      width: physical.width,
      height: physical.height,
      writingMode: writingMode,
      direction: direction,
      computedStyle: computedStyle,
      usedStyle: usedStyle,
      children: List.unmodifiable(children),
      pageIndex: pageIndex,
      effectiveTopInset: effectiveTopInset,
      effectiveBottomInset: effectiveBottomInset);
}
