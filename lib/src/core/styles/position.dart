/// CSS positioning scheme.
///
/// Port of `styles/position.ts`.
library;

import 'length.dart';
import 'computed_style.dart';

enum Position {
  staticPosition,
  relative,
  absolute;

  String get value {
    switch (this) {
      case Position.staticPosition:
        return 'static';
      case Position.relative:
        return 'relative';
      case Position.absolute:
        return 'absolute';
    }
  }

  static Position fromString(String val) {
    switch (val) {
      case 'static':
        return Position.staticPosition;
      case 'relative':
        return Position.relative;
      case 'absolute':
        return Position.absolute;
      default:
        throw ArgumentError('Unhandled Position: $val');
    }
  }
}

class TransformFn {
  final String fn;
  final Length? tx;
  final Length? ty;
  final double? angleRad;
  final double? sx;
  final double? sy;

  const TransformFn({
    required this.fn,
    this.tx,
    this.ty,
    this.angleRad,
    this.sx,
    this.sy,
  });
}

class TransformOrigin {
  final Length x;
  final Length y;

  const TransformOrigin({
    required this.x,
    required this.y,
  });
}

enum StackingContextRole {
  self;

  String get value => 'self';
}

/// Compute a box's `StackingContextRole` from its `ComputedStyle`.
StackingContextRole? computeStackingContextRole(ComputedStyle cs) {
  if (cs.position != Position.staticPosition && cs.zIndex != 'auto')
    return StackingContextRole.self;
  if (cs.opacity < 1) return StackingContextRole.self;
  if (cs.transform.isNotEmpty) return StackingContextRole.self;
  return null;
}
