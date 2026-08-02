/// Footnote types.
///
/// Port of `footnotes/types.ts`.
library;

import '../state/block_id.dart';

typedef CounterFormat
    = String; // "decimal" | "lower-roman" | "upper-roman" | "lower-alpha" | "upper-alpha" | "symbol"

class FootnoteAnchorRef {
  final BlockId contentBlockId;
  final BlockId blockId;
  final BlockId? sectionId;

  const FootnoteAnchorRef({
    required this.contentBlockId,
    required this.blockId,
    this.sectionId,
  });
}

class FootnoteNumberingPolicy {
  final String
      reset; // "continuous" | "restart-per-section" | "restart-per-page"
  final CounterFormat format;

  const FootnoteNumberingPolicy({
    required this.reset,
    required this.format,
  });
}

class FootnoteNumber {
  final int value;
  final String formatted;

  const FootnoteNumber({
    required this.value,
    required this.formatted,
  });
}
