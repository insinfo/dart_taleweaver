/// Typed metadata bag carried by ElementBox and BlockBox.
///
/// Port of `render/layout-metadata.ts`.
library;

import '../state/block_id.dart';
import '../state/drawing.dart';

class ImageMetadata {
  final String src;
  final double width;
  final double height;
  final String? alt;

  const ImageMetadata({
    required this.src,
    required this.width,
    required this.height,
    this.alt,
  });
}

/// Presentation metadata for a JSON-backed text box or simple shape.
///
/// Unlike [ImageMetadata], this is text-bearing for text boxes, rectangles,
/// and ellipses. The browser renderer uses it to add only presentation DOM;
/// the ordinary render-node children remain the authoritative editable text.
class DrawingMetadata {
  /// `text-box`, `rectangle`, `ellipse`, or `line`.
  final String kind;
  final DrawingProperties properties;
  final bool acceptsText;

  const DrawingMetadata({
    required this.kind,
    required this.properties,
    required this.acceptsText,
  });
}

class ListMetadata {
  final int level;
  final String listId;
  final bool ordered;

  const ListMetadata({
    required this.level,
    required this.listId,
    required this.ordered,
  });
}

class LayoutBoxMetadata {
  final ImageMetadata? image;
  final DrawingMetadata? drawing;
  final bool? horizontalLine;
  final bool? tableOfContents;
  final BlockId? navTarget;
  final bool? tocEntry;
  final List<double>? columnWidths;
  final int? headerRowCount;
  final int? rowSpan;
  final int? colSpan;
  final String? blockType;
  final int? headingLevel;
  final ListMetadata? list;

  final dynamic pageInlineSize;
  final dynamic pageBlockSize;
  final dynamic pageMargins;
  final dynamic pageGap;
  final dynamic headerBlockId;
  final dynamic footerBlockId;

  final dynamic columnCount;
  final dynamic columnGap;
  final dynamic columnRule;

  final String? embedType;
  final dynamic contentBlockId;

  final String? fieldKind;
  final String? numberStyle;

  final String? refMode; // e.g. "page"
  final String? targetId;

  final bool? replacedInline;

  const LayoutBoxMetadata({
    this.image,
    this.drawing,
    this.horizontalLine,
    this.tableOfContents,
    this.navTarget,
    this.tocEntry,
    this.columnWidths,
    this.headerRowCount,
    this.rowSpan,
    this.colSpan,
    this.blockType,
    this.headingLevel,
    this.list,
    this.pageInlineSize,
    this.pageBlockSize,
    this.pageMargins,
    this.pageGap,
    this.headerBlockId,
    this.footerBlockId,
    this.columnCount,
    this.columnGap,
    this.columnRule,
    this.embedType,
    this.contentBlockId,
    this.fieldKind,
    this.numberStyle,
    this.refMode,
    this.targetId,
    this.replacedInline,
  });
}
