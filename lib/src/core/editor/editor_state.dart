library;

import '../cursor/cursor_ops.dart';
import '../cursor/object_selection.dart';
import '../state/block_position.dart';
import '../state/block_id.dart';
import '../state/block.dart';
import '../state/history.dart';
import '../state/ops/delete_range.dart';
import '../state/ops/insert_text.dart';
import '../state/ops/apply_attrs.dart';
import '../state/ops/split_block.dart';
import '../state/ops/set_block_type.dart';
import '../state/ops/set_block_attrs.dart';
import '../state/ops/set_list_type.dart';
import '../state/ops/set_list_restart.dart';
import '../state/ops/comment_ops.dart';
import '../state/comments.dart';
import '../state/ops/suggestion_ops/resolve.dart';
import '../state/suggestions.dart';
import '../state/ops/insert_footnote.dart';
import '../state/ops/insert_cross_reference.dart';
import '../state/ops/insert_page_field.dart';
import '../state/ops/insert_tab.dart';
import '../state/ops/create_table.dart';
import '../state/table_context.dart';
import '../state/ops/insert_table_row.dart';
import '../state/ops/insert_table_column.dart';
import '../state/ops/delete_table_row.dart';
import '../state/ops/delete_table_column.dart';
import '../state/ops/delete_table.dart';
import '../state/ops/split_cell.dart';
import '../state/ops/merge_cells.dart';
import '../state/table_cell_range.dart';
import '../state/ops/insert_block.dart';
import '../state/ops/section_break.dart';
import '../state/ops/merge_section.dart';
import '../state/ops/insert_template_body.dart';
import '../state/ops/set_table_header_rows.dart';
import '../state/ops/insert_inline_image.dart';
import '../styles/tab_stops.dart';
import '../state/ops/merge_block_attrs.dart';
import '../state/ops/replace_matches.dart';
import '../components/component_registry.dart';
import '../state/block_traversal.dart';
import '../state/block_compare.dart';
import '../state/block_kinds.dart';
import '../state/inline_content.dart';
import '../state/span_iteration.dart';
import '../state/state.dart';
import 'editor_action.dart';

class EditorConfig {
  final double containerWidth;
  final int Function()? now;
  final ComponentRegistry? componentRegistry;
  const EditorConfig(
      {this.containerWidth = 800, this.now, this.componentRegistry});
}

class EditorState {
  final State state;
  final Selection selection;
  final History history;
  final Set<BlockId>? lastDirtyIds;
  final double containerWidth;

  const EditorState(
      {required this.state,
      required this.selection,
      required this.history,
      required this.containerWidth,
      this.lastDirtyIds});
}

EditorState createInitialEditorState(
    {EditorConfig config = const EditorConfig()}) {
  final state = createEmptyDocument();
  final paragraph = getBlock(state, state.rootId)!.firstChildId!;
  final selection = Selection(
    anchor: Position(blockId: paragraph, offset: 0),
    focus: Position(blockId: paragraph, offset: 0),
  );
  return EditorState(
      state: state,
      selection: selection,
      history: createHistory(state),
      containerWidth: config.containerWidth);
}

State _insertNodeRecursive(State state, BlockId parentId, BlockInit init,
    ComponentRegistry registry, Set<BlockId> dirty) {
  final kind = registry.getBlockKind(init.type);
  if (kind == null) {
    throw StateError('INSERT_NODE: type "${init.type}" is not registered');
  }
  final hasInline =
      init.inlineContent != null && init.inlineContent!.items.isNotEmpty;
  if (kind == Kind.inlineBearingLeaf && init.children.isNotEmpty) {
    throw StateError('INSERT_NODE: inline leaf cannot have children');
  }
  if (kind == Kind.atomicLeaf && (hasInline || init.children.isNotEmpty)) {
    throw StateError('INSERT_NODE: atomic leaf cannot have content');
  }
  if (kind == Kind.container && hasInline) {
    throw StateError('INSERT_NODE: container cannot have inline content');
  }
  final inserted = insertBlock(
    state,
    parentId,
    null,
    InsertBlockArgs(
      type: init.type,
      attrs: init.attrs,
      inlineContent: kind == Kind.inlineBearingLeaf
          ? (init.inlineContent ?? InlineContent.empty)
          : null,
    ),
    productionAllocator,
    registry,
  );
  dirty.addAll(inserted.dirtyIds);
  var current = inserted.state;
  final parent = getBlock(current, parentId);
  final newId = parent?.lastChildId;
  if (newId == null || kind != Kind.container) return current;
  for (final child in init.children) {
    current = _insertNodeRecursive(current, newId, child, registry, dirty);
  }
  return current;
}

