library;

import '../../state/block_id.dart';
import '../../styles/writing_mode.dart';

abstract class LayoutBox {
  final String type;
  final String key;
  final double inlineOffset;
  final double blockOffset;
  final double inlineSize;
  final double blockSize;
  final double x;
  final double y;
  final double width;
  final double height;
  final WritingMode writingMode;
  final Direction direction;
  final dynamic computedStyle;
  final dynamic usedStyle;

  const LayoutBox(
      {required this.type,
      required this.key,
      required this.inlineOffset,
      required this.blockOffset,
      required this.inlineSize,
      required this.blockSize,
      required this.x,
      required this.y,
      required this.width,
      required this.height,
      required this.writingMode,
      required this.direction,
      this.computedStyle,
      this.usedStyle});
}

class BlockBox extends LayoutBox {
  final List<LayoutBox> children;
  final BlockId? ownerBlockId;
  const BlockBox(
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
      this.ownerBlockId})
      : super(type: 'block');
}

class TableBox extends LayoutBox {
  final List<LayoutBox> children;
  final List<double> columnWidths;
  final List<double> rowHeights;
  final int headerRowCount;

  const TableBox({
    required super.key,
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
    this.columnWidths = const [],
    this.rowHeights = const [],
    this.headerRowCount = 0,
  }) : super(type: 'table');
}

class TableRowBox extends LayoutBox {
  final List<LayoutBox> children;

  const TableRowBox({
    required super.key,
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
  }) : super(type: 'table-row');
}

class TableCellBox extends LayoutBox {
  final List<LayoutBox> children;
  final int rowSpan;
  final int colSpan;

  const TableCellBox({
    required super.key,
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
    this.rowSpan = 1,
    this.colSpan = 1,
  }) : super(type: 'table-cell');
}

class TextRunBox extends LayoutBox {
  final String text;
  final int offsetLength;
  const TextRunBox(
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
      required this.text,
      this.offsetLength = 0})
      : super(type: 'text-run');
}

/// Replaced inline image box used by the Canvas backend.
class ImageBox extends LayoutBox {
  final String src;
  final String? alt;

  const ImageBox({
    required super.key,
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
    required this.src,
    this.alt,
  }) : super(type: 'image');
}

class LineBox extends LayoutBox {
  final List<LayoutBox> children;
  final double baseline;
  final BlockId? ownerBlockId;

  /// UTF-16 offset of the first text run on this visual line.
  final int offsetStart;

  /// Whether wrapping inserted a synthetic hyphen at this line's end.
  final bool endsWithHyphen;
  const LineBox(
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
      this.baseline = 0,
      this.ownerBlockId,
      this.offsetStart = 0,
      this.endsWithHyphen = false})
      : super(type: 'line');
}
