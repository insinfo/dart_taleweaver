library;

import '../cursor/cursor_ops.dart';
import '../cursor/object_selection.dart';
import '../state/block_position.dart';
import '../state/block_id.dart';
import '../state/block.dart';
import '../state/block_schema.dart';
import '../state/attrs.dart';
import '../state/inline_content.dart';
import '../state/history.dart';
import '../state/ops/delete_range.dart';
import '../state/ops/insert_text.dart';
import '../state/ops/insert_blocks_after.dart';
import '../state/ops/apply_attrs.dart';
import '../state/ops/split_block.dart';
import '../state/ops/set_block_type.dart';
import '../state/ops/set_block_attrs.dart';
import '../state/ops/set_list_type.dart';
import '../state/ops/set_list_restart.dart';
import '../state/ops/comment_ops.dart';
import '../state/comments.dart';
import '../state/ops/suggestion_ops/resolve.dart';
import '../state/ops/suggestion_ops/fragment.dart';
import '../state/ops/suggestion_ops/insert.dart';
import '../state/ops/suggestion_ops/mark.dart';
import '../state/ops/suggestion_ops/split.dart';
import '../state/suggestions.dart';
import '../state/ops/insert_footnote.dart';
import '../state/ops/insert_cross_reference.dart';
import '../state/ops/insert_page_field.dart';
import '../state/ops/insert_tab.dart';
import '../state/ops/create_table.dart';
import '../state/table_context.dart';
import '../state/ops/insert_table_row.dart';
import '../state/ops/insert_table_row_span_aware.dart';
import '../state/ops/insert_table_column.dart';
import '../state/ops/insert_table_column_span_aware.dart';
import '../state/ops/delete_table_row.dart';
import '../state/ops/delete_table_row_span_aware.dart';
import '../state/ops/delete_table_column.dart';
import '../state/ops/delete_table_column_span_aware.dart';
import '../state/ops/delete_table.dart';
import '../state/ops/split_cell.dart';
import '../state/ops/merge_cells.dart';
import '../state/table_cell_range.dart';
import '../state/ops/insert_block.dart';
import '../state/ops/remove_block.dart';
import '../state/ops/section_break.dart';
import '../state/ops/merge_section.dart';
import '../state/ops/insert_template_body.dart';
import '../state/ops/set_table_header_rows.dart';
import '../state/ops/insert_inline_image.dart';
import '../styles/tab_stops.dart';
import '../state/ops/merge_block_attrs.dart';
import '../state/ops/replace_matches.dart';
import '../state/ops/replace_range.dart';
import '../components/component_registry.dart';
import '../components/component_definition.dart';
import '../state/block_traversal.dart';
import '../state/block_compare.dart';
import '../state/list_defs.dart';
import '../state/block_kinds.dart';
import '../state/span_iteration.dart';
import '../state/state.dart';
import '../state/page_config.dart';
import '../state/drawing.dart';
import 'editor_action.dart';

class EditorConfig {
  final double containerWidth;
  final int Function()? now;
  final String? suggestingAuthor;
  final ComponentRegistry? componentRegistry;
  final PageConfig? pageConfig;
  const EditorConfig(
      {this.containerWidth = 800,
      this.now,
      this.suggestingAuthor,
      this.componentRegistry,
      this.pageConfig});
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
  final paragraph = iterateLeafBlocksInDocumentOrder(state)
      .firstWhere((block) => block.inlineContent != null)
      .id;
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

EditorState _reducePasteText(
    EditorState editor, String text, EditorConfig config, int now) {
  final selection = editor.selection;
  final target = isCollapsed(selection) ? selection.anchor : selection.start;

  if (config.suggestingAuthor != null) {
    final source = getBlock(editor.state, target.blockId);
    if (source == null || source.inlineContent == null) return editor;
    final fragment = text
        .split('\n')
        .map((line) => SiblingBlockInit(
              type: source.type,
              attrs: source.attrs,
              inlineContent: line.isEmpty
                  ? InlineContent.empty
                  : InlineContent([TextItem(text: line)]),
            ))
        .toList();
    final id =
        SuggestionId('paste-$now-${editor.state.doc.suggestions.length}');
    editor.history.beginCoalescedCapture(
        selectionBefore: selection, coalesceKey: 'command', timestampMs: now);
    final result = replaceWithSuggestedFragment(
      editor.state,
      selection,
      fragment,
      ReplaceSuggestionInput(
        deletionId: id,
        insertionId: id,
        author: config.suggestingAuthor!,
        createdAt: now,
      ),
      productionAllocator,
    );
    if (identical(result.result.state, editor.state)) return editor;
    final nextSelection =
        Selection(anchor: result.endPosition, focus: result.endPosition);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.result.dirtyIds,
    );
  }

  editor.history.beginCoalescedCapture(
      selectionBefore: selection, coalesceKey: 'command', timestampMs: now);
  var state = editor.state;
  final dirty = <BlockId>{};

  if (!isCollapsed(selection)) {
    final deleted = deleteRange(state, selection);
    state = deleted.state;
    dirty.addAll(deleted.dirtyIds);
  }

  final firstLine = text.split('\n');
  final first = firstLine.first;
  var position = target;
  if (first.isNotEmpty) {
    final inserted = insertText(state, position, first, const {});
    state = inserted.state;
    dirty.addAll(inserted.dirtyIds);
    position = Position(
        blockId: position.blockId, offset: position.offset + first.length);
  }

  if (firstLine.length > 1) {
    final source = getBlock(state, position.blockId);
    if (source != null &&
        source.inlineContent != null &&
        source.parentId != null) {
      final split = splitBlockAtPosition(state, position, productionAllocator);
      state = split.state;
      dirty.addAll(split.dirtyIds);
      final suffix = getBlock(state, source.id)?.nextSiblingId;
      if (suffix != null) {
        final last = firstLine.last;
        if (last.isNotEmpty) {
          final inserted = insertText(
              state, Position(blockId: suffix, offset: 0), last, const {});
          state = inserted.state;
          dirty.addAll(inserted.dirtyIds);
        }
        if (firstLine.length > 2) {
          final middle = <SiblingBlockInit>[];
          for (final line in firstLine.sublist(1, firstLine.length - 1)) {
            middle.add(SiblingBlockInit(
              type: source.type,
              attrs: source.attrs,
              inlineContent: line.isEmpty
                  ? InlineContent.empty
                  : InlineContent([
                      TextItem(text: line, attrs: const {}),
                    ]),
            ));
          }
          final inserted =
              insertBlocksAfter(state, source.id, middle, productionAllocator);
          state = inserted.result.state;
          dirty.addAll(inserted.result.dirtyIds);
        }
        position = Position(blockId: suffix, offset: last.length);
      }
    }
  }

  if (identical(state, editor.state)) return editor;
  final nextSelection = Selection(anchor: position, focus: position);
  editor.history.commit(selectionAfter: nextSelection);
  return EditorState(
    state: state,
    selection: nextSelection,
    history: editor.history,
    containerWidth: editor.containerWidth,
    lastDirtyIds: dirty,
  );
}

