library;

import '../state/block_position.dart';
import '../state/attrs.dart';
import '../state/find_matches.dart';
import '../state/inline_content.dart';
import '../state/drawing.dart';
import '../styles/tab_stops.dart';
import '../styles/column_config.dart';

sealed class EditorAction {
  const EditorAction();
}

class InsertTextAction extends EditorAction {
  final String text;
  const InsertTextAction(this.text);
}

class PasteTextAction extends EditorAction {
  final String text;
  const PasteTextAction(this.text);
}

class ApplyFormattingAction extends EditorAction {
  final Span span;
  final ReadonlyAttrs attrs;
  const ApplyFormattingAction(this.span, this.attrs);
}

class ToggleStyleAction extends EditorAction {
  final String style;
  const ToggleStyleAction(this.style);
}

class ClearFormattingAction extends EditorAction {
  const ClearFormattingAction();
}

class SetLinkAction extends EditorAction {
  final String? url;
  const SetLinkAction(this.url);
}

class SetTextColorAction extends EditorAction {
  final String? color;
  const SetTextColorAction(this.color);
}

class SetHighlightAction extends EditorAction {
  final String? color;
  const SetHighlightAction(this.color);
}

class SetFontSizeAction extends EditorAction {
  final double? size;
  const SetFontSizeAction(this.size);
}

class SetFontFamilyAction extends EditorAction {
  final String? family;
  const SetFontFamilyAction(this.family);
}

class SetTextTransformAction extends EditorAction {
  final String? value;
  const SetTextTransformAction(this.value);
}

class SetTextAlignAction extends EditorAction {
  final String align;
  const SetTextAlignAction(this.align);
}

class SetLineSpacingAction extends EditorAction {
  final double spacing;
  const SetLineSpacingAction(this.spacing);
}

class SetParagraphSpacingAction extends EditorAction {
  final String edge;
  final double? value;
  const SetParagraphSpacingAction(this.edge, this.value);
}

/// Sets the three Word-style paragraph indent controls in logical CSS terms.
///
/// [inlineStart] and [inlineEnd] are non-negative distances from their
/// respective paragraph edges. [firstLine] is an offset relative to
/// [inlineStart], so it may be negative to express a hanging indent. Passing
/// `null` clears the corresponding direct paragraph override.
class SetParagraphIndentsAction extends EditorAction {
  final double? inlineStart;
  final double? inlineEnd;
  final double? firstLine;

  const SetParagraphIndentsAction(
      this.inlineStart, this.inlineEnd, this.firstLine);
}

class IndentAction extends EditorAction {
  const IndentAction();
}

class OutdentAction extends EditorAction {
  const OutdentAction();
}

class SetTabStopsAction extends EditorAction {
  final String blockId;
  final List<TabStop> tabStops;
  const SetTabStopsAction(this.blockId, this.tabStops);
}

class ReplaceMatchAction extends EditorAction {
  final TextMatch match;
  final String replacement;
  const ReplaceMatchAction(this.match, this.replacement);
}

class ReplaceAllAction extends EditorAction {
  final List<TextMatch> matches;
  final String replacement;
  const ReplaceAllAction(this.matches, this.replacement);
}

class ToggleSectionLandscapeAction extends EditorAction {
  const ToggleSectionLandscapeAction();
}

class SetSectionColumnsAction extends EditorAction {
  final int columnCount;
  final double? columnGap;
  final ColumnRule? columnRule;
  const SetSectionColumnsAction(this.columnCount,
      {this.columnGap, this.columnRule});
}

/// Sets the pagination margins of the active section, or of the document root
/// when the selection is not inside an explicit section.
///
/// Values are points and use the logical-axis names used by the persisted
/// `pageMargins` attribute: `blockStart`, `blockEnd`, `inlineStart`, and
/// `inlineEnd`.  The reducer normalizes the input to a plain
/// `Map<String, double>` before writing it, so the document data is safe to
/// round-trip through the built-in JSON and binary serializers.
///
/// Use [SetActivePageMarginsAction.values] when named numeric arguments are
/// more convenient than a map.
class SetActivePageMarginsAction extends EditorAction {
  /// JSON-compatible logical page-margin values in points.
  final Map<String, dynamic> pageMargins;

