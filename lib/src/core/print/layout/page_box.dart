library;

import '../../styles/writing_mode.dart';
import 'layout_box.dart';

class PageBox extends LayoutBox {
  final List<LayoutBox> children;

  /// Named template-body slots. They remain nullable until the template
  /// layout producer supplies the active section's header/footer bodies.
  final BlockBox? headerSlot;
  final BlockBox? footerSlot;

  /// Named footnote band, kept out of [children] so painting, line collection
  /// and hit-testing can distinguish body content from the bottom slot.
  final BlockBox? footnoteSlot;
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
      this.headerSlot,
      this.footerSlot,
      this.footnoteSlot,
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
    BlockBox? headerSlot,
    BlockBox? footerSlot,
    BlockBox? footnoteSlot,
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
      headerSlot: headerSlot,
      footerSlot: footerSlot,
      footnoteSlot: footnoteSlot,
      pageIndex: pageIndex,
      effectiveTopInset: effectiveTopInset,
      effectiveBottomInset: effectiveBottomInset);
}