OperationResult _deleteRangeOrSuggest(
    State state, Span range, EditorConfig config, int now) {
  final author = config.suggestingAuthor;
  final context = selectionContextOf(state, range.anchor.blockId);
  if (author == null || context == null) return deleteRange(state, range);
  final id = SuggestionId('delete-$now-${state.doc.suggestions.length}');
  return markDeletion(
    state,
    range,
    SuggestionMintInput(id: id, author: author, createdAt: now),
  );
}

OperationResult _applyAttrsOrSuggest(
    State state, Span span, ReadonlyAttrs attrs, EditorConfig config, int now) {
  final author = config.suggestingAuthor;
  final context = selectionContextOf(state, span.anchor.blockId);
  if (author == null || context == null)
    return applyAttrsToRange(state, span, attrs);
  final id = SuggestionId('format-$now-${state.doc.suggestions.length}');
  return markFormatting(
    state,
    span,
    attrs,
    SuggestionMintInput(id: id, author: author, createdAt: now),
  );
}

/// Remove [tableId] and place the caret on a surviving main-tree block.
///
/// Last-row and last-column deletion must collapse the whole table: leaving an
/// empty table is not an editable document state. A table that is the body's
/// only child gets a replacement paragraph; otherwise its next sibling (or its
/// previous sibling when it was last) receives the caret.
EditorState _deleteWholeTable(EditorState editor, BlockId tableId, int now) {
  final table = getBlock(editor.state, tableId);
  if (table == null) return editor;

  final fallback = table.nextSiblingId ?? table.prevSiblingId;
  editor.history.beginCoalescedCapture(
    selectionBefore: editor.selection,
    coalesceKey: 'command',
    timestampMs: now,
  );
  final deleted =
      deleteTableWithReplacement(editor.state, tableId, productionAllocator);
  if (identical(deleted.result.state, editor.state)) {
    editor.history.commit(selectionAfter: editor.selection);
    return editor;
  }

  // A valid table always supplies one of these: a sole child gets a fresh
  // paragraph, while a non-sole child has an adjacent sibling. Keep a
  // defensive fallback rather than exposing a selection into a deleted cell.
  final caretId = deleted.newParagraphId ?? fallback;
  if (caretId == null) {
    editor.history.commit(selectionAfter: editor.selection);
    return EditorState(
      state: deleted.result.state,
      selection: editor.selection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: deleted.result.dirtyIds,
    );
  }
  final nextSelection = Selection(
    anchor: Position(blockId: caretId, offset: 0),
    focus: Position(blockId: caretId, offset: 0),
  );
  editor.history.commit(selectionAfter: nextSelection);
  return EditorState(
    state: deleted.result.state,
    selection: nextSelection,
    history: editor.history,
    containerWidth: editor.containerWidth,
    lastDirtyIds: deleted.result.dirtyIds,
  );
}

/// Validates and canonicalizes the document representation of page margins.
///
/// Section attributes intentionally store a JSON-compatible map rather than a
/// [PageMargins] instance: section setup belongs to document data and must
/// survive serializers and collaboration transports unchanged.
Map<String, double>? _normalizePageMargins(Map<String, dynamic> raw) {
  const keys = <String>{'blockStart', 'blockEnd', 'inlineStart', 'inlineEnd'};
  if (raw.length != keys.length || raw.keys.any((key) => !keys.contains(key))) {
    return null;
  }

  final normalized = <String, double>{};
  for (final key in keys) {
    final value = raw[key];
    if (value is! num || !value.isFinite || value < 0) return null;
    normalized[key] = value.toDouble();
  }
  return Map<String, double>.unmodifiable(normalized);
}

/// Ensures an override leaves a positive content rectangle when a page setup
/// is known.  Without [pageConfig], core can still persist a valid logical
/// margin map; an unpaginated host has no dimensions against which to check it.
bool _pageMarginsFitPage(
  Map<String, double> margins,
  PageConfig? pageConfig,
  Block target,
) {
  if (pageConfig == null) return true;

  var inlineSize = pageConfig.width;
  var blockSize = pageConfig.height;
  final inlineOverride = target.attrs['pageInlineSize'];
  final blockOverride = target.attrs['pageBlockSize'];
  if (inlineOverride is num && inlineOverride.isFinite && inlineOverride > 0) {
    inlineSize = inlineOverride.toDouble();
  }
  if (blockOverride is num && blockOverride.isFinite && blockOverride > 0) {
    blockSize = blockOverride.toDouble();
  }

  if (!inlineSize.isFinite ||
      !blockSize.isFinite ||
      inlineSize <= 0 ||
      blockSize <= 0) {
    return false;
  }
  return margins['inlineStart']! + margins['inlineEnd']! < inlineSize &&
      margins['blockStart']! + margins['blockEnd']! < blockSize;
}

/// Resolves persisted root/section margins for a page-size update.
///
/// A root setup is inherited by explicit sections, while a direct section
/// setup takes precedence. Imported malformed values cause the update to be
/// rejected instead of turning a previously recoverable document into one
/// whose active paper has no content rectangle.
Map<String, double>? _effectivePageMarginsForSize(
  State state,
  Block target,
  PageConfig? pageConfig,
) {
  final defaults = pageConfig?.margins;
  var margins = <String, double>{
    'blockStart': defaults?.top ?? 0,
    'blockEnd': defaults?.bottom ?? 0,
    'inlineStart': defaults?.left ?? 0,
    'inlineEnd': defaults?.right ?? 0,
  };

  final root = getBlock(state, state.rootId);
  final owners = <Block>[
    if (root != null) root,
    if (target.id != root?.id) target,
  ];
  for (final owner in owners) {
    if (!owner.attrs.containsKey('pageMargins')) continue;
    final raw = owner.attrs['pageMargins'];
    if (raw is! Map || raw.keys.any((key) => key is! String)) return null;
    final normalized = _normalizePageMargins(
      Map<String, dynamic>.from(raw),
    );
    if (normalized == null) return null;
    margins = Map<String, double>.of(normalized);
  }
  return margins;
}

