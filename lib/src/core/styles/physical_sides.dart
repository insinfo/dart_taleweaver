/// Logical to physical sides mapping.
///
/// Port of `styles/physical-sides.ts`.
library;

import 'color.dart';
import 'style.dart';
import 'used_style.dart';
import 'writing_mode.dart';

class PhysicalBorderSides {
  final double topWidth;
  final double rightWidth;
  final double bottomWidth;
  final double leftWidth;

  final BorderStyle topStyle;
  final BorderStyle rightStyle;
  final BorderStyle bottomStyle;
  final BorderStyle leftStyle;

  final Color topColor;
  final Color rightColor;
  final Color bottomColor;
  final Color leftColor;

  final double topPadding;
  final double rightPadding;
  final double bottomPadding;
  final double leftPadding;

  const PhysicalBorderSides({
    required this.topWidth,
    required this.rightWidth,
    required this.bottomWidth,
    required this.leftWidth,
    required this.topStyle,
    required this.rightStyle,
    required this.bottomStyle,
    required this.leftStyle,
    required this.topColor,
    required this.rightColor,
    required this.bottomColor,
    required this.leftColor,
    required this.topPadding,
    required this.rightPadding,
    required this.bottomPadding,
    required this.leftPadding,
  });
}

enum PhysicalSide { top, right, bottom, left }

class LogicalSideMap {
  final PhysicalSide blockStart;
  final PhysicalSide blockEnd;
  final PhysicalSide inlineStart;
  final PhysicalSide inlineEnd;

  const LogicalSideMap({
    required this.blockStart,
    required this.blockEnd,
    required this.inlineStart,
    required this.inlineEnd,
  });
}

abstract class LogicalSideContext {
  WritingMode get writingMode;
  Direction get direction;
}

/// Allows UsedStyle (which isn't implicitly an interface in Dart) to act as a context
class UsedStyleLogicalSideContext implements LogicalSideContext {
  final UsedStyle us;
  UsedStyleLogicalSideContext(this.us);

  @override
  WritingMode get writingMode => us.writingMode;
  @override
  Direction get direction => us.direction;
}

LogicalSideMap resolveLogicalSides(LogicalSideContext us) {
  final isRtl = us.direction == Direction.rtl;

  switch (us.writingMode) {
    case WritingMode.horizontalTb:
      return LogicalSideMap(
        blockStart: PhysicalSide.top,
        blockEnd: PhysicalSide.bottom,
        inlineStart: isRtl ? PhysicalSide.right : PhysicalSide.left,
        inlineEnd: isRtl ? PhysicalSide.left : PhysicalSide.right,
      );
    case WritingMode.verticalRl:
    case WritingMode.verticalLr:
      return LogicalSideMap(
        blockStart: us.writingMode == WritingMode.verticalRl
            ? PhysicalSide.right
            : PhysicalSide.left,
        blockEnd: us.writingMode == WritingMode.verticalRl
            ? PhysicalSide.left
            : PhysicalSide.right,
        inlineStart: isRtl ? PhysicalSide.bottom : PhysicalSide.top,
        inlineEnd: isRtl ? PhysicalSide.top : PhysicalSide.bottom,
      );
  }
}

PhysicalBorderSides physicalBorderSides(UsedStyle us) {
  final sides = resolveLogicalSides(UsedStyleLogicalSideContext(us));

  final width = <PhysicalSide, double>{
    PhysicalSide.top: 0,
    PhysicalSide.right: 0,
    PhysicalSide.bottom: 0,
    PhysicalSide.left: 0,
  };
  final style = <PhysicalSide, BorderStyle>{
    PhysicalSide.top: BorderStyle.none,
    PhysicalSide.right: BorderStyle.none,
    PhysicalSide.bottom: BorderStyle.none,
    PhysicalSide.left: BorderStyle.none,
  };
  final color = <PhysicalSide, Color>{
    PhysicalSide.top: 'black',
    PhysicalSide.right: 'black',
    PhysicalSide.bottom: 'black',
    PhysicalSide.left: 'black',
  };
  final padding = <PhysicalSide, double>{
    PhysicalSide.top: 0,
    PhysicalSide.right: 0,
    PhysicalSide.bottom: 0,
    PhysicalSide.left: 0,
  };

  width[sides.blockStart] = us.borderBlockStartWidth;
  width[sides.blockEnd] = us.borderBlockEndWidth;
  width[sides.inlineStart] = us.borderInlineStartWidth;
  width[sides.inlineEnd] = us.borderInlineEndWidth;

  style[sides.blockStart] = us.borderBlockStartStyle;
  style[sides.blockEnd] = us.borderBlockEndStyle;
  style[sides.inlineStart] = us.borderInlineStartStyle;
  style[sides.inlineEnd] = us.borderInlineEndStyle;

  color[sides.blockStart] = us.borderBlockStartColor;
  color[sides.blockEnd] = us.borderBlockEndColor;
  color[sides.inlineStart] = us.borderInlineStartColor;
  color[sides.inlineEnd] = us.borderInlineEndColor;

  padding[sides.blockStart] = us.paddingBlockStart;
  padding[sides.blockEnd] = us.paddingBlockEnd;
  padding[sides.inlineStart] = us.paddingInlineStart;
  padding[sides.inlineEnd] = us.paddingInlineEnd;

  return PhysicalBorderSides(
    topWidth: width[PhysicalSide.top]!,
    rightWidth: width[PhysicalSide.right]!,
    bottomWidth: width[PhysicalSide.bottom]!,
    leftWidth: width[PhysicalSide.left]!,
    topStyle: style[PhysicalSide.top]!,
    rightStyle: style[PhysicalSide.right]!,
    bottomStyle: style[PhysicalSide.bottom]!,
    leftStyle: style[PhysicalSide.left]!,
    topColor: color[PhysicalSide.top]!,
    rightColor: color[PhysicalSide.right]!,
    bottomColor: color[PhysicalSide.bottom]!,
    leftColor: color[PhysicalSide.left]!,
    topPadding: padding[PhysicalSide.top]!,
    rightPadding: padding[PhysicalSide.right]!,
    bottomPadding: padding[PhysicalSide.bottom]!,
    leftPadding: padding[PhysicalSide.left]!,
  );
}
