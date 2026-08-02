library;

import '../state/block_position.dart';
import '../state/attrs.dart';
import '../state/find_matches.dart';
import '../state/inline_content.dart';
import '../styles/tab_stops.dart';

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
  const SetSectionColumnsAction(this.columnCount, {this.columnGap});
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

class SetBlockTypeAction extends EditorAction {
  final String blockType;
  const SetBlockTypeAction(this.blockType);
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