/// A page-size override must retain a positive content rectangle after its
/// effective root/section margins have been applied.
bool _pageSizeFitsMargins(
  State state,
  Block target,
  double inlineSize,
  double blockSize,
  PageConfig? pageConfig,
) {
  final margins = _effectivePageMarginsForSize(state, target, pageConfig);
  if (margins == null) return false;
  return margins['inlineStart']! + margins['inlineEnd']! < inlineSize &&
      margins['blockStart']! + margins['blockEnd']! < blockSize;
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
        state: freshState(editor.state),
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
        state: freshState(editor.state),
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
    // Comments are anchored only in an expanded range of the main document
    // tree.  Do these guards before opening history so an invalid command is a
    // true identity no-op (and cannot disturb an active capture).
    if (action is AddCommentAction) {
      final anchorContext =
          selectionContextOf(editor.state, span.anchor.blockId);
      final focusContext = selectionContextOf(editor.state, span.focus.blockId);
      if (isCollapsed(span) ||
          anchorContext == null ||
          anchorContext != focusContext ||
          focusContext != editor.state.rootId) {
        return editor;
      }
    }
    final start =
        action is AddCommentAction ? spanStart(editor.state, span) : null;
    final end = action is AddCommentAction ? spanEnd(editor.state, span) : null;
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
    if (identical(result.state, editor.state)) {
      editor.history.commit(selectionAfter: span);
      return editor;
    }
    var selectionAfter = span;
    if (action is AddCommentAction) {
      // The paired zero-width markers sit outside the selected text. Preserve
      // both the visible range and its direction after their insertion.
      final sameBlock = start!.blockId == end!.blockId;
      final visibleStart =
          Position(blockId: start.blockId, offset: start.offset + 1);
      final visibleEnd = Position(
          blockId: end.blockId, offset: end.offset + (sameBlock ? 1 : 0));
      final anchorAtStart =
          comparePositions(editor.state, span.anchor, start) == 0;
      selectionAfter = anchorAtStart
          ? Selection(anchor: visibleStart, focus: visibleEnd)
          : Selection(anchor: visibleEnd, focus: visibleStart);
    } else if (action is DeleteCommentAction) {
      Position remap(Position position) {
        final block = getBlock(editor.state, position.blockId);
        if (block?.inlineContent == null) return position;
        var offset = 0;
        var stripped = 0;
        for (final item in block!.inlineContent!.items) {
          if (item is EmbedItem &&
              (item.embedType == commentStartEmbedType ||
                  item.embedType == commentEndEmbedType) &&
              item.properties['commentId'] == action.id &&
              offset < position.offset) {
            stripped++;
          }
          offset += item is TextItem ? item.text.length : 1;
        }
        return stripped == 0
            ? position
            : Position(
                blockId: position.blockId, offset: position.offset - stripped);
      }

      selectionAfter =
          Selection(anchor: remap(span.anchor), focus: remap(span.focus));
    }
    editor.history.commit(selectionAfter: selectionAfter);
    return EditorState(
      state: result.state,
      selection: selectionAfter,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is AcceptSuggestionAction ||
      action is RejectSuggestionAction ||
      action is AcceptAllSuggestionsAction ||
      action is RejectAllSuggestionsAction) {
    final result = switch (action) {
      AcceptSuggestionAction(:final id) =>
        acceptSuggestion(editor.state, SuggestionId(id)),
      RejectSuggestionAction(:final id) =>
        rejectSuggestion(editor.state, SuggestionId(id)),
      AcceptAllSuggestionsAction() => acceptAll(editor.state),
      RejectAllSuggestionsAction() => rejectAll(editor.state),
      _ => OperationResult(state: editor.state, dirtyIds: const {}),
    };
    // Accept/reject is final by contract. Do not create an undo entry, but
    // split any preceding typing capture so a later edit cannot merge into it.
    if (identical(result.state, editor.state)) return editor;
    editor.history.breakCoalescing();
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
    if (action is InsertInlineImageAction) {
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final anchor =
            resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final focus =
            resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (anchor == null ||
            focus == null ||
            anchor.parentId != focus.parentId ||
            anchor.inlineContent == null ||
            focus.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset >
                inlineContentLength(anchor.inlineContent!) ||
            normalized.focus.offset >
                inlineContentLength(focus.inlineContent!)) {
          return editor;
        }
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      // ignore: avoid_print
      var preparedState = editor.state;
      final dirtyIds = <BlockId>{};
      var insertionPoint = normalized.anchor;
      if (!isCollapsed(span)) {
        OperationResult deleted;
        try {
          deleted = deleteRange(preparedState, span);
        } on StateError {
          // Cross-context/cross-parent selections are not replaceable by an
          // inline embed and must remain a reducer no-op.
          return editor;
        }
        preparedState = deleted.state;
        dirtyIds.addAll(deleted.dirtyIds);
        insertionPoint = normalized.anchor;
      }
      final inserted = insertInlineImage(
          preparedState,
          insertionPoint,
          InlineImageProperties(
              src: action.src,
              width: action.width,
              height: action.height,
              alt: action.alt));
      // ignore: avoid_print
      if (identical(inserted.state, editor.state) && dirtyIds.isEmpty) {
        return editor;
      }
      dirtyIds.addAll(inserted.dirtyIds);
      final nextOffset = insertionPoint.offset + 1;
      final nextSelection = Selection(
        anchor: Position(blockId: insertionPoint.blockId, offset: nextOffset),
        focus: Position(blockId: insertionPoint.blockId, offset: nextOffset),
      );
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
        state: inserted.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: dirtyIds,
      );
    }
    if (action is InsertTabAction) {
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final anchor =
            resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final focus =
            resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (anchor == null ||
            focus == null ||
            anchor.parentId != focus.parentId ||
            anchor.inlineContent == null ||
            focus.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset >
                inlineContentLength(anchor.inlineContent!) ||
            normalized.focus.offset >
                inlineContentLength(focus.inlineContent!)) {
          return editor;
        }
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      var preparedState = editor.state;
      final dirtyIds = <BlockId>{};
      var insertionPoint = normalized.anchor;
      if (!isCollapsed(span)) {
        final deleted = deleteRange(preparedState, span);
        preparedState = deleted.state;
        dirtyIds.addAll(deleted.dirtyIds);
      }
      final inserted = insertTab(preparedState, insertionPoint);
      if (identical(inserted.state, editor.state) && dirtyIds.isEmpty) {
        return editor;
      }
      dirtyIds.addAll(inserted.dirtyIds);
      final nextOffset = insertionPoint.offset + 1;
      final nextSelection = Selection(
        anchor: Position(blockId: insertionPoint.blockId, offset: nextOffset),
        focus: Position(blockId: insertionPoint.blockId, offset: nextOffset),
      );
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
        state: inserted.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: dirtyIds,
      );
    }
    if (action is InsertFootnoteAction) {
      if (selectionContextOf(editor.state, span.focus.blockId) !=
          editor.state.rootId) return editor;
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final a = resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final f = resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (a == null ||
            f == null ||
            a.parentId != f.parentId ||
            a.inlineContent == null ||
            f.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset > inlineContentLength(a.inlineContent!) ||
            normalized.focus.offset > inlineContentLength(f.inlineContent!))
          return editor;
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      var prepared = editor.state;
      final dirty = <BlockId>{};
      if (!isCollapsed(span)) {
        try {
          final deleted = deleteRange(prepared, span);
          prepared = deleted.state;
          dirty.addAll(deleted.dirtyIds);
        } on StateError {
          return editor;
        }
      }
      final inserted =
          insertFootnote(prepared, normalized.anchor, productionAllocator);
      dirty.addAll(inserted.dirtyIds.map(BlockId.new));
      final next = Position(blockId: inserted.firstParagraphId, offset: 0);
      final nextSelection = Selection(anchor: next, focus: next);
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
          state: freshState(prepared),
          selection: nextSelection,
          history: editor.history,
          containerWidth: editor.containerWidth,
          lastDirtyIds: dirty);
    }
    if (action is InsertTableAction) {
      if (action.rows < 1 || action.cols < 1) return editor;
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final a = resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final f = resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (a == null ||
            f == null ||
            a.parentId != f.parentId ||
            a.inlineContent == null ||
            f.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset > inlineContentLength(a.inlineContent!) ||
            normalized.focus.offset > inlineContentLength(f.inlineContent!))
          return editor;
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      var prepared = editor.state;
      final dirty = <BlockId>{};
      if (!isCollapsed(span)) {
        try {
          final deleted = deleteRange(prepared, span);
          prepared = deleted.state;
          dirty.addAll(deleted.dirtyIds);
        } on StateError {
          return editor;
        }
      }
      final created = createTable(prepared, normalized.anchor, action.rows,
          action.cols, productionAllocator);
      dirty.addAll(created.result.dirtyIds);
      final next = created.caretInto;
      final nextSelection = Selection(anchor: next, focus: next);
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
          state: created.result.state,
          selection: nextSelection,
          history: editor.history,
          containerWidth: editor.containerWidth,
          lastDirtyIds: dirty);
    }
    if (action is InsertCrossReferenceAction) {
      // Cross-references are body-only and validate their target before any
      // selection deletion, matching the TypeScript handler's no-op gates.
      if (selectionContextOf(editor.state, span.focus.blockId) !=
          editor.state.rootId) return editor;
      final target = getBlock(editor.state, BlockId(action.targetId));
      if (target == null) return editor;
      if (action.refMode == 'number') {
        if (target.type != 'list-item') return editor;
        final raw = target.attrs['listId'];
        final def =
            raw is String ? getListDefsForState(editor.state)[raw] : null;
        if (def == null || classifyListDef(def) != 'ordered') return editor;
      }
      if ((action.refMode == 'text' || action.refMode == 'page') &&
          target.inlineContent == null) return editor;
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final a = resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final f = resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (a == null ||
            f == null ||
            a.parentId != f.parentId ||
            a.inlineContent == null ||
            f.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset > inlineContentLength(a.inlineContent!) ||
            normalized.focus.offset > inlineContentLength(f.inlineContent!)) {
          return editor;
        }
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      var prepared = editor.state;
      final dirty = <BlockId>{};
      final point = normalized.anchor;
      if (!isCollapsed(span)) {
        try {
          final deleted = deleteRange(prepared, span);
          prepared = deleted.state;
          dirty.addAll(deleted.dirtyIds);
        } on StateError {
          return editor;
        }
      }
      final inserted = insertCrossReference(prepared, point,
          BlockId(action.targetId), action.refMode, action.numberStyle);
      if (identical(inserted.state, editor.state) && dirty.isEmpty)
        return editor;
      dirty.addAll(inserted.dirtyIds);
      final next = Position(blockId: point.blockId, offset: point.offset + 1);
      final nextSelection = Selection(anchor: next, focus: next);
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
          state: inserted.state,
          selection: nextSelection,
          history: editor.history,
          containerWidth: editor.containerWidth,
          lastDirtyIds: dirty);
    }
    if (action is InsertPageFieldAction ||
        action is InsertPageNumberAction ||
        action is InsertPageCountAction) {
      final context = selectionContextOf(editor.state, span.focus.blockId);
      final contextBlock =
          context == null ? null : resolveBlock(editor.state, context)?.block;
      if (contextBlock == null || contextBlock.type != 'template-body')
        return editor;
      final normalized = Span(
        anchor: spanStart(editor.state, span),
        focus: spanEnd(editor.state, span),
      );
      if (!isCollapsed(span)) {
        final a = resolveBlock(editor.state, normalized.anchor.blockId)?.block;
        final f = resolveBlock(editor.state, normalized.focus.blockId)?.block;
        if (a == null ||
            f == null ||
            a.parentId != f.parentId ||
            a.inlineContent == null ||
            f.inlineContent == null ||
            normalized.anchor.offset < 0 ||
            normalized.focus.offset < 0 ||
            normalized.anchor.offset > inlineContentLength(a.inlineContent!) ||
            normalized.focus.offset > inlineContentLength(f.inlineContent!))
          return editor;
      }
      editor.history.beginCoalescedCapture(
          selectionBefore: span, coalesceKey: 'command', timestampMs: now);
      var prepared = editor.state;
      final dirty = <BlockId>{};
      final point = normalized.anchor;
      if (!isCollapsed(span)) {
        try {
          final deleted = deleteRange(prepared, span);
          prepared = deleted.state;
          dirty.addAll(deleted.dirtyIds);
        } on StateError {
          return editor;
        }
      }
      final kind = action is InsertPageFieldAction
          ? action.fieldKind
          : action is InsertPageNumberAction
              ? 'page-number'
              : 'page-count';
      final style = switch (action) {
        InsertPageFieldAction(:final numberStyle) => numberStyle,
        InsertPageNumberAction(:final numberStyle) => numberStyle,
        InsertPageCountAction(:final numberStyle) => numberStyle,
        _ => 'decimal',
      };
      final inserted = insertPageField(prepared, point, kind, style);
      if (identical(inserted.state, editor.state) && dirty.isEmpty)
        return editor;
      dirty.addAll(inserted.dirtyIds);
      final next = Position(blockId: point.blockId, offset: point.offset + 1);
      final nextSelection = Selection(anchor: next, focus: next);
      editor.history.commit(selectionAfter: nextSelection);
      return EditorState(
          state: inserted.state,
          selection: nextSelection,
          history: editor.history,
          containerWidth: editor.containerWidth,
          lastDirtyIds: dirty);
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
    if (action is DeleteTableAction) {
      return _deleteWholeTable(editor, context.tableId, now);
    }
    if (context.ragged) return editor;

    // Deleting the last row/column cannot leave an empty table. Collapse it
    // through the same path as DELETE_TABLE so the post-delete caret always
    // targets a surviving sibling (or a replacement paragraph).
    if (action is DeleteTableRowAction && context.rowIds.length <= 1) {
      return _deleteWholeTable(editor, context.tableId, now);
    }

    BlockId? deleteCaretCellId;
    if (action is DeleteTableRowAction) {
      if (context.spanned) {
        final grid = context.grid;
        final caretCell = grid?.cells
            .where((cell) => cell.cellId == context.cellId)
            .firstOrNull;
        if (grid == null || caretCell == null) return editor;
        final targetGridRow = caretCell.gridRow < grid.occupancy.length - 1
            ? caretCell.gridRow + 1
            : caretCell.gridRow - 1;
        if (targetGridRow < 0 || targetGridRow >= grid.occupancy.length) {
          return editor;
        }
        final row = grid.occupancy[targetGridRow];
        if (caretCell.gridCol < 0 || caretCell.gridCol >= row.length) {
          return editor;
        }
        deleteCaretCellId = row[caretCell.gridCol];
      } else {
        final targetRow = context.rowIndex + 1 < context.cellIdsByRow.length
            ? context.cellIdsByRow[context.rowIndex + 1]
            : context.rowIndex > 0
                ? context.cellIdsByRow[context.rowIndex - 1]
                : null;
        if (targetRow == null || context.colIndex >= targetRow.length) {
          return editor;
        }
        deleteCaretCellId = targetRow[context.colIndex];
      }
      if (deleteCaretCellId == null) return editor;
    }

    if (action is DeleteTableColumnAction) {
      final grid = context.grid;
      if (grid == null) return editor;
      if (grid.columnCount <= 1) {
        return _deleteWholeTable(editor, context.tableId, now);
      }

      if (context.spanned) {
        final caretCell = grid.cells
            .where((cell) => cell.cellId == context.cellId)
            .firstOrNull;
        if (caretCell == null) return editor;
        final targetGridCol = caretCell.gridCol < grid.columnCount - 1
            ? caretCell.gridCol + 1
            : caretCell.gridCol - 1;
        if (targetGridCol < 0 ||
            caretCell.gridRow < 0 ||
            caretCell.gridRow >= grid.occupancy.length) {
          return editor;
        }
        final row = grid.occupancy[caretCell.gridRow];
        if (targetGridCol >= row.length) return editor;
        deleteCaretCellId = row[targetGridCol];
      } else {
        final row = context.cellIdsByRow[context.rowIndex];
        if (context.colIndex < 0 || context.colIndex >= row.length) {
          return editor;
        }
        deleteCaretCellId = context.colIndex + 1 < row.length
            ? row[context.colIndex + 1]
            : context.colIndex > 0
                ? row[context.colIndex - 1]
                : null;
      }
      if (deleteCaretCellId == null) return editor;
    }

    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = switch (action) {
      InsertTableRowAction(:final position) => context.spanned
          ? insertTableRowSpanAware(
              editor.state,
              context,
              position == 'above' ? RowPosition.above : RowPosition.below,
              productionAllocator)
          : insertTableRow(
                  editor.state,
                  context,
                  position == 'above' ? RowPosition.above : RowPosition.below,
                  productionAllocator)
              .result,
      InsertTableColumnAction(:final position) => context.spanned
          ? insertTableColumnSpanAware(
              editor.state,
              context,
              position == 'left' ? ColumnPosition.left : ColumnPosition.right,
              productionAllocator)
          : insertTableColumn(
              editor.state,
              context,
              position == 'left' ? ColumnPosition.left : ColumnPosition.right,
              productionAllocator),
      DeleteTableRowAction() => context.spanned
          ? deleteTableRowSpanAware(editor.state, context)
          : deleteTableRow(editor.state, context),
      DeleteTableColumnAction() => context.spanned
          ? deleteTableColumnSpanAware(editor.state, context)
          : deleteTableColumn(editor.state, context),
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
    if (identical(result.state, editor.state)) {
      editor.history.commit(selectionAfter: span);
      return editor;
    }

    var selectionAfter = span;
    if (deleteCaretCellId != null) {
      final caretId = getBlock(result.state, deleteCaretCellId)?.firstChildId;
      if (caretId == null) {
        // Well-formed table operations always retain the computed target cell.
        // Keep the mutation/history coherent even if a malformed foreign tree
        // violates that invariant, instead of pointing into a deleted cell.
        final fallback = iterateLeafBlocksInDocumentOrder(result.state)
            .where((block) => block.inlineContent != null)
            .firstOrNull;
        if (fallback != null) {
          selectionAfter = Selection(
            anchor: Position(blockId: fallback.id, offset: 0),
            focus: Position(blockId: fallback.id, offset: 0),
          );
        }
      } else {
        selectionAfter = Selection(
          anchor: Position(blockId: caretId, offset: 0),
          focus: Position(blockId: caretId, offset: 0),
        );
      }
    }
    editor.history.commit(selectionAfter: selectionAfter);
    return EditorState(
      state: result.state,
      selection: selectionAfter,
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
  if (action is ReplaceMatchAction) {
    final match = action.match;
    final resolved = resolveBlock(editor.state, match.blockId);
    final inline = resolved?.block.inlineContent;
    if (inline == null ||
        match.start < 0 ||
        match.end < match.start ||
        match.end > inlineContentLength(inline)) return editor;
    final matchSpan = Span(
      anchor: Position(blockId: match.blockId, offset: match.start),
      focus: Position(blockId: match.blockId, offset: match.end),
    );
    final attrs = attrsAtOffset(inline, match.start);
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result =
        replaceRange(editor.state, matchSpan, action.replacement, attrs);
    if (identical(result.state, editor.state)) return editor;
    final cursor = Position(
        blockId: match.blockId,
        offset: match.start + action.replacement.length);
    final nextSelection = Selection(anchor: cursor, focus: cursor);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
        state: result.state,
        selection: nextSelection,
        history: editor.history,
        containerWidth: editor.containerWidth,
        lastDirtyIds: result.dirtyIds);
  }
  if (action is ReplaceAllAction) {
    if (action.matches.isEmpty) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result =
        replaceAllMatches(editor.state, action.matches, action.replacement);
    if (identical(result.state, editor.state)) return editor;
    final first = action.matches.first;
    final cursor = Position(blockId: first.blockId, offset: first.start);
    final nextSelection = Selection(anchor: cursor, focus: cursor);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
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
    final imageId = getBlock(result.state, block.id)!.nextSiblingId;
    if (imageId == null) return editor;
    final image = getBlock(result.state, imageId)!;
    final paragraphResult = insertBlock(
      result.state,
      parentId,
      image.nextSiblingId,
      const InsertBlockArgs(
          type: 'paragraph', inlineContent: InlineContent.empty),
      productionAllocator,
    );
    final paragraphId = getBlock(paragraphResult.state, imageId)!.nextSiblingId;
    if (paragraphId == null) return editor;
    final nextSelection = Selection(
      anchor: Position(blockId: paragraphId, offset: 0),
      focus: Position(blockId: paragraphId, offset: 0),
    );
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: paragraphResult.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: {...result.dirtyIds, ...paragraphResult.dirtyIds},
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
    final image = getBlock(editor.state, blockId);
    if (image == null || image.type != 'image') return editor;
    if (action is SetImageSizeAction &&
        (!action.width.isFinite ||
            !action.height.isFinite ||
            action.width <= 0 ||
            action.height <= 0)) {
      return editor;
    }
    if (action is SetImageWrapAction &&
        action.wrap != 'left' &&
        action.wrap != 'right' &&
        action.wrap != 'break') {
      return editor;
    }
    final attrs = switch (action) {
      SetImageSizeAction(:final width, :final height) => <String, dynamic>{
          'width': width,
          'height': height
        },
      SetImageWrapAction(:final wrap) => <String, dynamic>{
          'wrap': wrap == 'break' ? null : wrap
        },
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
  if (action is InsertTextBoxAction || action is InsertShapeAction) {
    final block = getBlock(editor.state, span.focus.blockId);
    final parentId = block?.parentId;
    if (block == null || parentId == null) return editor;

    final shapeKind = action is InsertShapeAction ? action.shapeKind : null;
    final defaults = shapeKind == null
        ? DrawingProperties.textBoxDefaults
        : DrawingProperties.defaultsFor(shapeKind);
    final properties = _drawingPropertiesFromInsertAction(action, defaults);
    if (properties == null) return editor;
    final acceptsText = shapeKind != DrawingShapeKind.line;
    final requestedText = switch (action) {
      InsertTextBoxAction(:final text) => text,
      InsertShapeAction(:final text) => text,
      _ => '',
    };
    final text = acceptsText ? requestedText : '';
    final attrs = <String, dynamic>{
      ...properties.toJson(),
      if (shapeKind != null) 'shapeKind': shapeKind.value,
    };

    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = insertBlock(
      editor.state,
      parentId,
      block.nextSiblingId,
      InsertBlockArgs(
        type: shapeKind == null ? 'text-box' : 'shape',
        attrs: attrs,
        inlineContent: text.isEmpty
            ? InlineContent.empty
            : InlineContent(<InlineItem>[TextItem(text: text)]),
      ),
      productionAllocator,
    );
    final drawingId = getBlock(result.state, block.id)!.nextSiblingId;
    if (drawingId == null) return editor;
    final drawing = getBlock(result.state, drawingId)!;
    // Preserve a normal text insertion point after a drawing. Text-bearing
    // drawings are still selected internally so their label can be edited
    // immediately; lines select this following paragraph instead.
    final paragraphResult = insertBlock(
      result.state,
      parentId,
      drawing.nextSiblingId,
      const InsertBlockArgs(
        type: 'paragraph',
        inlineContent: InlineContent.empty,
      ),
      productionAllocator,
    );
    final paragraphId =
        getBlock(paragraphResult.state, drawingId)!.nextSiblingId;
    if (paragraphId == null) return editor;
    final next = acceptsText
        ? Position(blockId: drawingId, offset: text.length)
        : Position(blockId: paragraphId, offset: 0);
    final nextSelection = Selection(anchor: next, focus: next);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: paragraphResult.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: {...result.dirtyIds, ...paragraphResult.dirtyIds},
    );
  }
  if (action is UpdateDrawingAction) {
    final blockId = BlockId(action.blockId);
    final drawing = getBlock(editor.state, blockId);
    if (drawing == null ||
        (drawing.type != 'text-box' && drawing.type != 'shape')) {
      return editor;
    }
    final shapeKind = drawing.type == 'shape'
        ? DrawingShapeKind.fromValue(drawing.attrs['shapeKind']) ??
            DrawingShapeKind.rectangle
        : null;
    final acceptsText = shapeKind != DrawingShapeKind.line;
    if (!acceptsText && action.text != null) return editor;
    final defaults = shapeKind == null
        ? DrawingProperties.textBoxDefaults
        : DrawingProperties.defaultsFor(shapeKind);
    final existing = DrawingProperties.fromAttrs(
      drawing.attrs,
      fallback: defaults,
    );
    final properties = _drawingPropertiesFromUpdateAction(action, existing);
    if (properties == null) return editor;
    final nextAttrs = <String, dynamic>{
      ...drawing.attrs,
      ...properties.toJson(),
    };
    final replacementText = action.text;
    final textChanges = replacementText != null &&
        !_isPlainDrawingText(drawing.inlineContent!, replacementText);
    final attrsChange = !attrsEqual(drawing.attrs, nextAttrs);
    if (!attrsChange && !textChanges) return editor;

    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = applyOperation(editor.state, (doc) {
      final map = doc.getBlockMap(blockId.value);
      if (map == null) return;
      if (attrsChange) map[BlockFields.attrs] = nextAttrs;
      if (textChanges) {
        map[BlockFields.inlineContent] = replacementText.isEmpty
            ? InlineContent.empty
            : InlineContent(<InlineItem>[TextItem(text: replacementText)]);
      }
      doc.markDirty(blockId.value);
    });
    final selection = textChanges && span.focus.blockId == blockId
        ? Selection(
            anchor: Position(blockId: blockId, offset: replacementText.length),
            focus: Position(blockId: blockId, offset: replacementText.length),
          )
        : span;
    editor.history.commit(selectionAfter: selection);
    return EditorState(
      state: result.state,
      selection: selection,
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
    final atomicId = getBlock(result.state, block.id)!.nextSiblingId;
    if (atomicId == null) return editor;
    final atomic = getBlock(result.state, atomicId)!;
    final paragraphResult = insertBlock(
      result.state,
      parentId,
      atomic.nextSiblingId,
      const InsertBlockArgs(
          type: 'paragraph', inlineContent: InlineContent.empty),
      productionAllocator,
    );
    final paragraphId =
        getBlock(paragraphResult.state, atomicId)!.nextSiblingId;
    if (paragraphId == null) return editor;
    final nextSelection = Selection(
      anchor: Position(blockId: paragraphId, offset: 0),
      focus: Position(blockId: paragraphId, offset: 0),
    );
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: paragraphResult.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: {...result.dirtyIds, ...paragraphResult.dirtyIds},
    );
  }
  if (action is SectionBreakAction || action is MergeSectionAction) {
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    if (action is SectionBreakAction) {
      final split =
          applySectionBreak(editor.state, span.focus, productionAllocator);
      if (identical(split.result.state, editor.state)) return editor;
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
    if (identical(result.state, editor.state)) return editor;
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
      action is SetSectionColumnsAction ||
      action is SetActivePageMarginsAction ||
      action is SetActivePageSizeAction) {
    if (action is SetSectionColumnsAction &&
        (action.columnCount < 1 ||
            (action.columnGap != null &&
                (!action.columnGap!.isFinite || action.columnGap! < 0)))) {
      return editor;
    }
    final normalizedMargins = action is SetActivePageMarginsAction
        ? _normalizePageMargins(action.pageMargins)
        : null;
    if (action is SetActivePageMarginsAction && normalizedMargins == null) {
      return editor;
    }
    final inlineSize =
        action is SetActivePageSizeAction ? action.inlineSize.toDouble() : null;
    final blockSize =
        action is SetActivePageSizeAction ? action.blockSize.toDouble() : null;
    if (action is SetActivePageSizeAction &&
        (!inlineSize!.isFinite ||
            !blockSize!.isFinite ||
            inlineSize <= 0 ||
            blockSize <= 0)) {
      return editor;
    }
    final current = getBlock(editor.state, span.focus.blockId);
    if (current == null) return editor;
    final sections = ancestorChain(editor.state, current)
        .where((block) => block.type == 'section')
        .toList();
    final section = sections.isEmpty ? null : sections.first;
    if (action is ToggleSectionLandscapeAction &&
        (config.pageConfig == null || section == null)) return editor;
    final target = section ?? getBlock(editor.state, editor.state.rootId);
    if (target == null) return editor;
    if (action is SetActivePageMarginsAction &&
        !_pageMarginsFitPage(normalizedMargins!, config.pageConfig, target)) {
      return editor;
    }
    if (action is SetActivePageSizeAction &&
        !_pageSizeFitsMargins(
          editor.state,
          target,
          inlineSize!,
          blockSize!,
          config.pageConfig,
        )) {
      return editor;
    }
    final attrs = <String, dynamic>{};
    if (action is SetSectionColumnsAction) {
      attrs['columnCount'] = action.columnCount;
      if (action.columnGap != null) attrs['columnGap'] = action.columnGap;
      if (action.columnRule != null) attrs['columnRule'] = action.columnRule;
    } else if (action is SetActivePageMarginsAction) {
      attrs['pageMargins'] = normalizedMargins;
    } else if (action is SetActivePageSizeAction) {
      attrs['pageInlineSize'] = inlineSize;
      attrs['pageBlockSize'] = blockSize;
    } else {
      final landscape = target.attrs['pageInlineSize'];
      if (landscape is num) {
        attrs['pageInlineSize'] = null;
        attrs['pageBlockSize'] = null;
      } else {
        final page = config.pageConfig!;
        attrs['pageInlineSize'] = page.height;
        attrs['pageBlockSize'] = page.width;
      }
    }
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = mergeBlockAttrs(editor.state, target.id, attrs);
    if (identical(result.state, editor.state)) return editor;
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
    if (identical(result.state, editor.state)) return editor;
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
    final current = resolveBlock(editor.state, span.focus.blockId)?.block;
    if (current == null) return editor;
    final mainCurrent = getBlock(editor.state, current.id);
    final section = mainCurrent == null
        ? getBlock(editor.state, editor.state.rootId)!
        : ancestorChain(editor.state, mainCurrent).firstWhere(
            (block) => block.type == 'section',
            orElse: () => getBlock(editor.state, editor.state.rootId)!);
    final region = action is InsertHeaderAction ? 'header' : 'footer';
    final attrKey = region == 'header' ? 'headerBlockId' : 'footerBlockId';
    final existingId = section.attrs[attrKey];
    if (existingId is String) {
      final existing = getTemplateContent(editor.state, BlockId(existingId));
      if (existing != null) {
        final caretId = existing.firstChildId ?? BlockId(existingId);
        final cursor = Position(blockId: caretId, offset: 0);
        return EditorState(
          state: editor.state,
          selection: Selection(anchor: cursor, focus: cursor),
          history: editor.history,
          containerWidth: editor.containerWidth,
          lastDirtyIds: editor.lastDirtyIds,
        );
      }
    }
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = insertTemplateBody(
      editor.state,
      InsertTemplateBodyArgs(region: region, sectionBlockId: section.id),
      productionAllocator,
    );
    final nextSelection = Selection(
      anchor: Position(blockId: result.firstParagraphId, offset: 0),
      focus: Position(blockId: result.firstParagraphId, offset: 0),
    );
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds.map(BlockId.new).toSet(),
    );
  }
  if (action is SetTextAlignAction ||
      action is SetLineSpacingAction ||
      action is SetParagraphSpacingAction ||
      action is SetParagraphIndentsAction ||
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
    if (action is SetParagraphIndentsAction &&
        ((action.inlineStart != null &&
                (!action.inlineStart!.isFinite || action.inlineStart! < 0)) ||
            (action.inlineEnd != null &&
                (!action.inlineEnd!.isFinite || action.inlineEnd! < 0)) ||
            (action.firstLine != null && !action.firstLine!.isFinite))) {
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
      } else if (action is SetParagraphIndentsAction) {
        _setParagraphIndentAttr(attrs, 'marginInlineStart', action.inlineStart);
        _setParagraphIndentAttr(attrs, 'marginInlineEnd', action.inlineEnd);
        _setParagraphIndentAttr(attrs, 'textIndent', action.firstLine,
            allowNegative: true);
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
    final result = _applyAttrsOrSuggest(editor.state, span, attrs, config, now);
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
    final result = _applyAttrsOrSuggest(
        editor.state, action.span, action.attrs, config, now);
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
  if (action is SetHeadingLevelAction) {
    // Headings are semantic block styles, not arbitrary type casts. Keep the
    // command safe for object/table selections, malformed documents and hosts
    // that deliberately omit the heading component from their schema.
    if (action.level < 1 || action.level > 6) return editor;
    final resolved = resolveBlock(editor.state, span.focus.blockId);
    final current = resolved?.block;
    if (current == null ||
        current.inlineContent == null ||
        !{'paragraph', 'list-item', 'heading'}.contains(current.type)) {
      return editor;
    }
    final registry =
        config.componentRegistry ?? createDefaultComponentRegistry();
    if (registry.getBlockKind(current.type) != Kind.inlineBearingLeaf ||
        registry.getBlockKind('heading') != Kind.inlineBearingLeaf) {
      return editor;
    }

    // Retain direct paragraph/layout formatting (alignment, spacing, indents,
    // tabs, language and page breaks), but never carry list bookkeeping into
    // a semantic heading. Keeping a dangling listId would also make DOM and
    // accessibility list grouping ambiguous after the type conversion.
    final attrs = Map<String, dynamic>.of(current.attrs);
    if (current.type == 'list-item') {
      attrs
        ..remove('listId')
        ..remove('listLevel')
        ..remove('listCounterOverride')
        ..remove('listType');
    }
    attrs['level'] = action.level;
    if (current.type == 'heading' && attrsEqual(current.attrs, attrs)) {
      return editor;
    }

    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final typed = current.type == 'heading'
        ? OperationResult(state: editor.state, dirtyIds: const {})
        : setBlockType(editor.state, current.id, 'heading', registry);
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
    if (action is PasteTextAction) {
      final normalized = text.replaceAll('\r', '');
      if (normalized.isEmpty) return editor;
      return _reducePasteText(editor, normalized, config, now);
    }
    final target = isCollapsed(span) ? span.anchor : span.start;
    final key = action is InsertTextAction ? 'insert' : 'command';
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: key, timestampMs: now);
    var nextState = editor.state;
    var dirty = <BlockId>{};
    final suggestionId = config.suggestingAuthor == null
        ? null
        : SuggestionId('text-$now-${editor.state.doc.suggestions.length}');
    if (suggestionId != null) {
      final input = SuggestionMintInput(
        id: suggestionId,
        author: config.suggestingAuthor!,
        createdAt: now,
      );
      final suggested = isCollapsed(span)
          ? mintInsertion(editor.state, span.focus, text, const {}, input)
          : replaceWithSuggestion(
              editor.state,
              span,
              text,
              const {},
              ReplaceSuggestionInput(
                deletionId: suggestionId,
                insertionId: suggestionId,
                author: input.author,
                createdAt: input.createdAt,
              ));
      nextState = suggested.state;
      dirty.addAll(suggested.dirtyIds);
    } else if (!isCollapsed(span)) {
      final deleted = deleteRange(nextState, span);
      nextState = deleted.state;
      dirty.addAll(deleted.dirtyIds);
    }
    final inserted = suggestionId == null
        ? insertText(nextState, target, text, const {})
        : OperationResult(state: nextState, dirtyIds: const {});
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
    final current = getBlock(editor.state, caret.blockId);
    final atomicTypes = {'image', 'horizontal-line', 'table-of-contents'};
    if (current != null && current.inlineContent != null) {
      final atStart = caret.offset == 0;
      final atEnd = caret.offset == inlineContentLength(current.inlineContent!);
      final adjacentId = action is DeleteBackwardAction && atStart
          ? current.prevSiblingId
          : action is DeleteForwardAction && atEnd
              ? current.nextSiblingId
              : null;
      final adjacent =
          adjacentId == null ? null : getBlock(editor.state, adjacentId);
      if (adjacent != null && atomicTypes.contains(adjacent.type)) {
        editor.history.beginCoalescedCapture(
            selectionBefore: span, coalesceKey: 'delete', timestampMs: now);
        final removed = removeBlock(editor.state, adjacent.id);
        if (identical(removed.state, editor.state)) return editor;
        final nextSelection = Selection(anchor: caret, focus: caret);
        editor.history.commit(selectionAfter: nextSelection);
        return EditorState(
            state: removed.state,
            selection: nextSelection,
            history: editor.history,
            containerWidth: editor.containerWidth,
            lastDirtyIds: removed.dirtyIds);
      }
    }
    final target = action is DeleteBackwardAction
        ? moveByCharacter(editor.state, caret, 'backward')
        : moveByCharacter(editor.state, caret, 'forward');
    final adjacentRange = action is DeleteBackwardAction
        ? Span(anchor: target, focus: caret)
        : Span(anchor: caret, focus: target);
    final range = isCollapsed(span) ? adjacentRange : span;
    if (range.anchor.blockId == range.focus.blockId &&
        range.anchor.offset == range.focus.offset) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'delete', timestampMs: now);
    final result = _deleteRangeOrSuggest(editor.state, range, config, now);
    if (identical(result.state, editor.state)) return editor;
    final collapse = isCollapsed(span) || action is DeleteBackwardAction
        ? range.anchor
        : range.focus;
    final nextSelection = Selection(anchor: collapse, focus: collapse);
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
    final range = isCollapsed(span)
        ? (action.direction == 'backward'
            ? Span(anchor: target, focus: caret)
            : Span(anchor: caret, focus: target))
        : span;
    if (range.anchor.blockId == range.focus.blockId &&
        range.anchor.offset == range.focus.offset) return editor;
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'delete', timestampMs: now);
    final result = _deleteRangeOrSuggest(editor.state, range, config, now);
    if (identical(result.state, editor.state)) return editor;
    final collapse =
        config.suggestingAuthor != null && action.direction == 'forward'
            ? range.focus
            : range.anchor;
    final nextSelection = Selection(anchor: collapse, focus: collapse);
    editor.history.commit(selectionAfter: nextSelection);
    return EditorState(
      state: result.state,
      selection: nextSelection,
      history: editor.history,
      containerWidth: editor.containerWidth,
      lastDirtyIds: result.dirtyIds,
    );
  }
  if (action is SplitNodeAction || action is PageBreakAction) {
    // A structural split is only defined for a text-bearing leaf.  Resolve the
    // follow-on type before the transaction so Enter at the end of a heading
    // creates a clean paragraph, in both direct and suggesting modes.
    final insertsManualPageBreak = action is PageBreakAction;
    final expanded = !isCollapsed(span);
    final splitPosition = expanded ? spanStart(editor.state, span) : span.focus;
    final selectionEnd = expanded ? spanEnd(editor.state, span) : span.focus;
    if (expanded &&
        (splitPosition.blockId != selectionEnd.blockId ||
            selectionContextOf(editor.state, splitPosition.blockId) !=
                selectionContextOf(editor.state, selectionEnd.blockId))) {
      return editor;
    }
    final block = getBlock(editor.state, splitPosition.blockId);
    if (block == null ||
        block.inlineContent == null ||
        block.parentId == null) {
      return editor;
    }
    final atEnd = !expanded &&
        splitPosition.offset == inlineContentLength(block.inlineContent!);
    final definition =
        (config.componentRegistry ?? createDefaultComponentRegistry())
            .get(block.type);
    final followOn = atEnd && definition is LeafComponentDefinition
        ? definition.splitFollowOnType
        : null;
    final newBlockAttrs = insertsManualPageBreak
        ? <String, dynamic>{
            ...?(followOn == null ? block.attrs : null),
            'breakBefore': 'page',
          }
        : followOn == null
            ? null
            : const <String, dynamic>{};
    final newBlockInit = newBlockAttrs == null
        ? null
        : <String, dynamic>{
            'type': followOn ?? block.type,
            'attrs': newBlockAttrs,
          };
    editor.history.beginCoalescedCapture(
        selectionBefore: span, coalesceKey: 'command', timestampMs: now);
    final result = config.suggestingAuthor == null
        ? splitBlockAtPosition(editor.state, splitPosition, productionAllocator,
            newType: followOn, newAttrs: newBlockAttrs)
        : expanded
            ? splitWithSuggestionOverSelection(
                editor.state,
                span,
                productionAllocator,
                ReplaceSuggestionInput(
                  deletionId: SuggestionId(
                      'split-delete-$now-${editor.state.doc.suggestions.length}'),
                  insertionId: SuggestionId(
                      'split-insert-$now-${editor.state.doc.suggestions.length}'),
                  author: config.suggestingAuthor!,
                  createdAt: now,
                ),
                newBlockInit)
            : splitWithSuggestion(
                editor.state,
                splitPosition,
                productionAllocator,
                SuggestionMintInput(
                  id: SuggestionId(
                      'split-$now-${editor.state.doc.suggestions.length}'),
                  author: config.suggestingAuthor!,
                  createdAt: now,
                ),
                newBlockInit);
    if (identical(result.state, editor.state)) return editor;
    final newBlockId =
        getBlock(result.state, splitPosition.blockId)?.nextSiblingId;
    if (newBlockId == null) return editor;
    final nextSelection = Selection(
      anchor: Position(blockId: newBlockId, offset: 0),
      focus: Position(blockId: newBlockId, offset: 0),
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

/// Stores a direct paragraph-indent value using the document's canonical
/// attribute representation. Zero and `null` both mean that no direct
/// override is needed; negative values are only valid for a first-line
/// (hanging) indent.
void _setParagraphIndentAttr(
  Map<String, dynamic> attrs,
  String key,
  double? value, {
  bool allowNegative = false,
}) {
  if (value == null || value == 0) {
    attrs.remove(key);
    return;
  }
  if (!allowNegative && value < 0) return;
  attrs[key] = value;
}

DrawingProperties? _drawingPropertiesFromInsertAction(
  EditorAction action,
  DrawingProperties fallback,
) {
  return switch (action) {
    InsertTextBoxAction(
      :final width,
      :final height,
      :final alignment,
      :final fill,
      :final outline,
      :final outlineWidth,
    ) =>
      _mergeDrawingProperties(
        fallback,
        width: width,
        height: height,
        alignment: alignment,
        fill: fill,
        outline: outline,
        outlineWidth: outlineWidth,
      ),
    InsertShapeAction(
      :final width,
      :final height,
      :final alignment,
      :final fill,
      :final outline,
      :final outlineWidth,
    ) =>
      _mergeDrawingProperties(
        fallback,
        width: width,
        height: height,
        alignment: alignment,
        fill: fill,
        outline: outline,
        outlineWidth: outlineWidth,
      ),
    _ => null,
  };
}

DrawingProperties? _drawingPropertiesFromUpdateAction(
  UpdateDrawingAction action,
  DrawingProperties existing,
) =>
    _mergeDrawingProperties(
      existing,
      width: action.width,
      height: action.height,
      alignment: action.alignment,
      fill: action.fill,
      outline: action.outline,
      outlineWidth: action.outlineWidth,
    );

DrawingProperties? _mergeDrawingProperties(
  DrawingProperties current, {
  double? width,
  double? height,
  DrawingAlignment? alignment,
  String? fill,
  String? outline,
  double? outlineWidth,
}) {
  if (width != null && !isDrawingDimension(width)) return null;
  if (height != null && !isDrawingDimension(height)) return null;
  if (outlineWidth != null && !isDrawingOutlineWidth(outlineWidth)) {
    return null;
  }
  if (fill != null && !isSafeDrawingColor(fill)) return null;
  if (outline != null && !isSafeDrawingColor(outline)) return null;
  return DrawingProperties(
    width: width ?? current.width,
    height: height ?? current.height,
    alignment: alignment ?? current.alignment,
    fill: fill?.trim() ?? current.fill,
    outline: outline?.trim() ?? current.outline,
    outlineWidth: outlineWidth ?? current.outlineWidth,
  );
}

bool _isPlainDrawingText(InlineContent content, String text) =>
    content.items.length == 1 &&
    content.items.single is TextItem &&
    (content.items.single as TextItem).text == text &&
    (content.items.single as TextItem).attrs.isEmpty;

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
