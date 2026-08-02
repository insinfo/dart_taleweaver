/// The DOM-free HTML-node seam for `taleweaver-html` DECODE.
///
/// Port of `serialize/html-node.ts`.
library;

/// Node kinds for HTML parsing abstraction.
enum HtmlNodeKind {
  element,
  text,
  other,
}

/// A minimal, DOM-free view of a parsed HTML node.
abstract interface class HtmlNode {
  HtmlNodeKind get kind;

  /// UPPERCASE tag name for elements; empty string for non-elements.
  String get tagName;

  /// Element attribute by name, or null.
  String? getAttribute(String name);

  /// Element children (elements ONLY).
  List<HtmlNode> get children;

  /// ALL child nodes incl. text.
  List<HtmlNode> get childNodes;

  /// RAW character data of a TEXT node (kind "text").
  String get data;

  /// Inline CSS properties the decode reads (e.g. "textAlign", "width").
  String? getStyleProperty(String prop);
}

/// Injected HTML parser: parse a full HTML string and return the BODY
/// as an `HtmlNode` (kind "element", tagName "BODY").
typedef HtmlParser = HtmlNode Function(String html);