  const SetActivePageMarginsAction(this.pageMargins);

  /// Convenience constructor for the four required logical margins.
  factory SetActivePageMarginsAction.values({
    required num blockStart,
    required num blockEnd,
    required num inlineStart,
    required num inlineEnd,
  }) {
    return SetActivePageMarginsAction(<String, dynamic>{
      'blockStart': blockStart,
      'blockEnd': blockEnd,
      'inlineStart': inlineStart,
      'inlineEnd': inlineEnd,
    });
  }

  /// Convenience constructor for horizontal, left-to-right page coordinates.
  ///
  /// This maps `top`, `right`, `bottom`, and `left` to the persisted logical
  /// page-margin representation.
  factory SetActivePageMarginsAction.physical({
    required num top,
    required num right,
    required num bottom,
    required num left,
  }) {
    return SetActivePageMarginsAction.values(
      blockStart: top,
      blockEnd: bottom,
      inlineStart: left,
      inlineEnd: right,
    );
  }
}

/// Sets the paper size of the active section, or of the document root when
/// the selection is not inside an explicit section.
///
/// Both values are points and are persisted as the JSON-compatible
/// `pageInlineSize` and `pageBlockSize` attributes. The reducer canonicalizes
/// numeric input to `double`s, rejects non-positive or non-finite values, and
/// refuses a size that would leave no usable rectangle after the active page
/// margins are applied.
class SetActivePageSizeAction extends EditorAction {
  /// Physical page width in points in the document's inline direction.
  final num inlineSize;

  /// Physical page height in points in the document's block direction.
  final num blockSize;

  const SetActivePageSizeAction(this.inlineSize, this.blockSize);
}

class SetFootnotePolicyAction extends EditorAction {
  final String? reset;
  final String? format;
  const SetFootnotePolicyAction({this.reset, this.format});
}

class ListIndentAction extends EditorAction {
  const ListIndentAction();
}

class ListOutdentAction extends EditorAction {
  const ListOutdentAction();
}

class DeleteBackwardAction extends EditorAction {
  const DeleteBackwardAction();
}

class DeleteForwardAction extends EditorAction {
  const DeleteForwardAction();
}

class SetSelectionAction extends EditorAction {
  final Selection selection;
  const SetSelectionAction(this.selection);
}

class MoveWordAction extends EditorAction {
  final String direction;
  const MoveWordAction(this.direction);
}

class ExpandWordAction extends EditorAction {
  final String direction;
  const ExpandWordAction(this.direction);
}

class DeleteWordAction extends EditorAction {
  final String direction;
  const DeleteWordAction(this.direction);
}

class MoveDocumentBoundaryAction extends EditorAction {
  final String boundary;
  const MoveDocumentBoundaryAction(this.boundary);
}

class ExpandDocumentBoundaryAction extends EditorAction {
  final String boundary;
  const ExpandDocumentBoundaryAction(this.boundary);
}

class SetContainerWidthAction extends EditorAction {
  final double width;
  const SetContainerWidthAction(this.width);
}

class EscapeAction extends EditorAction {
  const EscapeAction();
}

class BlockInit {
  final String type;
  final ReadonlyAttrs? attrs;
  final InlineContent? inlineContent;
  final List<BlockInit> children;

  const BlockInit({
    required this.type,
    this.attrs,
    this.inlineContent,
    this.children = const [],
  });
}

class InsertNodeAction extends EditorAction {
  final BlockInit node;
  final Position? position;
  const InsertNodeAction(this.node, {this.position});
}

class SelectAllAction extends EditorAction {
  const SelectAllAction();
}

class SplitNodeAction extends EditorAction {
  const SplitNodeAction();
}

