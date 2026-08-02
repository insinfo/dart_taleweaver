/// Resolve a length value at cascade time.
///
/// Port of `cascade/resolve-length.ts`.
library;

import '../styles/length.dart';

ComputedLength resolveLength(Length value, double fontSize) {
  if (value is PxLength) {
    return ComputedLength.px(value.value);
  } else if (value is EmLength) {
    return ComputedLength.px(value.value * fontSize);
  } else if (value is PercentLength) {
    return ComputedLength.percent(value.value);
  }
  return const ComputedLength.px(0); // fallback
}
