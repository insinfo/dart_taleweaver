/// CSS length types used throughout the Taleweaver styling system.
///
/// Mirrors the TypeScript `Length`, `ComputedLength`, `UsedLength` hierarchy:
/// - [Length] — declared/specified value (what components return)
/// - [ComputedLength] — produced by the cascade (em/rem resolved to px)
/// - [UsedLength] — produced by layout (fully numeric)
library;

// ---------------------------------------------------------------------------
// Length — declared/specified value
// ---------------------------------------------------------------------------

/// A declared CSS length value.
///
/// Use the factory constructors [Length.px], [Length.percent], [Length.em].
/// A bare `double` in the original TypeScript is shorthand for px.
sealed class Length {
  const Length();

  /// Shorthand: a bare number means px.
  const factory Length.px(double value) = PxLength;
  const factory Length.percent(double value) = PercentLength;
  const factory Length.em(double value) = EmLength;
}

class PxLength extends Length {
  final double value;
  const PxLength(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PxLength && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'PxLength($value)';
}

class PercentLength extends Length {
  final double value;
  const PercentLength(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PercentLength && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'PercentLength($value%)';
}

class EmLength extends Length {
  final double value;
  const EmLength(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EmLength && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'EmLength(${value}em)';
}

// ---------------------------------------------------------------------------
// LengthOrAuto
// ---------------------------------------------------------------------------

/// A [Length] or the keyword `auto`.
sealed class LengthOrAuto {
  const LengthOrAuto();
  const factory LengthOrAuto.auto() = AutoLength;
  factory LengthOrAuto.length(Length l) = LengthValue;
}

class AutoLength extends LengthOrAuto {
  const AutoLength();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AutoLength;
  @override
  int get hashCode => 'auto'.hashCode;
  @override
  String toString() => 'auto';
}

class LengthValue extends LengthOrAuto {
  final Length value;
  const LengthValue(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LengthValue && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'LengthValue($value)';
}

// ---------------------------------------------------------------------------
// ComputedLength — produced by the cascade
// ---------------------------------------------------------------------------

/// A computed CSS length: `em`/`rem` already resolved to absolute px;
/// `percent` stays symbolic for layout-time resolution.
sealed class ComputedLength {
  const ComputedLength();

  /// Absolute px value.
  const factory ComputedLength.px(double value) = ComputedPxLength;

  /// Percent value (resolved during layout against containing block).
  const factory ComputedLength.percent(double value) = ComputedPercentLength;
}

class ComputedPxLength extends ComputedLength {
  final double value;
  const ComputedPxLength(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComputedPxLength && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'ComputedPxLength($value)';
}

class ComputedPercentLength extends ComputedLength {
  final double value;
  const ComputedPercentLength(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComputedPercentLength && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'ComputedPercentLength($value%)';
}

// ---------------------------------------------------------------------------
// ComputedLengthOrAuto
// ---------------------------------------------------------------------------

sealed class ComputedLengthOrAuto {
  const ComputedLengthOrAuto();
  const factory ComputedLengthOrAuto.auto() = ComputedAutoLength;
  factory ComputedLengthOrAuto.length(ComputedLength l) = ComputedLengthValue;
}

class ComputedAutoLength extends ComputedLengthOrAuto {
  const ComputedAutoLength();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ComputedAutoLength;
  @override
  int get hashCode => 'computedAuto'.hashCode;
  @override
  String toString() => 'auto';
}

class ComputedLengthValue extends ComputedLengthOrAuto {
  final ComputedLength value;
  const ComputedLengthValue(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComputedLengthValue && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'ComputedLengthValue($value)';
}

// ---------------------------------------------------------------------------
// UsedLength — produced by layout (fully numeric)
// ---------------------------------------------------------------------------

/// Fully resolved length in pixels.
typedef UsedLength = double;

// ---------------------------------------------------------------------------
// Intrinsic sizing keywords
// ---------------------------------------------------------------------------

/// CSS Sizing 3 intrinsic-sizing keywords.
enum IntrinsicSizingKeyword {
  minContent,
  maxContent,
  fitContent,
}