/// Inserts a manual page boundary before the following text-bearing block.
///
/// This is intentionally distinct from [SectionBreakAction]: it preserves the
/// current section's page setup, headers, footers and columns.  The reducer
/// represents the boundary as `breakBefore: 'page'` on the new sibling block.
class PageBreakAction extends EditorAction {
  const PageBreakAction();
}

class SetBlockTypeAction extends EditorAction {
  final String blockType;
  const SetBlockTypeAction(this.blockType);
}

/// Applies a Word-style heading level to the selected text block.
///
/// Valid levels are 1 through 6. The reducer accepts paragraphs, list items
/// and existing headings only; list-only metadata is removed when a list item
/// becomes a heading, while all other block formatting is preserved.
class SetHeadingLevelAction extends EditorAction {
  final int level;
  const SetHeadingLevelAction(this.level);
}

class ToggleListAction extends EditorAction {
  final String listType;
  const ToggleListAction(this.listType);
}

class SetListTypeAction extends EditorAction {
  final String listType;
  const SetListTypeAction(this.listType);
}

class SetListRestartAction extends EditorAction {
  final int? value;
  const SetListRestartAction(this.value);
}

class AddCommentAction extends EditorAction {
  final String id;
  final String author;
  final String body;
  final int createdAt;
  const AddCommentAction(this.id, this.author, this.body, this.createdAt);
}

class ResolveCommentAction extends EditorAction {
  final String id;
  const ResolveCommentAction(this.id);
}

class ReopenCommentAction extends EditorAction {
  final String id;
  const ReopenCommentAction(this.id);
}

class DeleteCommentAction extends EditorAction {
  final String id;
  const DeleteCommentAction(this.id);
}

class AddReplyAction extends EditorAction {
  final String commentId;
  final String replyId;
  final String author;
  final String body;
  final int createdAt;
  const AddReplyAction(
      this.commentId, this.replyId, this.author, this.body, this.createdAt);
}

class AcceptSuggestionAction extends EditorAction {
  final String id;
  const AcceptSuggestionAction(this.id);
}

class RejectSuggestionAction extends EditorAction {
  final String id;
  const RejectSuggestionAction(this.id);
}

class AcceptAllSuggestionsAction extends EditorAction {
  const AcceptAllSuggestionsAction();
}

class RejectAllSuggestionsAction extends EditorAction {
  const RejectAllSuggestionsAction();
}

class InsertFootnoteAction extends EditorAction {
  const InsertFootnoteAction();
}

class InsertCrossReferenceAction extends EditorAction {
  final String targetId;
  final String refMode;
  final String numberStyle;
  const InsertCrossReferenceAction(this.targetId, this.refMode,
      {this.numberStyle = 'decimal'});
}

class InsertPageFieldAction extends EditorAction {
  final String fieldKind;
  final String numberStyle;
  const InsertPageFieldAction(this.fieldKind, {this.numberStyle = 'decimal'});
}

class InsertTabAction extends EditorAction {
  const InsertTabAction();
}

class InsertTableAction extends EditorAction {
  final int rows;
  final int cols;
  const InsertTableAction(this.rows, this.cols);
}

class InsertTableRowAction extends EditorAction {
  final String position;
  const InsertTableRowAction(this.position);
}

class InsertTableColumnAction extends EditorAction {
  final String position;
  const InsertTableColumnAction(this.position);
}

class DeleteTableRowAction extends EditorAction {
  const DeleteTableRowAction();
}

class DeleteTableColumnAction extends EditorAction {
  const DeleteTableColumnAction();
}

class DeleteTableAction extends EditorAction {
  const DeleteTableAction();
}

class SplitCellAction extends EditorAction {
  const SplitCellAction();
}

class MergeCellsAction extends EditorAction {
  final String tableId;
  final int minRow;
  final int maxRow;
  final int minCol;
  final int maxCol;
  const MergeCellsAction(
      this.tableId, this.minRow, this.maxRow, this.minCol, this.maxCol);
}

class InsertHorizontalLineAction extends EditorAction {
  const InsertHorizontalLineAction();
}

