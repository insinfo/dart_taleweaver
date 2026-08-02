library;

class PrintPageSize {
  final double width;
  final double height;
  const PrintPageSize(this.width, this.height);
}

class PrintPageMargins {
  final double top;
  final double right;
  final double bottom;
  final double left;
  const PrintPageMargins(
      {this.top = 72, this.right = 72, this.bottom = 72, this.left = 72});
}

class PrintLayoutConfig {
  final PrintPageSize pageSize;
  final PrintPageMargins margins;
  final double pageGap;
  const PrintLayoutConfig(
      {this.pageSize = const PrintPageSize(612, 792),
      this.margins = const PrintPageMargins(),
      this.pageGap = 24});

  double get contentWidth => pageSize.width - margins.left - margins.right;
  double get contentHeight => pageSize.height - margins.top - margins.bottom;
}
