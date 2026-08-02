/// Writing mode and text direction.
///
/// Port of `styles/writing-mode.ts`.
library;

/// CSS `writing-mode` values.
enum WritingMode {
  horizontalTb,
  verticalRl,
  verticalLr;

  String get value {
    switch (this) {
      case WritingMode.horizontalTb: return 'horizontal-tb';
      case WritingMode.verticalRl: return 'vertical-rl';
      case WritingMode.verticalLr: return 'vertical-lr';
    }
  }

  static WritingMode fromString(String val) {
    switch (val) {
      case 'horizontal-tb': return WritingMode.horizontalTb;
      case 'vertical-rl': return WritingMode.verticalRl;
      case 'vertical-lr': return WritingMode.verticalLr;
      default: throw ArgumentError('Unhandled writing mode: $val');
    }
  }
}

/// CSS `direction` values.
enum Direction {
  ltr,
  rtl;

  String get value {
    switch (this) {
      case Direction.ltr: return 'ltr';
      case Direction.rtl: return 'rtl';
    }
  }

  static Direction fromString(String val) {
    switch (val) {
      case 'ltr': return Direction.ltr;
      case 'rtl': return Direction.rtl;
      default: throw ArgumentError('Unhandled direction: $val');
    }
  }
}

/// A rectangle in the logical coordinate system.
class LogicalRect {
  final double inlineOffset;
  final double blockOffset;
  final double inlineSize;
  final double blockSize;

  const LogicalRect({
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineSize,
    required this.blockSize,
  });
}

/// A rectangle in the physical coordinate system.
class PhysicalRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const PhysicalRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Map a logical rect to a physical rect based on writing-mode + direction.
PhysicalRect logicalToPhysical(
  LogicalRect logical,
  WritingMode writingMode,
  Direction direction,
  double containingInlineSize, [
  double? containingBlockSize,
]) {
  switch (writingMode) {
    case WritingMode.horizontalTb:
      if (direction == Direction.ltr) {
        return PhysicalRect(
          x: logical.inlineOffset,
          y: logical.blockOffset,
          width: logical.inlineSize,
          height: logical.blockSize,
        );
      }
      return PhysicalRect(
        x: containingInlineSize - logical.inlineOffset - logical.inlineSize,
        y: logical.blockOffset,
        width: logical.inlineSize,
        height: logical.blockSize,
      );
    case WritingMode.verticalLr:
    case WritingMode.verticalRl:
      final y = direction == Direction.ltr
          ? logical.inlineOffset
          : containingInlineSize - logical.inlineOffset - logical.inlineSize;

      final x = writingMode == WritingMode.verticalLr
          ? logical.blockOffset
          : (containingBlockSize == null || containingBlockSize.isInfinite || containingBlockSize.isNaN
              ? logical.blockOffset
              : containingBlockSize - logical.blockOffset - logical.blockSize);

      return PhysicalRect(
        x: x,
        y: y,
        width: logical.blockSize,
        height: logical.inlineSize,
      );
  }
}

/// Exact inverse of `logicalToPhysical`.
LogicalRect physicalToLogical(
  PhysicalRect physical,
  WritingMode writingMode,
  Direction direction,
  double containingInlineSize, [
  double? containingBlockSize,
]) {
  if (writingMode == WritingMode.horizontalTb) {
    if (direction == Direction.ltr) {
      return LogicalRect(
        inlineOffset: physical.x,
        blockOffset: physical.y,
        inlineSize: physical.width,
        blockSize: physical.height,
      );
    }
    return LogicalRect(
      inlineOffset: containingInlineSize - physical.x - physical.width,
      blockOffset: physical.y,
      inlineSize: physical.width,
      blockSize: physical.height,
    );
  }

  final inlineSize = physical.height;
  final blockSize = physical.width;

  final inlineOffset = direction == Direction.ltr
      ? physical.y
      : containingInlineSize - physical.y - inlineSize;

  double blockOffset;
  if (writingMode == WritingMode.verticalLr) {
    blockOffset = physical.x;
  } else {
    blockOffset = (containingBlockSize == null || containingBlockSize.isInfinite || containingBlockSize.isNaN)
        ? physical.x
        : containingBlockSize - physical.x - blockSize;
  }

  return LogicalRect(
    inlineOffset: inlineOffset,
    blockOffset: blockOffset,
    inlineSize: inlineSize,
    blockSize: blockSize,
  );
}

/// Which physical axis each logical axis maps to.
class AxisMap {
  final String inline; // 'x' or 'y'
  final String block; // 'x' or 'y'
  final bool inlineReversed;

  const AxisMap({
    required this.inline,
    required this.block,
    required this.inlineReversed,
  });
}

/// The consumer-facing axis selector.
AxisMap axisMapFor(WritingMode writingMode, Direction direction) {
  final inlineReversed = direction == Direction.rtl;
  if (writingMode == WritingMode.horizontalTb) {
    return AxisMap(inline: 'x', block: 'y', inlineReversed: inlineReversed);
  }
  return AxisMap(inline: 'y', block: 'x', inlineReversed: inlineReversed);
}