class InsertTableOfContentsAction extends EditorAction {
  const InsertTableOfContentsAction();
}

class SectionBreakAction extends EditorAction {
  const SectionBreakAction();
}

class MergeSectionAction extends EditorAction {
  final String sectionId;
  const MergeSectionAction(this.sectionId);
}

class InsertHeaderAction extends EditorAction {
  const InsertHeaderAction();
}

class InsertFooterAction extends EditorAction {
  const InsertFooterAction();
}

class InsertPageNumberAction extends EditorAction {
  final String numberStyle;
  const InsertPageNumberAction({this.numberStyle = 'decimal'});
}

class InsertPageCountAction extends EditorAction {
  final String numberStyle;
  const InsertPageCountAction({this.numberStyle = 'decimal'});
}

class SetTableHeaderRowsAction extends EditorAction {
  final String tableId;
  final int count;
  const SetTableHeaderRowsAction(this.tableId, this.count);
}

class InsertInlineImageAction extends EditorAction {
  final String src;
  final double width;
  final double height;
  final String alt;
  const InsertInlineImageAction(this.src, this.width, this.height, this.alt);
}

class InsertImageAction extends EditorAction {
  final String src;
  final double? width;
  final double? height;
  const InsertImageAction(this.src, {this.width, this.height});
}

class SetImageSizeAction extends EditorAction {
  final String blockId;
  final double width;
  final double height;
  const SetImageSizeAction(this.blockId, this.width, this.height);
}

class SetImageWrapAction extends EditorAction {
  final String blockId;
  final String? wrap;
  const SetImageWrapAction(this.blockId, this.wrap);
}

class SetImageAltAction extends EditorAction {
  final String blockId;
  final String? alt;
  const SetImageAltAction(this.blockId, this.alt);
}

/// Inserts an editable, block-level text box after the focused block.
///
/// The optional presentation values are normalized into JSON primitives by
/// the reducer. Its text is stored as normal inline content, rather than a
/// second string attribute, so the box participates in ordinary text editing.
class InsertTextBoxAction extends EditorAction {
  final String text;
  final double? width;
  final double? height;
  final DrawingAlignment? alignment;
  final String? fill;
  final String? outline;
  final double? outlineWidth;

  const InsertTextBoxAction({
    this.text = '',
    this.width,
    this.height,
    this.alignment,
    this.fill,
    this.outline,
    this.outlineWidth,
  });
}

/// Inserts a rectangle, ellipse, or line. Rectangle and ellipse labels are
/// ordinary inline text; a line deliberately ignores a supplied [text].
class InsertShapeAction extends EditorAction {
  final DrawingShapeKind shapeKind;
  final String text;
  final double? width;
  final double? height;
  final DrawingAlignment? alignment;
  final String? fill;
  final String? outline;
  final double? outlineWidth;

  const InsertShapeAction(
    this.shapeKind, {
    this.text = '',
    this.width,
    this.height,
    this.alignment,
    this.fill,
    this.outline,
    this.outlineWidth,
  });
}

/// Updates JSON-safe geometry and visual properties of a drawing block.
///
/// Null fields retain the existing value. For a text box, rectangle or
/// ellipse, [text] replaces its ordinary inline content in one undoable
/// operation. Lines do not accept text and reject an update that supplies it.
class UpdateDrawingAction extends EditorAction {
  final String blockId;
  final String? text;
  final double? width;
  final double? height;
  final DrawingAlignment? alignment;
  final String? fill;
  final String? outline;
  final double? outlineWidth;

  const UpdateDrawingAction(
    this.blockId, {
    this.text,
    this.width,
    this.height,
    this.alignment,
    this.fill,
    this.outline,
    this.outlineWidth,
  });
}

class DeleteRangeAction extends EditorAction {
  final Span span;
  const DeleteRangeAction(this.span);
}

class UndoAction extends EditorAction {
  const UndoAction();
}

class RedoAction extends EditorAction {
  const RedoAction();
}
