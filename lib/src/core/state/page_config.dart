/// Page setup configuration (size, orientation, margins).
///
/// Port of `page-config.ts`.
library;

/// Document page-setup data.
class PageConfig {
  /// Page width in points (1 pt = 1/72 inch).
  final double width;

  /// Page height in points.
  final double height;

  /// Page margins.
  final PageMargins margins;

  /// Gap between header/footer and body.
  final double headerFooterGap;

  const PageConfig({
    this.width = 612, // US Letter: 8.5 × 11 inches
    this.height = 792,
    this.margins = const PageMargins(),
    this.headerFooterGap = 36, // 0.5 inch
  });

  PageConfig copyWith({
    double? width,
    double? height,
    PageMargins? margins,
    double? headerFooterGap,
  }) {
    return PageConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      margins: margins ?? this.margins,
      headerFooterGap: headerFooterGap ?? this.headerFooterGap,
    );
  }
}

/// Page margins in points.
class PageMargins {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const PageMargins({
    this.top = 72, // 1 inch
    this.right = 72,
    this.bottom = 72,
    this.left = 72,
  });
}