EditorState reduceEditor(
  EditorState editor,
  EditorAction action, [
  EditorConfig config = const EditorConfig(),
]) {
  final now = config.now?.call() ?? DateTime.now().millisecondsSinceEpoch;
  if (action is SetSelectionAction) {
    editor.history.breakCoalescing();
    return EditorState(
        state: freshState(editor.state),
        selection: action.selection,
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is InsertNodeAction) {
    final registry =
        config.componentRegistry ?? createDefaultComponentRegistry();
    final dirty = <BlockId>{};
    editor.history.beginCoalescedCapture(
        selectionBefore: editor.selection,
        coalesceKey: 'command',
        timestampMs: now);
    final result = _insertNodeRecursive(
        editor.state, editor.state.rootId, action.node, registry, dirty);
    editor.history.commit(selectionAfter: editor.selection);
    return EditorState(
      state: result,
      selection: editor.selection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: dirty,
    );
  }
  if (action is EscapeAction) {
    final objectId = objectSelection(editor.state, editor.selection,
        config.componentRegistry ?? createDefaultComponentRegistry());
    if (objectId == null) return editor;
    final moved = moveOffObjectSelection(editor.state, objectId, 'forward');
    if (moved == null) return editor;
    editor.history.breakCoalescing();
    return EditorState(
      state: freshState(editor.state),
      selection: moved,
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
  }
  if (action is MoveWordAction) {
    editor.history.breakCoalescing();
    return EditorState(
        state: freshState(editor.state),
        selection: Selection(
            anchor: moveByWord(
                editor.state, editor.selection.anchor, action.direction),
            focus: moveByWord(
                editor.state, editor.selection.focus, action.direction)),
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is ExpandWordAction) {
    editor.history.breakCoalescing();
    final expanded = selectWord(editor.state, editor.selection.focus);
    return EditorState(
        state: editor.state,
        selection: action.direction == 'backward'
            ? Selection(anchor: expanded.focus, focus: expanded.anchor)
            : expanded,
        history: editor.history,
        containerWidth: editor.containerWidth);
  }
  if (action is SelectAllAction) {
    editor.history.breakCoalescing();
    final leaves = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.inlineContent != null)
        .toList();
    if (leaves.isEmpty) return editor;
    final first = leaves.first;
    final last = leaves.last;
    final start = Position(blockId: first.id, offset: 0);
    final end = Position(
      blockId: last.id,
      offset: inlineContentLength(last.inlineContent!),
    );
    return EditorState(
      state: freshState(editor.state),
      selection: Selection(anchor: start, focus: end),
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
  }
  if (action is MoveDocumentBoundaryAction) {
    editor.history.breakCoalescing();
    final leaves = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.inlineContent != null)
        .toList();
    if (leaves.isEmpty) return editor;
    final block = action.boundary == 'start' ? leaves.first : leaves.last;
    final position = Position(
      blockId: block.id,
      offset: action.boundary == 'start'
          ? 0
          : inlineContentLength(block.inlineContent!),
    );
    return EditorState(
      state: freshState(editor.state),
      selection: Selection(anchor: position, focus: position),
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
  }
  if (action is ExpandDocumentBoundaryAction) {
    editor.history.breakCoalescing();
    final context =
        selectionContextOf(editor.state, editor.selection.focus.blockId);
    final leaves = iterateLeafBlocksInDocumentOrder(editor.state, context)
        .where((block) => block.inlineContent != null)
        .toList();
    if (leaves.isEmpty) return editor;
    final target = action.boundary == 'start' ? leaves.first : leaves.last;
    final position = Position(
      blockId: target.id,
      offset: action.boundary == 'start'
          ? 0
          : inlineContentLength(target.inlineContent!),
    );
    return EditorState(
      state: freshState(editor.state),
      selection: Selection(anchor: editor.selection.anchor, focus: position),
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
  }
  if (action is SetContainerWidthAction) {
    if (!action.width.isFinite ||
        action.width <= 0 ||
        action.width == editor.containerWidth) return editor;
    return EditorState(
      state: freshState(editor.state),
      selection: editor.selection,
      history: editor.history,
      containerWidth: action.width,
    );
  }
  if (action is UndoAction) {
    editor.history.breakCoalescing();
    final result = editor.history.undo();
    if (result == null) return editor;
    return EditorState(
        state: editor.state,
        selection: result.selection ?? editor.selection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  if (action is RedoAction) {
    editor.history.breakCoalescing();
    final result = editor.history.redo();
    if (result == null) return editor;
    return EditorState(
        state: editor.state,
        selection: result.selection ?? editor.selection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  final span = editor.selection;
  if (action is AddCommentAction ||
      action is ResolveCommentAction ||
      action is ReopenCommentAction ||
      action is DeleteCommentAction ||
      action is AddReplyAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = switch (action) {
      AddCommentAction(
        :final id,
        :final author,
        :final body,
        :final createdAt
      ) =>
        addComment(
            editor.state,
            span,
            AddCommentInput(
                id: CommentId(id),
                author: author,
                body: body,
                createdAt: createdAt)),
      ResolveCommentAction(:final id) =>
        resolveComment(editor.state, CommentId(id)),
      ReopenCommentAction(:final id) =>
        reopenComment(editor.state, CommentId(id)),
      DeleteCommentAction(:final id) =>
        deleteComment(editor.state, CommentId(id)),
      AddReplyAction(
        :final commentId,
        :final replyId,
        :final author,
        :final body,
        :final createdAt
      ) =>
        addReply(
            editor.state,
            CommentId(commentId),
            AddReplyInput(
                replyId: replyId,
                author: author,
                body: body,
                createdAt: createdAt)),
      _ => OperationResult(state: editor.state, dirtyIds: const {}),
    };
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is AcceptSuggestionAction ||
      action is RejectSuggestionAction ||
      action is AcceptAllSuggestionsAction ||
      action is RejectAllSuggestionsAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = switch (action) {
      AcceptSuggestionAction(:final id) =>
        acceptSuggestion(editor.state, SuggestionId(id)),
      RejectSuggestionAction(:final id) =>
        rejectSuggestion(editor.state, SuggestionId(id)),
      AcceptAllSuggestionsAction() => acceptAll(editor.state),
      RejectAllSuggestionsAction() => rejectAll(editor.state),
      _ => OperationResult(state: editor.state, dirtyIds: const {}),
    };
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is InsertFootnoteAction ||
      action is InsertCrossReferenceAction ||
      action is InsertPageFieldAction ||
      action is InsertTabAction ||
      action is InsertTableAction ||
      action is InsertInlineImageAction ||
      action is InsertPageNumberAction ||
      action is InsertPageCountAction) {
    if (action is InsertTableAction && (action.rows < 1 || action.cols < 1)) {
      return editor;
    }
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final caret = span.focus;
    if (action is InsertTableAction) {
      final created = createTable(
          editor.state, caret, action.rows, action.cols, productionAllocator);
      final nextSelection =
          Selection(anchor: created.caretInto, focus: created.caretInto);
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
        state: created.result.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: created.result.dirtyIds,
      );
    }
    final result = switch (action) {
      InsertFootnoteAction() => OperationResult(
          state: freshState(editor.state), dirtyIds: const <BlockId>{}),
      InsertCrossReferenceAction(
        :final targetId,
        :final refMode,
        :final numberStyle
      ) =>
        insertCrossReference(
            editor.state, caret, BlockId(targetId), refMode, numberStyle),
      InsertPageFieldAction(:final fieldKind, :final numberStyle) =>
        insertPageField(editor.state, caret, fieldKind, numberStyle),
      InsertTabAction() => insertTab(editor.state, caret),
      InsertInlineImageAction(
        :final src,
        :final width,
        :final height,
        :final alt
      ) =>
        insertInlineImage(
            editor.state,
            caret,
            InlineImageProperties(
                src: src, width: width, height: height, alt: alt)),
      InsertPageNumberAction(:final numberStyle) =>
        insertPageField(editor.state, caret, 'page-number', numberStyle),
      InsertPageCountAction(:final numberStyle) =>
        insertPageField(editor.state, caret, 'page-count', numberStyle),
      _ => OperationResult(state: editor.state, dirtyIds: const {}),
    };
    // Footnote has a result object rather than OperationResult; keep this
    // branch explicit until its editor-facing caret mapping is finalized.
    if (action is InsertFootnoteAction) {
      final footnote = insertFootnote(editor.state, caret, productionAllocator);
      editor.history.commit(selectionAfter: span);
      return EditorState(
        state: freshState(editor.state),
        selection: span,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: footnote.dirtyIds.map(BlockId.new).toSet(),
      );
    }
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is InsertTableRowAction ||
      action is InsertTableColumnAction ||
      action is DeleteTableRowAction ||
      action is DeleteTableColumnAction ||
      action is DeleteTableAction ||
      action is SplitCellAction ||
      action is MergeCellsAction) {
    final context = resolveTableContext(editor.state, span.focus.blockId);
    if (context == null) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = switch (action) {
      InsertTableRowAction(:final position) => insertTableRow(
              editor.state,
              context,
              position == 'above' ? RowPosition.above : RowPosition.below,
              productionAllocator)
          .result,
      InsertTableColumnAction(:final position) => insertTableColumn(
          editor.state,
          context,
          position == 'left' ? ColumnPosition.left : ColumnPosition.right,
          productionAllocator),
      DeleteTableRowAction() => deleteTableRow(editor.state, context),
      DeleteTableColumnAction() => deleteTableColumn(editor.state, context),
      DeleteTableAction() => deleteTableWithReplacement(
              editor.state, context.tableId, productionAllocator)
          .result,
      SplitCellAction() =>
        splitCell(editor.state, context, productionAllocator),
      MergeCellsAction(
        :final tableId,
        :final minRow,
        :final maxRow,
        :final minCol,
        :final maxCol
      ) =>
        mergeCells(
            editor.state,
            CellRange(
              tableId: BlockId(tableId),
              minRow: minRow,
              maxRow: maxRow,
              minCol: minCol,
              maxCol: maxCol,
            )),
      _ => OperationResult(state: editor.state, dirtyIds: const {}),
    };
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SetTableHeaderRowsAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result =
        setTableHeaderRows(editor.state, BlockId(action.tableId), action.count);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is ReplaceMatchAction || action is ReplaceAllAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = action is ReplaceMatchAction
        ? replaceAllMatches(editor.state, [action.match], action.replacement)
        : (() {
            final replace = action as ReplaceAllAction;
            return replaceAllMatches(
                editor.state, replace.matches, replace.replacement);
          })();
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SetTabStopsAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final normalized = [
      for (final stop in action.tabStops)
        TabStop(
          position:
              stop.position.isFinite && stop.position > 0 ? stop.position : 0,
          alignment: stop.alignment,
          leader: stop.leader,
        ),
    ]..sort((a, b) => a.position.compareTo(b.position));
    final result = mergeBlockAttrs(
        editor.state, BlockId(action.blockId), {'tabStops': normalized});
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is InsertImageAction) {
    final block = getBlock(editor.state, span.focus.blockId);
    final parentId = block?.parentId;
    if (block == null || parentId == null) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final attrs = <String, dynamic>{'src': action.src};
    if (action.width != null) attrs['width'] = action.width;
    if (action.height != null) attrs['height'] = action.height;
    final result = insertBlock(
      editor.state,
      parentId,
      block.nextSiblingId,
      InsertBlockArgs(type: 'image', attrs: attrs),
      productionAllocator,
    );
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SetImageSizeAction ||
      action is SetImageWrapAction ||
      action is SetImageAltAction) {
    final blockId = switch (action) {
      SetImageSizeAction(:final blockId) => BlockId(blockId),
      SetImageWrapAction(:final blockId) => BlockId(blockId),
      SetImageAltAction(:final blockId) => BlockId(blockId),
      _ => span.focus.blockId,
    };
    final attrs = switch (action) {
      SetImageSizeAction(:final width, :final height) => <String, dynamic>{
          'width': width,
          'height': height
        },
      SetImageWrapAction(:final wrap) => <String, dynamic>{'wrap': wrap},
      SetImageAltAction(:final alt) => <String, dynamic>{'alt': alt},
      _ => const <String, dynamic>{},
    };
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = mergeBlockAttrs(editor.state, blockId, attrs);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is InsertHorizontalLineAction ||
      action is InsertTableOfContentsAction) {
    final block = getBlock(editor.state, span.focus.blockId);
    final parentId = block?.parentId;
    if (block == null || parentId == null) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final type = action is InsertHorizontalLineAction
        ? 'horizontal-line'
        : 'table-of-contents';
    final attrs = action is InsertTableOfContentsAction
        ? <String, dynamic>{
            'levels': [1, 2, 3, 4, 5, 6],
            'leader': 'dot',
            'showPageNumbers': true,
            'indentStep': 18.0,
          }
        : const <String, dynamic>{};
    final result = insertBlock(
      editor.state,
      parentId,
      block.nextSiblingId,
      InsertBlockArgs(type: type, attrs: attrs),
      productionAllocator,
    );
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SectionBreakAction || action is MergeSectionAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    if (action is SectionBreakAction) {
      final split =
          applySectionBreak(editor.state, span.focus, productionAllocator);
      final next = Position(blockId: split.newCursorBlockId, offset: 0);
      editor.history
          .commit(selectionAfter: Selection(anchor: next, focus: next));
      return EditorState(
        state: split.result.state,
        selection: Selection(anchor: next, focus: next),
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: split.result.dirtyIds,
      );
    }
    final result = mergeSectionWithPrevious(
        editor.state, BlockId((action as MergeSectionAction).sectionId));
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is ToggleSectionLandscapeAction ||
      action is SetSectionColumnsAction) {
    if (action is SetSectionColumnsAction &&
        (action.columnCount < 1 ||
            (action.columnGap != null &&
                (!action.columnGap!.isFinite || action.columnGap! < 0)))) {
      return editor;
    }
    final current = getBlock(editor.state, span.focus.blockId);
    if (current == null) return editor;
    final sections = ancestorChain(editor.state, current)
        .where((block) => block.type == 'section')
        .toList();
    final section = sections.isEmpty ? null : sections.first;
    final target = section ?? getBlock(editor.state, editor.state.rootId);
    if (target == null) return editor;
    final attrs = <String, dynamic>{};
    if (action is SetSectionColumnsAction) {
      attrs['columnCount'] = action.columnCount;
      if (action.columnGap != null) attrs['columnGap'] = action.columnGap;
    } else {
      final landscape = target.attrs['pageInlineSize'];
      if (landscape is num) {
        attrs['pageInlineSize'] = null;
        attrs['pageBlockSize'] = null;
      } else {
        // Without a page-config dependency, preserve explicit dimensions when
        // present and use the conventional A4 portrait swap as a deterministic
        // fallback for the standalone reducer.
        final inline =
            (target.attrs['pageInlineSize'] as num?)?.toDouble() ?? 794;
        final block =
            (target.attrs['pageBlockSize'] as num?)?.toDouble() ?? 1123;
        attrs['pageInlineSize'] = block;
        attrs['pageBlockSize'] = inline;
      }
    }
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = mergeBlockAttrs(editor.state, target.id, attrs);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SetFootnotePolicyAction) {
    final attrs = <String, dynamic>{};
    const resets = {'continuous', 'restart-per-section', 'restart-per-page'};
    const formats = {
      'decimal',
      'lower-roman',
      'upper-roman',
      'lower-alpha',
      'upper-alpha',
      'symbol'
    };
    if (resets.contains(action.reset)) {
      attrs['footnoteNumberingReset'] = action.reset;
    }
    if (formats.contains(action.format)) {
      attrs['footnoteNumberingFormat'] = action.format;
    }
    if (attrs.isEmpty) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = mergeBlockAttrs(editor.state, editor.state.rootId, attrs);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is InsertHeaderAction || action is InsertFooterAction) {
    final current = getBlock(editor.state, span.focus.blockId);
    if (current == null) return editor;
    final section = ancestorChain(editor.state, current).firstWhere(
        (block) => block.type == 'section',
        orElse: () => getBlock(editor.state, editor.state.rootId)!);
    final region = action is InsertHeaderAction ? 'header' : 'footer';
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = insertTemplateBody(
      editor.state,
      InsertTemplateBodyArgs(region: region, sectionBlockId: section.id),
      productionAllocator,
    );
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds.map(BlockId.new).toSet(),
    );
  }
  if (action is SetTextAlignAction ||
      action is SetLineSpacingAction ||
      action is SetParagraphSpacingAction ||
      action is IndentAction ||
      action is OutdentAction ||
      action is ListIndentAction ||
      action is ListOutdentAction) {
    if (action is SetTextAlignAction &&
        !{
          'start',
          'end',
          'left',
          'right',
          'center',
          'justify',
        }.contains(action.align)) {
      return editor;
    }
    if (action is SetLineSpacingAction &&
        (!action.spacing.isFinite || action.spacing <= 0)) {
      return editor;
    }
    if (action is SetParagraphSpacingAction &&
        (action.edge != 'before' && action.edge != 'after')) {
      return editor;
    }
    final targets = <Block>[];
    if (span.anchor == span.focus) {
      final block = getBlock(editor.state, span.focus.blockId);
      if (block != null && block.inlineContent != null) targets.add(block);
    } else {
      targets.addAll(iterateBlocksInSpan(editor.state, span)
          .where((block) => block.inlineContent != null));
    }
    if (targets.isEmpty) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    var nextState = editor.state;
    final dirtyIds = <BlockId>{};
    for (final target in targets) {
      final block = getBlock(nextState, target.id);
      if (block == null) continue;
      final attrs = Map<String, dynamic>.of(block.attrs);
      if (action is SetTextAlignAction) {
        const allowed = {
          'start',
          'end',
          'left',
          'right',
          'center',
          'justify',
        };
        if (!allowed.contains(action.align)) continue;
        attrs['textAlign'] = action.align;
      } else if (action is SetLineSpacingAction) {
        if (action.spacing.isFinite && action.spacing > 0) {
          attrs['lineHeight'] = action.spacing;
        }
      } else if (action is SetParagraphSpacingAction) {
        if (action.edge != 'before' && action.edge != 'after') continue;
        final key =
            action.edge == 'before' ? 'marginBlockStart' : 'marginBlockEnd';
        if (action.value == null ||
            !action.value!.isFinite ||
            action.value! < 0) {
          attrs.remove(key);
        } else {
          attrs[key] = action.value;
        }
      } else if (action is IndentAction || action is OutdentAction) {
        if (block.type == 'list-item') continue;
        final current = (attrs['marginInlineStart'] as num?)?.toDouble() ?? 0;
        final delta = action is IndentAction ? 48.0 : -48.0;
        final maxIndent = editor.containerWidth - 96;
        final next = (current + delta)
            .clamp(0, maxIndent > 0 ? maxIndent : 0)
            .toDouble();
        if (next == 0) {
          attrs.remove('marginInlineStart');
        } else {
          attrs['marginInlineStart'] = next;
        }
      } else {
        if (block.type != 'list-item') continue;
        final current = (attrs['listLevel'] as num?)?.toInt() ?? 0;
        final delta = action is ListIndentAction ? 1 : -1;
        final next = (current + delta).clamp(0, 8);
        if (next == 0) {
          attrs.remove('listLevel');
        } else {
          attrs['listLevel'] = next;
        }
      }
      final result = setBlockAttrs(nextState, block.id, attrs);
      nextState = result.state;
      dirtyIds.addAll(result.dirtyIds);
    }
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: nextState,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: dirtyIds,
    );
  }
  if (action is ToggleStyleAction ||
      action is ClearFormattingAction ||
      action is SetLinkAction ||
      action is SetTextColorAction ||
      action is SetHighlightAction ||
      action is SetFontSizeAction ||
      action is SetFontFamilyAction ||
      action is SetTextTransformAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final attrs = switch (action) {
      ToggleStyleAction(:final style) => <String, dynamic>{
          style: !_selectionHasStyle(editor.state, span, style),
        },
      ClearFormattingAction() => <String, dynamic>{
          for (final key in _formattingKeys) key: null,
        },
      SetLinkAction(:final url) => <String, dynamic>{'link': url},
      SetTextColorAction(:final color) => <String, dynamic>{'color': color},
      SetHighlightAction(:final color) => <String, dynamic>{'highlight': color},
      SetFontSizeAction(:final size) => <String, dynamic>{'fontSize': size},
      SetFontFamilyAction(:final family) => <String, dynamic>{
          'fontFamily': family
        },
      SetTextTransformAction(:final value) => <String, dynamic>{
          'textTransform': value
        },
      _ => const <String, dynamic>{},
    };
    final result = applyAttrsToRange(editor.state, span, attrs);
    editor.history.commit(selectionAfter: editor.selection);
    return EditorState(
      state: result.state,
      selection: editor.selection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is ApplyFormattingAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: action.span, coalesceKey: 'command', timestampMs: now);
    final result = applyAttrsToRange(editor.state, action.span, action.attrs);
    editor.history.commit(selectionAfter: editor.selection);
    return EditorState(
      state: result.state,
      selection: editor.selection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SetBlockTypeAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = setBlockType(
      editor.state,
      span.focus.blockId,
      action.blockType,
      config.componentRegistry ?? createDefaultComponentRegistry(),
    );
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is ToggleListAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final current = getBlock(editor.state, span.focus.blockId);
    if (current == null) return editor;
    final registry =
        config.componentRegistry ?? createDefaultComponentRegistry();
    late final OperationResult typed;
    if (current.type == 'list-item') {
      final attrs = Map<String, dynamic>.of(current.attrs)..remove('listId');
      typed = setBlockType(editor.state, current.id, 'paragraph', registry);
      final result = setBlockAttrs(typed.state, current.id, attrs);
      editor.history.commit(selectionAfter: span);
      return EditorState(
        state: result.state,
        selection: span,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: {...typed.dirtyIds, ...result.dirtyIds},
      );
    }
    final listId = newListId();
    final attrs = Map<String, dynamic>.of(current.attrs)..['listId'] = listId;
    typed = setBlockType(editor.state, current.id, 'list-item', registry);
    final result = setBlockAttrs(typed.state, current.id, attrs);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: {...typed.dirtyIds, ...result.dirtyIds},
    );
  }
  if (action is SetListTypeAction || action is SetListRestartAction) {
    final block = getBlock(editor.state, span.focus.blockId);
    final listId = block?.attrs['listId'];
    if (listId is! String) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = action is SetListTypeAction
        ? setListType(
            editor.state,
            listId,
            action.listType == 'ordered'
                ? ListType.ordered
                : ListType.unordered,
          )
        : setListRestart(editor.state, span.focus.blockId,
            (action as SetListRestartAction).value);
    editor.history.commit(selectionAfter: span);
    return EditorState(
      state: result.state,
      selection: span,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is DeleteRangeAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = deleteRange(editor.state, action.span);
    final collapsed = action.span.start;
    editor.history
        .commit(selectionAfter: Selection(anchor: collapsed, focus: collapsed));
    return EditorState(
        state: result.state,
        selection: Selection(anchor: collapsed, focus: collapsed),
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  if (action is InsertTextAction || action is PasteTextAction) {
    final text = action is InsertTextAction
        ? action.text
        : (action as PasteTextAction).text;
    final target = isCollapsed(span) ? span.anchor : span.start;
    final key = action is InsertTextAction ? 'insert' : 'command';
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: key, timestampMs: now);
    var nextState = editor.state;
    var dirty = <BlockId>{};
    if (!isCollapsed(span)) {
      final deleted = deleteRange(nextState, span);
      nextState = deleted.state;
      dirty.addAll(deleted.dirtyIds);
    }
    final inserted = insertText(nextState, target, text, const {});
    dirty.addAll(inserted.dirtyIds);
    final caret =
        Position(blockId: target.blockId, offset: target.offset + text.length);
    final nextSelection = Selection(anchor: caret, focus: caret);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
        state: inserted.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: dirty);
  }
  if (action is DeleteBackwardAction || action is DeleteForwardAction) {
    final caret = span.focus;
    final target = action is DeleteBackwardAction
        ? moveByCharacter(editor.state, caret, 'backward')
        : moveByCharacter(editor.state, caret, 'forward');
    final range = action is DeleteBackwardAction
        ? Span(anchor: target, focus: caret)
        : Span(anchor: caret, focus: target);
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'delete', timestampMs: now);
    final result = deleteRange(editor.state, range);
    final nextSelection = Selection(anchor: range.anchor, focus: range.anchor);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is DeleteWordAction) {
    final caret = span.focus;
    final target = moveByWord(editor.state, caret, action.direction);
    final range = action.direction == 'backward'
        ? Span(anchor: target, focus: caret)
        : Span(anchor: caret, focus: target);
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'delete', timestampMs: now);
    final result = deleteRange(editor.state, range);
    final nextSelection = Selection(anchor: range.anchor, focus: range.anchor);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SplitNodeAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result =
        splitBlockAtPosition(editor.state, span.focus, productionAllocator);
    final nextSelection = Selection(
      anchor: Position(blockId: span.focus.blockId, offset: span.focus.offset),
      focus: Position(blockId: span.focus.blockId, offset: span.focus.offset),
    );
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  return editor;
}

const _formattingKeys = <String>[
  'bold',
  'italic',
  'underline',
  'strikethrough',
  'link',
  'color',
  'highlight',
  'fontSize',
  'fontFamily',
  'textTransform',
];

bool _selectionHasStyle(State state, Span span, String key) {
  var saw = false;
  var all = true;
  for (final segment in iterateSpan(state, span)) {
    final content = segment.block.inlineContent;
    if (content == null) continue;
    var cursor = 0;
    for (final item in content.items) {
      final length = item is TextItem ? item.text.length : 1;
      final overlaps =
          cursor < segment.rangeEnd && cursor + length > segment.rangeStart;
      if (overlaps && item is TextItem) {
        saw = true;
        all = all && item.attrs[key] == true;
      }
      cursor += length;
    }
  }
  return saw && all;
}

extension on Span {
  Position get start => anchor.offset <= focus.offset ? anchor : focus;
}
