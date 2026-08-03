import 'dart:convert';

import 'package:test/test.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/editor/reconcile_foreign_change.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/block_traversal.dart';
import 'package:taleweaver/src/core/state/find_matches.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/styles/tab_stops.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/page_config.dart';
import 'package:taleweaver/src/core/state/serialize/json_serializer.dart';
import 'package:taleweaver/src/core/state/table_context.dart';
import 'package:taleweaver/src/core/state/ops/remove_block.dart';

String inlineContentToPlainText(InlineContent content) =>
    content.items.whereType<TextItem>().map((item) => item.text).join();

BlockId firstTableId(State state) => iterateBlocksInDocumentOrder(state)
    .firstWhere((block) => block.type == 'table')
    .id;

/// Builds a well-formed 2×2 table merged into one 2×2 cell.
///
/// This is intentionally made through the public reducer so the assertions
/// below exercise the same table-action route embedders use.
EditorState editorWithMergedTable() {
  var editor = createInitialEditorState();
  editor = reduceEditor(editor, const InsertTableAction(2, 2));
  final tableId = firstTableId(editor.state);
  return reduceEditor(editor, MergeCellsAction(tableId.value, 0, 1, 0, 1));
}

void main() {
  test('reconcileForeignChange refreshes dirty snapshots without local undo',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('remote baseline'));
    final selection = editor.selection;
    final history = editor.history;
    final dirty = {selection.focus.blockId};

    final next = reconcileForeignChange(editor, dirty);

    expect(next.state, isNot(same(editor.state)));
    expect(next.selection, same(selection));
    expect(next.history, same(history));
    expect(next.lastDirtyIds, dirty);
    expect(next.containerWidth, editor.containerWidth);
  });

  test('initial selection targets the first content-bearing leaf', () {
    final editor = createInitialEditorState();
    final block = getBlock(editor.state, editor.selection.focus.blockId);

    expect(block, isNotNull);
    expect(block!.inlineContent, isNotNull);
    expect(editor.selection.focus.offset, 0);
  });

  test('editor reducer inserts text and records selection', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('hello'));
    expect(editor.selection.anchor.offset, 5);
    expect(editor.history.canUndo, isTrue);
    editor = reduceEditor(editor, const UndoAction());
    expect(editor.selection.anchor.offset, 0);
  });

  test('paste normalizes line endings and creates sibling blocks', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const PasteTextAction('one\r\ntwo\n'));
    final leaves = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.inlineContent != null)
        .toList();
    expect(
        leaves.map((block) => inlineContentToPlainText(block.inlineContent!)),
        ['one', 'two', '']);
    expect(editor.selection.anchor.blockId, leaves.last.id);
    expect(editor.selection.anchor.offset, 0);
    expect(editor.history.canUndo, isTrue);
  });

  test('paste replaces a selection and places the caret after the last line',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('hello world'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 6),
        focus: Position(blockId: paragraph, offset: 11),
      )),
    );
    editor = reduceEditor(editor, const PasteTextAction('Dart\nrocks'));
    final leaves = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.inlineContent != null)
        .toList();
    expect(
        leaves.map((block) => inlineContentToPlainText(block.inlineContent!)),
        ['hello Dart', 'rocks']);
    expect(editor.selection.anchor.blockId, leaves.last.id);
    expect(editor.selection.anchor.offset, 5);
  });

  test('suggesting paste tags inserted text instead of deleting directly', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const PasteTextAction('tracked'),
      const EditorConfig(suggestingAuthor: 'alice'),
    );
    final paragraph = getBlock(editor.state, editor.selection.focus.blockId)!;
    final item = paragraph.inlineContent!.items.single as TextItem;
    expect(item.text, 'tracked');
    expect(item.attrs['insertionSuggestionId'], isA<String>());
    expect(editor.state.doc.suggestions, isNotEmpty);
    expect(editor.history.canUndo, isTrue);
  });

  test('suggesting insert text tracks caret insertion and replacement', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertTextAction('abc'),
      const EditorConfig(suggestingAuthor: 'alice'),
    );
    final blockId = editor.selection.focus.blockId;
    final tracked = getBlock(editor.state, blockId)!.inlineContent!.items.single
        as TextItem;
    expect(tracked.attrs['insertionSuggestionId'], isA<String>());

    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 1),
        focus: Position(blockId: blockId, offset: 2),
      )),
    );
    editor = reduceEditor(
      editor,
      const InsertTextAction('X'),
      const EditorConfig(suggestingAuthor: 'alice'),
    );
    expect(editor.selection.anchor.offset, 2);
    expect(editor.state.doc.suggestions.length, 1,
        reason: 'same-author insertion suggestions coalesce');
  });

  test('suggesting deletion marks a selected range instead of removing it', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final blockId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 1),
        focus: Position(blockId: blockId, offset: 2),
      )),
    );
    editor = reduceEditor(
      editor,
      const DeleteBackwardAction(),
      const EditorConfig(suggestingAuthor: 'alice'),
    );
    final items = getBlock(editor.state, blockId)!.inlineContent!.items;
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, blockId)!.inlineContent!),
        'abc');
    expect(
        items
            .whereType<TextItem>()
            .any((item) => item.attrs['deletionSuggestionId'] is String),
        isTrue);
  });

  test('suggesting formatting records a proposal without changing live attrs',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final blockId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      ApplyFormattingAction(
        Span(
          anchor: Position(blockId: blockId, offset: 0),
          focus: Position(blockId: blockId, offset: 3),
        ),
        const {'bold': true},
      ),
      const EditorConfig(suggestingAuthor: 'alice'),
    );
    final item = getBlock(editor.state, blockId)!.inlineContent!.items.single
        as TextItem;
    expect(item.attrs['bold'], isNull);
    expect(item.attrs['formattingSuggestionId'], isA<String>());
    expect(editor.state.doc.suggestions.values.single['proposedAttrs'],
        {'bold': true});
  });

  test('delete word uses the active selection before moving by word', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('one two'));
    final blockId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 3),
      )),
    );
    editor = reduceEditor(editor, const DeleteWordAction('forward'));
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, blockId)!.inlineContent!),
        ' two');
    expect(editor.selection.anchor.offset, 0);
  });

  test('editor reducer expands a word and deletes a range', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('one two'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 1),
      )),
    );
    editor = reduceEditor(editor, const ExpandWordAction('forward'));
    expect(editor.selection.focus.offset,
        greaterThan(editor.selection.anchor.offset));
  });

  test('editor reducer applies inline formatting through the range operation',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('bold'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      ApplyFormattingAction(
        Span(
          anchor: Position(blockId: paragraph, offset: 0),
          focus: Position(blockId: paragraph, offset: 4),
        ),
        const {'fontWeight': 'bold'},
      ),
    );
    expect(editor.history.canUndo, isTrue);
  });

  test('editor reducer toggles and clears inline styles', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('bold'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 0),
        focus: Position(blockId: paragraph, offset: 4),
      )),
    );
    editor = reduceEditor(editor, const ToggleStyleAction('bold'));
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .single
            .attrs['bold'],
        true);
    editor = reduceEditor(editor, const ClearFormattingAction());
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .single
            .attrs['bold'],
        isNull);
  });

  test('editor reducer applies link and text presentation actions', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('link'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 0),
        focus: Position(blockId: paragraph, offset: 4),
      )),
    );
    editor = reduceEditor(editor, const SetLinkAction('https://example.com'));
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .single
            .attrs['link'],
        'https://example.com');
    editor = reduceEditor(editor, const SetTextColorAction('#f00'));
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .single
            .attrs['color'],
        '#f00');
  });

  test('editor reducer updates list type and restart override', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const ToggleListAction('unordered'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, const SetListTypeAction('ordered'));
    editor = reduceEditor(editor, const SetListRestartAction(3));
    expect(getBlock(editor.state, paragraph)!.attrs['listCounterOverride'], 3);
  });

  test('editor reducer routes comment lifecycle actions', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('note'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 0),
        focus: Position(blockId: paragraph, offset: 4),
      )),
    );
    editor = reduceEditor(editor, const AddCommentAction('c1', 'A', 'body', 1));
    expect(editor.state.doc.comments['c1'], isNotNull);
    editor = reduceEditor(editor, const ResolveCommentAction('c1'));
    expect(editor.state.doc.comments['c1']!['resolved'], true);
    editor = reduceEditor(editor, const ReopenCommentAction('c1'));
    expect(editor.state.doc.comments['c1']!['resolved'], false);
    editor = reduceEditor(editor, const DeleteCommentAction('c1'));
    expect(editor.state.doc.comments['c1'], isNull);
  });

  test('adding a comment keeps the selected text and direction outside markers',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abcdef'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 4),
        focus: Position(blockId: paragraph, offset: 1),
      )),
    );

    editor = reduceEditor(editor, const AddCommentAction('c1', 'A', 'body', 1));

    expect(editor.selection.anchor, Position(blockId: paragraph, offset: 5));
    expect(editor.selection.focus, Position(blockId: paragraph, offset: 2));
  });

  test('comment commands reject collapsed selections as identity no-ops', () {
    final editor = createInitialEditorState();
    final next =
        reduceEditor(editor, const AddCommentAction('c1', 'A', 'body', 1));

    expect(next, same(editor));
    expect(next.state.doc.comments, isEmpty);
  });

  test('resolving suggestions is final and does not enter undo history', () {
    final config = EditorConfig(suggestingAuthor: 'Ada', now: () => 1);
    var editor = createInitialEditorState(config: config);
    editor = reduceEditor(editor, const InsertTextAction('draft'), config);
    final id = editor.state.doc.suggestions.keys.single;

    editor = reduceEditor(editor, AcceptSuggestionAction(id), config);

    expect(editor.state.doc.suggestions, isEmpty);
    final afterUndo = reduceEditor(editor, const UndoAction(), config);
    expect(
        inlineContentToPlainText(
            getBlock(afterUndo.state, afterUndo.selection.focus.blockId)!
                .inlineContent!),
        isEmpty);
    expect(afterUndo.history.canUndo, isFalse);
  });

  test('suggesting split creates a tracked break and places caret in new block',
      () {
    final config = EditorConfig(suggestingAuthor: 'Ada', now: () => 1);
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abcdef'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 3),
        focus: Position(blockId: paragraph, offset: 3),
      )),
    );

    editor = reduceEditor(editor, const SplitNodeAction(), config);

    final newBlock = getBlock(editor.state, paragraph)!.nextSiblingId!;
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, paragraph)!.inlineContent!),
        'abc');
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, newBlock)!.inlineContent!),
        'def');
    expect(getBlock(editor.state, paragraph)!.inlineContent!.items.last,
        isA<EmbedItem>());
    expect(editor.state.doc.suggestions, hasLength(1));
    expect(editor.selection.focus, Position(blockId: newBlock, offset: 0));

    editor = reduceEditor(editor, const UndoAction(), config);
    expect(getBlock(editor.state, paragraph)!.nextSiblingId, isNull);
    expect(editor.state.doc.suggestions, isEmpty);
  });

  test('suggesting split over a selection retains deleted text as a proposal',
      () {
    final config = EditorConfig(suggestingAuthor: 'Ada', now: () => 2);
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abcdef'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 4),
      )),
    );

    editor = reduceEditor(editor, const SplitNodeAction(), config);

    final original = getBlock(editor.state, paragraph)!;
    final suffix = original.nextSiblingId!;
    expect(inlineContentToPlainText(original.inlineContent!), 'abcd');
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, suffix)!.inlineContent!),
        'ef');
    expect(editor.state.doc.suggestions.values.map((record) => record['kind']),
        containsAll(<String>['deletion', 'insertion']));
    expect(editor.selection.focus, Position(blockId: suffix, offset: 0));
  });

  test('manual page break is serializable, undoable, and never a section', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('antes depois'));
    final originalId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: originalId, offset: 6),
        focus: Position(blockId: originalId, offset: 6),
      )),
    );
    editor = reduceEditor(editor, const PageBreakAction());

    final first = getBlock(editor.state, originalId)!;
    final followingId = first.nextSiblingId!;
    final following = getBlock(editor.state, followingId)!;
    expect(inlineContentToPlainText(first.inlineContent!), 'antes ');
    expect(inlineContentToPlainText(following.inlineContent!), 'depois');
    expect(following.attrs['breakBefore'], 'page');
    expect(
        iterateBlocksInDocumentOrder(editor.state)
            .where((block) => block.type == 'section'),
        isEmpty);

    final serializer = createJsonDocumentSerializer(
      allocator: createTestAllocator('manual-page-break-round-trip'),
      blockBlockKindResolver: createDefaultComponentRegistry(),
    );
    final encoded = serializer.encode(editor.state);
    final decoded = serializer.decode(encoded);
    final decodedFirst =
        getBlock(decoded, getBlock(decoded, decoded.rootId)!.firstChildId!)!;
    final decodedFollowing = getBlock(decoded, decodedFirst.nextSiblingId!)!;
    expect(decodedFollowing.attrs['breakBefore'], 'page');

    editor = reduceEditor(editor, const UndoAction());
    expect(getBlock(editor.state, originalId)!.nextSiblingId, isNull);
    expect(
        inlineContentToPlainText(
            getBlock(editor.state, originalId)!.inlineContent!),
        'antes depois');

    editor = reduceEditor(editor, const RedoAction());
    final redoneFollowing = getBlock(editor.state, originalId)!.nextSiblingId!;
    expect(
        getBlock(editor.state, redoneFollowing)!.attrs['breakBefore'], 'page');
  });

  test('editor reducer inserts inline fields and tabs', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('x'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, const InsertTabAction());
    final items = getBlock(editor.state, paragraph)!.inlineContent!.items;
    expect(items.whereType<EmbedItem>().single.embedType, 'tab');
    expect(editor.selection.focus.offset, 2);
  });

  test('tab insertion replaces a selected range and collapses after embed', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Span(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 2),
      )),
    );
    editor = reduceEditor(editor, const InsertTabAction());
    final items = getBlock(editor.state, paragraph)!.inlineContent!.items;
    expect(items.whereType<TextItem>().map((item) => item.text).join(), 'ac');
    expect(items.whereType<EmbedItem>().single.embedType, 'tab');
    expect(editor.selection.anchor.offset, 2);
    editor = reduceEditor(editor, const UndoAction());
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<TextItem>()
            .map((item) => item.text)
            .join(),
        'abc');
  });

  test('cross-reference insertion replaces selection and collapses after embed',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 2),
      )),
    );
    editor = reduceEditor(
      editor,
      InsertCrossReferenceAction(paragraph.value, 'text'),
    );
    final content = getBlock(editor.state, paragraph)!.inlineContent!;
    expect(content.items.whereType<TextItem>().map((item) => item.text).join(),
        'ac');
    expect(content.items.whereType<EmbedItem>().single.properties['refMode'],
        'text');
    expect(editor.selection.anchor.offset, 2);
    editor = reduceEditor(editor, const UndoAction());
    expect(getBlock(editor.state, paragraph)!.inlineContent!.items.single,
        isA<TextItem>());
  });

  test('footnote insertion replaces selection and moves caret into body', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 2),
      )),
    );
    editor = reduceEditor(editor, const InsertFootnoteAction());
    expect(editor.selection.anchor.offset, 0);
    expect(editor.selection.anchor.blockId, isNot(paragraph));
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<EmbedItem>()
            .single
            .embedType,
        'footnote-anchor');
  });

  test('editor reducer creates a table through the table operation', () {
    var editor = createInitialEditorState();
    final bodyParagraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      EditorState(
        state: editor.state,
        selection: Selection(
          anchor: Position(blockId: bodyParagraph, offset: 0),
          focus: Position(blockId: bodyParagraph, offset: 0),
        ),
        history: editor.history,
        containerWidth: editor.containerWidth,
      ),
      const InsertTableAction(2, 2),
    );
    final root = getBlock(editor.state, editor.state.rootId)!;
    expect(getBlock(editor.state, root.firstChildId!)!.type, 'table');
    editor = reduceEditor(editor, const InsertTableRowAction('below'));
    editor = reduceEditor(editor, const InsertTableColumnAction('right'));
    editor = reduceEditor(editor, const SplitCellAction());
    final table = getBlock(editor.state, root.firstChildId!)!;
    editor = reduceEditor(
      editor,
      MergeCellsAction(table.id.value, 0, 1, 0, 1),
    );
    expect(table.type, 'table');
    editor = reduceEditor(editor, const DeleteTableAction());
    expect(
        iterateBlocksInDocumentOrder(editor.state)
            .any((block) => block.type == 'table'),
        isFalse);
    expect(getBlock(editor.state, editor.selection.focus.blockId)!.type,
        'paragraph');
  });

  test('table reducer routes row insertion through the span-aware operation',
      () {
    final editor = editorWithMergedTable();
    final tableId = firstTableId(editor.state);
    final before =
        resolveTableContext(editor.state, editor.selection.focus.blockId)!;
    expect(before.spanned, isTrue);
    expect(before.ragged, isFalse);

    final next = reduceEditor(editor, const InsertTableRowAction('below'));
    final after =
        resolveTableContext(next.state, next.selection.focus.blockId)!;
    final rows = getChildIds(next.state, tableId);

    // The inserted boundary is below a cell spanning two columns. The
    // span-aware route must therefore create two physical cells, not clone the
    // source row's one merged cell and leave a ragged table.
    expect(rows, hasLength(3));
    expect(getChildIds(next.state, rows.last), hasLength(2));
    expect(after.ragged, isFalse);
    expect(next.selection, editor.selection);
  });

  test('table reducer routes column insertion through the span-aware operation',
      () {
    final editor = editorWithMergedTable();
    final tableId = firstTableId(editor.state);
    final before =
        resolveTableContext(editor.state, editor.selection.focus.blockId)!;
    expect(before.grid!.columnCount, 2);

    final next = reduceEditor(editor, const InsertTableColumnAction('right'));
    final after =
        resolveTableContext(next.state, next.selection.focus.blockId)!;
    final rows = getChildIds(next.state, tableId);

    // The lower grid row is covered by the merged cell and has no physical
    // cell before the edit. A plain row-cell-index route would fail there;
    // the span-aware route materializes the uncovered cell and keeps a 3-col
    // rectangular grid.
    expect(after.grid!.columnCount, 3);
    expect(getChildIds(next.state, rows[1]), hasLength(1));
    expect(after.ragged, isFalse);
    expect(next.selection, editor.selection);
  });

  test('table reducer routes row deletion through span-aware caret mapping',
      () {
    final editor = editorWithMergedTable();
    final before =
        resolveTableContext(editor.state, editor.selection.focus.blockId)!;
    final mergedCellId = before.cellId;
    final paragraphId = editor.selection.focus.blockId;

    final next = reduceEditor(editor, const DeleteTableRowAction());
    final after = resolveTableContext(next.state, paragraphId)!;

    // Deleting the originating row rehomes the surviving rowSpan cell. The
    // caret remains at its still-valid paragraph rather than the deleted row.
    expect(getBlock(next.state, mergedCellId), isNotNull);
    expect(getBlock(next.state, mergedCellId)!.attrs['rowSpan'], isNull);
    expect(after.rowIds, hasLength(1));
    expect(next.selection.focus, Position(blockId: paragraphId, offset: 0));
    expect(next.selection.anchor, Position(blockId: paragraphId, offset: 0));
  });

  test('table reducer routes column deletion through span-aware caret mapping',
      () {
    final editor = editorWithMergedTable();
    final before =
        resolveTableContext(editor.state, editor.selection.focus.blockId)!;
    final mergedCellId = before.cellId;
    final paragraphId = editor.selection.focus.blockId;

    final next = reduceEditor(editor, const DeleteTableColumnAction());
    final after = resolveTableContext(next.state, paragraphId)!;

    // The merged cell survives while its colSpan shrinks to one. A plain
    // delete would attempt to remove non-existent physical cells from the
    // covered row.
    expect(getBlock(next.state, mergedCellId), isNotNull);
    expect(getBlock(next.state, mergedCellId)!.attrs['colSpan'], isNull);
    expect(after.grid!.columnCount, 1);
    expect(next.selection.focus, Position(blockId: paragraphId, offset: 0));
    expect(next.selection.anchor, Position(blockId: paragraphId, offset: 0));
  });

  test('deleting the last table row deletes the table and targets its sibling',
      () {
    var editor = createInitialEditorState();
    final survivingParagraph = editor.selection.focus.blockId;
    editor = reduceEditor(editor, const InsertTableAction(1, 2));
    final tableId = firstTableId(editor.state);

    final next = reduceEditor(editor, const DeleteTableRowAction());

    expect(getBlock(next.state, tableId), isNull);
    expect(
        next.selection.focus, Position(blockId: survivingParagraph, offset: 0));
    expect(next.selection.anchor,
        Position(blockId: survivingParagraph, offset: 0));
  });

  test(
      'deleting the last table column deletes the table and targets its sibling',
      () {
    var editor = createInitialEditorState();
    final survivingParagraph = editor.selection.focus.blockId;
    editor = reduceEditor(editor, const InsertTableAction(2, 1));
    final tableId = firstTableId(editor.state);

    final next = reduceEditor(editor, const DeleteTableColumnAction());

    expect(getBlock(next.state, tableId), isNull);
    expect(
        next.selection.focus, Position(blockId: survivingParagraph, offset: 0));
    expect(next.selection.anchor,
        Position(blockId: survivingParagraph, offset: 0));
  });

  test('last table column replaces a sole table with a valid paragraph caret',
      () {
    var editor = createInitialEditorState();
    final originalParagraph = editor.selection.focus.blockId;
    editor = reduceEditor(editor, const InsertTableAction(1, 1));
    final tableId = firstTableId(editor.state);

    // Make the inserted table the body's sole child to exercise the
    // replacement-paragraph half of deleteTableWithReplacement.
    final withoutSibling = removeBlock(editor.state, originalParagraph);
    editor = EditorState(
      state: withoutSibling.state,
      selection: editor.selection,
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
    final table = getBlock(editor.state, tableId)!;
    expect(table.prevSiblingId, isNull);
    expect(table.nextSiblingId, isNull);

    final next = reduceEditor(editor, const DeleteTableColumnAction());
    final root = getBlock(next.state, next.state.rootId)!;
    final replacementId = root.firstChildId;

    expect(getBlock(next.state, tableId), isNull);
    expect(replacementId, isNotNull);
    expect(getBlock(next.state, replacementId!)!.type, 'paragraph');
    expect(next.selection.focus, Position(blockId: replacementId, offset: 0));
    expect(next.selection.anchor, Position(blockId: replacementId, offset: 0));
  });

  test('table insertion replaces a selected range before creating the table',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 2),
      )),
    );
    editor = reduceEditor(editor, const InsertTableAction(1, 1));
    expect(
        iterateBlocksInDocumentOrder(editor.state)
            .any((block) => block.type == 'table'),
        isTrue);
    expect(editor.selection.anchor.blockId, isNot(paragraph));
  });

  test('editor reducer inserts an inline image embed', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
        editor, const InsertInlineImageAction('img.png', 32, 24, 'thumbnail'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    final image = getBlock(editor.state, paragraph)!
        .inlineContent!
        .items
        .whereType<EmbedItem>()
        .single;
    expect(image.embedType, 'inline-image');
    expect(image.properties['src'], 'img.png');
    expect(editor.selection.focus.offset, 1);
  });

  test(
      'inline image insertion replaces a selected range and collapses after it',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Span(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 2),
      )),
    );
    editor = reduceEditor(
        editor, const InsertInlineImageAction('img.png', 20, 10, 'alt'));
    final items = getBlock(editor.state, paragraph)!.inlineContent!.items;
    expect(items.whereType<TextItem>().map((item) => item.text).join(), 'ac');
    expect(items.whereType<EmbedItem>(), hasLength(1));
    expect(editor.selection.anchor.offset, 2);
    expect(editor.selection.focus.offset, 2);
    editor = reduceEditor(editor, const UndoAction());
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<TextItem>()
            .map((item) => item.text)
            .join(),
        'abc');
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<EmbedItem>(),
        isEmpty);
  });

  test('editor reducer inserts a block image', () {
    var editor = createInitialEditorState();
    editor =
        reduceEditor(editor, const InsertImageAction('photo.png', width: 120));
    final root = getBlock(editor.state, editor.state.rootId)!;
    final types = <String>[];
    var id = root.firstChildId;
    while (id != null) {
      final block = getBlock(editor.state, id)!;
      types.add(block.type);
      id = block.nextSiblingId;
    }
    expect(types, contains('image'));
    expect(getBlock(editor.state, editor.selection.focus.blockId)!.type,
        'paragraph');
    expect(editor.selection.focus.offset, 0);
    editor = reduceEditor(editor, const DeleteBackwardAction());
    expect(
        iterateBlocksInDocumentOrder(editor.state)
            .any((block) => block.type == 'image'),
        isFalse);
  });

  test('editor reducer updates block image size, wrap and alt', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertImageAction('photo.png'));
    final image = iterateBlocksInDocumentOrder(editor.state)
        .firstWhere((block) => block.type == 'image');
    editor = reduceEditor(editor, SetImageSizeAction(image.id.value, 120, 80));
    editor = reduceEditor(editor, SetImageWrapAction(image.id.value, 'left'));
    editor = reduceEditor(editor, SetImageAltAction(image.id.value, 'diagram'));
    final attrs = getBlock(editor.state, image.id)!.attrs;
    expect(attrs['width'], 120);
    expect(attrs['height'], 80);
    expect(attrs['wrap'], 'left');
    expect(attrs['alt'], 'diagram');
  });

  test('image actions reject invalid targets, dimensions and wraps', () {
    final editor = createInitialEditorState();
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    final invalidTarget =
        reduceEditor(editor, SetImageSizeAction(paragraph.value, 120, 80));
    expect(identical(invalidTarget.state, editor.state), isTrue);
    final inserted = reduceEditor(editor, const InsertImageAction('photo.png'));
    final image = iterateBlocksInDocumentOrder(inserted.state)
        .firstWhere((block) => block.type == 'image');
    final invalidSize = reduceEditor(
        inserted, SetImageSizeAction(image.id.value, double.nan, 80));
    expect(identical(invalidSize.state, inserted.state), isTrue);
    final invalidWrap =
        reduceEditor(inserted, SetImageWrapAction(image.id.value, 'around'));
    expect(identical(invalidWrap.state, inserted.state), isTrue);
  });

  test('editor reducer inserts horizontal line and table of contents blocks',
      () {
    var editor = createInitialEditorState();
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, const InsertHorizontalLineAction());
    final line = getBlock(editor.state, paragraph)!.nextSiblingId!;
    expect(getBlock(editor.state, line)!.type, 'horizontal-line');
    editor = reduceEditor(editor, const InsertTableOfContentsAction());
    expect(
        iterateBlocksInDocumentOrder(editor.state)
            .any((block) => block.type == 'table-of-contents'),
        isTrue);
    expect(getBlock(editor.state, editor.selection.focus.blockId)!.type,
        'paragraph');
  });

  test('editor reducer inserts header and footer template bodies', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertHeaderAction());
    final root = getBlock(editor.state, editor.state.rootId)!;
    final headerId = root.attrs['headerBlockId'];
    expect(headerId, isA<String>());
    expect(editor.selection.anchor.offset, 0);
    final repeated = reduceEditor(editor, const InsertHeaderAction());
    expect(identical(repeated.state, editor.state), isTrue);
    expect(repeated.selection.anchor.blockId, editor.selection.anchor.blockId);
    editor = reduceEditor(editor, const InsertFooterAction());
    expect(getBlock(editor.state, editor.state.rootId)!.attrs['footerBlockId'],
        isA<String>());
  });

  test('editor reducer inserts page fields and sets table headers', () {
    var editor = createInitialEditorState();
    final bodyBefore = editor.state;
    editor = reduceEditor(editor, const InsertPageNumberAction());
    expect(identical(editor.state, bodyBefore), isTrue,
        reason: 'page fields are valid only in template content');
    final template = insertTemplateBody(
      editor.state,
      InsertTemplateBodyArgs(
        region: 'header',
        sectionBlockId: editor.state.rootId,
      ),
      productionAllocator,
    );
    editor = EditorState(
      state: template.state,
      selection: Selection(
        anchor: Position(blockId: template.firstParagraphId, offset: 0),
        focus: Position(blockId: template.firstParagraphId, offset: 0),
      ),
      history: editor.history,
      containerWidth: editor.containerWidth,
    );
    editor = reduceEditor(editor, const InsertPageNumberAction());
    final paragraph = template.firstParagraphId;
    expect(
        getTemplateContent(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<EmbedItem>()
            .single
            .properties['fieldKind'],
        'page-number');
  });

  test('editor coalesces nearby insertions and preserves first/last selection',
      () {
    var tick = 0;
    const config = EditorConfig();
    var editor = createInitialEditorState(config: config);
    editor = reduceEditor(
        editor, const InsertTextAction('a'), EditorConfig(now: () => tick));
    tick += 10;
    editor = reduceEditor(
        editor, const InsertTextAction('b'), EditorConfig(now: () => tick));
    editor =
        reduceEditor(editor, const UndoAction(), EditorConfig(now: () => tick));
    expect(editor.selection.anchor.offset, 0);
    expect(editor.history.canUndo, isFalse);
  });

  test('no-op edit does not create an undo item', () {
    var editor = createInitialEditorState();
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(
        editor,
        ApplyFormattingAction(
          Span(
              anchor: Position(blockId: paragraph, offset: 0),
              focus: Position(blockId: paragraph, offset: 0)),
          <String, dynamic>{},
        ));
    expect(editor.history.canUndo, isFalse);
  });

  test(
      'document boundary and select-all actions use leaf block geometry-free positions',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('one two'));
    editor = reduceEditor(editor, const SelectAllAction());
    expect(editor.selection.anchor.offset, 0);
    expect(editor.selection.focus.offset, 7);
    editor = reduceEditor(editor, const MoveDocumentBoundaryAction('start'));
    expect(isCollapsed(editor.selection), isTrue);
    expect(editor.selection.anchor.offset, 0);
    editor = reduceEditor(editor, const MoveDocumentBoundaryAction('end'));
    expect(editor.selection.anchor.offset, 7);
  });

  test('delete-word removes the adjacent word using UTF-16 offsets', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('one two'));
    editor = reduceEditor(editor, const DeleteWordAction('backward'));
    expect(editor.selection.anchor.offset, 4);
  });

  test('expand document boundary preserves anchor and changes only focus', () {
    var editor = createInitialEditorState();
    final paragraph = editor.selection.focus.blockId;
    editor = reduceEditor(editor, const InsertTextAction('abc'));
    editor = reduceEditor(editor, const ExpandDocumentBoundaryAction('start'));
    expect(editor.selection.anchor.blockId, paragraph);
    expect(editor.selection.anchor.offset, 3);
    expect(editor.selection.focus.blockId, paragraph);
    expect(editor.selection.focus.offset, 0);
  });

  test('container width action updates layout input without history mutation',
      () {
    final editor = createInitialEditorState();
    final resized = reduceEditor(editor, const SetContainerWidthAction(640));
    expect(resized.containerWidth, 640);
    expect(resized.history.undo(), isNull);
    expect(reduceEditor(resized, const SetContainerWidthAction(-1)),
        same(resized));
  });

  test('insert-node builds a registered subtree', () {
    final editor = reduceEditor(
      createInitialEditorState(),
      const InsertNodeAction(
        BlockInit(
          type: 'section',
          children: [BlockInit(type: 'paragraph')],
        ),
      ),
    );
    final root = getBlock(editor.state, editor.state.rootId)!;
    final section = getBlock(editor.state, root.lastChildId!)!;
    expect(section.type, 'section');
    final paragraph = getBlock(editor.state, section.firstChildId!)!;
    expect(paragraph.type, 'paragraph');
    expect(paragraph.inlineContent, isNotNull);
    expect(editor.lastDirtyIds, contains(section.id));
    expect(editor.lastDirtyIds, contains(paragraph.id));
  });

  test('insert-node preserves leaf inline content and rejects invalid shapes',
      () {
    final initial = createInitialEditorState();
    final inserted = reduceEditor(
      initial,
      const InsertNodeAction(BlockInit(
        type: 'paragraph',
        attrs: {'role': 'body'},
        inlineContent: InlineContent([
          TextItem(text: 'hello', attrs: {'bold': true}),
        ]),
      )),
    );
    final block = getBlock(inserted.state,
        getBlock(inserted.state, inserted.state.rootId)!.lastChildId!)!;
    expect(block.attrs['role'], 'body');
    expect(block.inlineContent!.items.single, isA<TextItem>());
    expect((block.inlineContent!.items.single as TextItem).text, 'hello');
    expect(
      () => reduceEditor(
        initial,
        const InsertNodeAction(BlockInit(
          type: 'paragraph',
          children: [BlockInit(type: 'paragraph')],
        )),
      ),
      throwsStateError,
    );
    expect(
      () => reduceEditor(
        initial,
        const InsertNodeAction(BlockInit(
          type: 'image',
          inlineContent: InlineContent([TextItem(text: 'x')]),
        )),
      ),
      throwsStateError,
    );
  });

  test('insert-node honors the configured component registry', () {
    final registry = createComponentRegistry();
    expect(
      () => reduceEditor(
        createInitialEditorState(),
        const InsertNodeAction(BlockInit(type: 'paragraph')),
        EditorConfig(componentRegistry: registry),
      ),
      throwsStateError,
    );
  });

  test('insert-node participates in undo and redo history', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertNodeAction(BlockInit(type: 'paragraph')),
    );
    final insertedId = getBlock(editor.state, editor.state.rootId)!.lastChildId;
    expect(insertedId, isNotNull);
    expect(editor.history.canUndo, isTrue);
    final undone = editor.history.undo();
    expect(undone, isNotNull);
    expect(undone!.dirtyIds, contains(insertedId));
    expect(editor.history.canRedo, isTrue);
  });

  test('escape moves an atomic object selection to the next text block', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertImageAction('photo.png'));
    editor = reduceEditor(editor, const InsertTextAction('after'));
    final image = iterateBlocksInDocumentOrder(editor.state)
        .firstWhere((block) => block.type == 'image');
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: image.id, offset: 0),
        focus: Position(blockId: image.id, offset: 0),
      )),
    );
    final escaped = reduceEditor(editor, const EscapeAction());
    expect(escaped.selection.focus.blockId,
        getBlock(escaped.state, image.id)!.nextSiblingId);
    expect(escaped.selection.focus.offset, 0);
  });

  test('set-block-type changes the selected leaf through the registered schema',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const SetBlockTypeAction('heading'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    expect(getBlock(editor.state, paragraph)!.type, 'heading');
  });

  test('heading level converts text blocks and preserves relevant formatting',
      () {
    var editor = createInitialEditorState();
    final blockId = editor.selection.focus.blockId;
    editor = reduceEditor(editor, const SetTextAlignAction('center'));
    editor = reduceEditor(editor, const SetLineSpacingAction(1.5));
    editor =
        reduceEditor(editor, const SetParagraphSpacingAction('before', 12));
    editor = reduceEditor(editor, const ToggleListAction('ordered'));
    editor = reduceEditor(editor, const ListIndentAction());
    editor = reduceEditor(editor, const SetListRestartAction(3));

    final listed = getBlock(editor.state, blockId)!;
    expect(listed.type, 'list-item');
    expect(listed.attrs['listId'], isA<String>());
    expect(listed.attrs['listLevel'], 1);
    expect(listed.attrs['listCounterOverride'], 3);

    editor = reduceEditor(editor, const SetHeadingLevelAction(3));
    final heading = getBlock(editor.state, blockId)!;
    expect(heading.type, 'heading');
    expect(heading.attrs['level'], 3);
    expect(heading.attrs['textAlign'], 'center');
    expect(heading.attrs['lineHeight'], 1.5);
    expect(heading.attrs['marginBlockStart'], 12);
    expect(heading.attrs.containsKey('listId'), isFalse);
    expect(heading.attrs.containsKey('listLevel'), isFalse);
    expect(heading.attrs.containsKey('listCounterOverride'), isFalse);
    expect(editor.lastDirtyIds, contains(blockId));

    editor = reduceEditor(editor, const UndoAction());
    final restored = getBlock(editor.state, blockId)!;
    expect(restored.type, 'list-item');
    expect(restored.attrs['listId'], listed.attrs['listId']);
    expect(restored.attrs['listLevel'], 1);
    expect(restored.attrs['listCounterOverride'], 3);
    expect(restored.attrs['textAlign'], 'center');

    editor = reduceEditor(editor, const RedoAction());
    final redone = getBlock(editor.state, blockId)!;
    expect(redone.type, 'heading');
    expect(redone.attrs['level'], 3);
    expect(redone.attrs.containsKey('listId'), isFalse);
  });

  test('heading level rejects invalid and non-convertible selections', () {
    final editor = createInitialEditorState();
    final invalid = reduceEditor(editor, const SetHeadingLevelAction(0));
    expect(identical(invalid, editor), isTrue);

    final levelSeven = reduceEditor(editor, const SetHeadingLevelAction(7));
    expect(identical(levelSeven, editor), isTrue);

    final withoutHeading = reduceEditor(
      editor,
      const SetHeadingLevelAction(1),
      EditorConfig(componentRegistry: createComponentRegistry()),
    );
    expect(identical(withoutHeading, editor), isTrue);

    var tableEditor = reduceEditor(editor, const InsertTableAction(1, 1));
    final cell = iterateBlocksInDocumentOrder(tableEditor.state)
        .firstWhere((block) => block.type == 'table-cell');
    tableEditor = reduceEditor(
      tableEditor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: cell.id, offset: 0),
        focus: Position(blockId: cell.id, offset: 0),
      )),
    );
    final tableCell = reduceEditor(tableEditor, const SetHeadingLevelAction(2));
    expect(identical(tableCell, tableEditor), isTrue);

    var headingEditor = reduceEditor(editor, const SetHeadingLevelAction(2));
    final unchanged =
        reduceEditor(headingEditor, const SetHeadingLevelAction(2));
    expect(identical(unchanged, headingEditor), isTrue);
  });

  test('toggle-list converts a paragraph to a list item and back', () {
    var editor = createInitialEditorState();
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, const ToggleListAction('unordered'));
    expect(getBlock(editor.state, paragraph)!.type, 'list-item');
    expect(getBlock(editor.state, paragraph)!.attrs['listId'], isA<String>());
    editor = reduceEditor(editor, const ToggleListAction('unordered'));
    expect(getBlock(editor.state, paragraph)!.type, 'paragraph');
    expect(getBlock(editor.state, paragraph)!.attrs.containsKey('listId'),
        isFalse);
  });
  test('paragraph alignment, spacing and indentation actions', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const SetTextAlignAction('center'));
    final id = editor.selection.focus.blockId;
    expect(getBlock(editor.state, id)!.attrs['textAlign'], 'center');
    editor = reduceEditor(editor, const SetLineSpacingAction(1.5));
    expect(getBlock(editor.state, id)!.attrs['lineHeight'], 1.5);
    editor = reduceEditor(editor, const SetParagraphSpacingAction('after', 12));
    expect(getBlock(editor.state, id)!.attrs['marginBlockEnd'], 12);
    editor = reduceEditor(editor, const IndentAction());
    expect(getBlock(editor.state, id)!.attrs['marginInlineStart'], 48.0);
    editor = reduceEditor(editor, const OutdentAction());
    expect(getBlock(editor.state, id)!.attrs.containsKey('marginInlineStart'),
        false);
  });

  test('precise paragraph indents apply to selected text blocks and undo', () {
    var editor = createInitialEditorState();
    final first = editor.selection.focus.blockId;
    editor = reduceEditor(
        editor, const InsertNodeAction(BlockInit(type: 'paragraph')));
    final second = getBlock(editor.state, editor.state.rootId)!.lastChildId!;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: first, offset: 0),
        focus: Position(blockId: second, offset: 0),
      )),
    );

    editor = reduceEditor(
        editor, const SetParagraphIndentsAction(36.0, 18.0, -12.0));
    for (final id in [first, second]) {
      final attrs = getBlock(editor.state, id)!.attrs;
      expect(attrs['marginInlineStart'], 36.0);
      expect(attrs['marginInlineEnd'], 18.0);
      expect(attrs['textIndent'], -12.0);
    }
    expect(editor.lastDirtyIds, containsAll([first, second]));
    expect(editor.history.canUndo, isTrue);

    editor = reduceEditor(editor, const UndoAction());
    for (final id in [first, second]) {
      final attrs = getBlock(editor.state, id)!.attrs;
      expect(attrs.containsKey('marginInlineStart'), isFalse);
      expect(attrs.containsKey('marginInlineEnd'), isFalse);
      expect(attrs.containsKey('textIndent'), isFalse);
    }

    editor = reduceEditor(editor, const RedoAction());
    expect(getBlock(editor.state, first)!.attrs['textIndent'], -12.0);
    expect(getBlock(editor.state, second)!.attrs['marginInlineEnd'], 18.0);
  });

  test('precise paragraph indents clear direct values and reject invalid edges',
      () {
    var editor = createInitialEditorState();
    editor =
        reduceEditor(editor, const SetParagraphIndentsAction(36.0, 18.0, 12.0));
    final id = editor.selection.focus.blockId;
    editor =
        reduceEditor(editor, const SetParagraphIndentsAction(null, null, null));
    final attrs = getBlock(editor.state, id)!.attrs;
    expect(attrs.containsKey('marginInlineStart'), isFalse);
    expect(attrs.containsKey('marginInlineEnd'), isFalse);
    expect(attrs.containsKey('textIndent'), isFalse);

    final invalid =
        reduceEditor(editor, const SetParagraphIndentsAction(-1.0, 0.0, 0.0));
    expect(identical(invalid, editor), isTrue);
  });

  test('invalid paragraph alignment is a no-op', () {
    final editor = createInitialEditorState();
    final reduced = reduceEditor(editor, const SetTextAlignAction('diagonal'));
    expect(identical(reduced.state, editor.state), isTrue);
    expect(reduced.state, same(editor.state));
  });

  test('replace and tab-stop actions use existing state operations', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('hello world'));
    final blockId = editor.selection.focus.blockId;
    final match = TextMatch(blockId, 0, 5, 'hello');
    editor = reduceEditor(editor, ReplaceMatchAction(match, 'hi'));
    final content = getBlock(editor.state, blockId)!.inlineContent!;
    expect(content.items.whereType<TextItem>().map((item) => item.text).join(),
        'hi world');
    expect(editor.selection.anchor.offset, 2);
    editor = reduceEditor(
      editor,
      ReplaceAllAction([TextMatch(blockId, 3, 8, 'world')], 'earth'),
    );
    expect(
        getBlock(editor.state, blockId)!
            .inlineContent!
            .items
            .whereType<TextItem>()
            .map((item) => item.text)
            .join(),
        'hi earth');
    expect(editor.selection.anchor.offset, 3);
  });

  test('tab-stop actions normalize position and order', () {
    var editor = createInitialEditorState();
    final blockId = editor.selection.focus.blockId.value;
    editor = reduceEditor(
      editor,
      SetTabStopsAction(
        blockId,
        const [
          TabStop(
              position: -4,
              alignment: TabAlignment.right,
              leader: LeaderStyle.dot),
          TabStop(
              position: 24,
              alignment: TabAlignment.left,
              leader: LeaderStyle.none),
        ],
      ),
    );
    final value = getBlock(editor.state, editor.selection.focus.blockId)!
        .attrs['tabStops'] as List<TabStop>;
    expect(value.map((stop) => stop.position), [0, 24]);
  });

  test('invalid table dimensions are a no-op', () {
    final editor = createInitialEditorState();
    final reduced = reduceEditor(editor, const InsertTableAction(0, 2));
    expect(identical(reduced.state, editor.state), isTrue);
    expect(reduced.history.canUndo, isFalse);
  });

  test('section geometry actions update column and landscape attrs', () {
    var editor = createInitialEditorState();
    editor =
        reduceEditor(editor, const SetSectionColumnsAction(2, columnGap: 24));
    final root = getBlock(editor.state, editor.state.rootId)!;
    expect(root.attrs['columnCount'], 2);
    expect(root.attrs['columnGap'], 24);
    final unchanged = reduceEditor(editor, const ToggleSectionLandscapeAction(),
        EditorConfig(pageConfig: PageConfig()));
    expect(identical(unchanged.state, editor.state), isTrue,
        reason: 'landscape requires an active section');
  });

  test('invalid section column geometry is a no-op', () {
    final editor = createInitialEditorState();
    final reduced =
        reduceEditor(editor, const SetSectionColumnsAction(0, columnGap: -1));
    expect(identical(reduced.state, editor.state), isTrue);
    expect(reduced.history.canUndo, isFalse);
  });

  test('active page margins persist as logical JSON data and undo/redo', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const SetActivePageMarginsAction(<String, dynamic>{
        'blockStart': 54,
        'blockEnd': 63.5,
        'inlineStart': 45,
        'inlineEnd': 36,
      }),
    );

    final rootId = editor.state.rootId;
    expect(getBlock(editor.state, rootId)!.attrs['pageMargins'], {
      'blockStart': 54.0,
      'blockEnd': 63.5,
      'inlineStart': 45.0,
      'inlineEnd': 36.0,
    });
    expect(editor.history.canUndo, isTrue);

    final serializer = createJsonDocumentSerializer(
      allocator: createTestAllocator('page-margins-round-trip'),
      blockBlockKindResolver: createDefaultComponentRegistry(),
    );
    final encoded = serializer.encode(editor.state);
    final encodedMargins = (jsonDecode(encoded) as Map<String, dynamic>)['root']
        ['attrs']['pageMargins'] as Map<String, dynamic>;
    expect(encodedMargins, {
      'blockStart': 54.0,
      'blockEnd': 63.5,
      'inlineStart': 45.0,
      'inlineEnd': 36.0,
    });
    final roundTripped = serializer.decode(encoded);
    expect(getBlock(roundTripped, roundTripped.rootId)!.attrs['pageMargins'], {
      'blockStart': 54.0,
      'blockEnd': 63.5,
      'inlineStart': 45.0,
      'inlineEnd': 36.0,
    });

    editor = reduceEditor(editor, const UndoAction());
    expect(getBlock(editor.state, rootId)!.attrs.containsKey('pageMargins'),
        isFalse);
    editor = reduceEditor(editor, const RedoAction());
    expect(getBlock(editor.state, rootId)!.attrs['pageMargins'], {
      'blockStart': 54.0,
      'blockEnd': 63.5,
      'inlineStart': 45.0,
      'inlineEnd': 36.0,
    });
  });

  test('active page margins target the current section before the root', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('first'));
    editor = reduceEditor(editor, const SplitNodeAction());
    editor = reduceEditor(editor, const SectionBreakAction());

    final focused = getBlock(editor.state, editor.selection.focus.blockId)!;
    final section = ancestorChain(editor.state, focused)
        .firstWhere((block) => block.type == 'section');
    editor = reduceEditor(
      editor,
      SetActivePageMarginsAction.physical(
        top: 24,
        right: 30,
        bottom: 36,
        left: 42,
      ),
    );

    expect(getBlock(editor.state, section.id)!.attrs['pageMargins'], {
      'blockStart': 24.0,
      'blockEnd': 36.0,
      'inlineStart': 42.0,
      'inlineEnd': 30.0,
    });
    expect(
        getBlock(editor.state, editor.state.rootId)!
            .attrs
            .containsKey('pageMargins'),
        isFalse);
  });

  test('invalid or non-fitting active page margins are no-ops', () {
    final editor = createInitialEditorState();
    final malformed = reduceEditor(
      editor,
      const SetActivePageMarginsAction(<String, dynamic>{
        'blockStart': 20,
        'blockEnd': 20,
        'inlineStart': 20,
      }),
    );
    expect(identical(malformed.state, editor.state), isTrue);
    expect(malformed.history.canUndo, isFalse);

    final nonFinite = reduceEditor(
      editor,
      SetActivePageMarginsAction.values(
        blockStart: double.nan,
        blockEnd: 20,
        inlineStart: 20,
        inlineEnd: 20,
      ),
    );
    expect(identical(nonFinite.state, editor.state), isTrue);

    final doesNotFit = reduceEditor(
      editor,
      SetActivePageMarginsAction.values(
        blockStart: 20,
        blockEnd: 20,
        inlineStart: 50,
        inlineEnd: 50,
      ),
      const EditorConfig(pageConfig: PageConfig(width: 100, height: 100)),
    );
    expect(identical(doesNotFit.state, editor.state), isTrue);
    expect(doesNotFit.history.canUndo, isFalse);
  });

  test('active page size persists as JSON data and undo/redo restores it', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const SetActivePageSizeAction(595, 842));

    final rootId = editor.state.rootId;
    expect(getBlock(editor.state, rootId)!.attrs['pageInlineSize'], 595.0);
    expect(getBlock(editor.state, rootId)!.attrs['pageBlockSize'], 842.0);
    expect(editor.history.canUndo, isTrue);

    final serializer = createJsonDocumentSerializer(
      allocator: createTestAllocator('page-size-round-trip'),
      blockBlockKindResolver: createDefaultComponentRegistry(),
    );
    final encoded = serializer.encode(editor.state);
    final encodedAttrs = (jsonDecode(encoded) as Map<String, dynamic>)['root']
        ['attrs'] as Map<String, dynamic>;
    expect(encodedAttrs['pageInlineSize'], 595.0);
    expect(encodedAttrs['pageBlockSize'], 842.0);
    final roundTripped = serializer.decode(encoded);
    expect(getBlock(roundTripped, roundTripped.rootId)!.attrs['pageInlineSize'],
        595.0);
    expect(getBlock(roundTripped, roundTripped.rootId)!.attrs['pageBlockSize'],
        842.0);

    editor = reduceEditor(editor, const UndoAction());
    expect(getBlock(editor.state, rootId)!.attrs.containsKey('pageInlineSize'),
        isFalse);
    expect(getBlock(editor.state, rootId)!.attrs.containsKey('pageBlockSize'),
        isFalse);
    editor = reduceEditor(editor, const RedoAction());
    expect(getBlock(editor.state, rootId)!.attrs['pageInlineSize'], 595.0);
    expect(getBlock(editor.state, rootId)!.attrs['pageBlockSize'], 842.0);
  });

  test('active page size targets the current section before the root', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('first'));
    editor = reduceEditor(editor, const SplitNodeAction());
    editor = reduceEditor(editor, const SectionBreakAction());

    final focused = getBlock(editor.state, editor.selection.focus.blockId)!;
    final section = ancestorChain(editor.state, focused)
        .firstWhere((block) => block.type == 'section');
    editor = reduceEditor(editor, const SetActivePageSizeAction(792, 612));

    expect(getBlock(editor.state, section.id)!.attrs['pageInlineSize'], 792.0);
    expect(getBlock(editor.state, section.id)!.attrs['pageBlockSize'], 612.0);
    expect(
        getBlock(editor.state, editor.state.rootId)!
            .attrs
            .containsKey('pageInlineSize'),
        isFalse);
  });

  test('invalid or margin-collapsing active page sizes are no-ops', () {
    var editor = createInitialEditorState();
    final invalid = reduceEditor(
      editor,
      const SetActivePageSizeAction(0, 792),
    );
    expect(identical(invalid.state, editor.state), isTrue);
    expect(invalid.history.canUndo, isFalse);

    editor = reduceEditor(
      editor,
      SetActivePageMarginsAction.physical(
        top: 36,
        right: 54,
        bottom: 36,
        left: 54,
      ),
    );
    final collapsed = reduceEditor(
      editor,
      const SetActivePageSizeAction(108, 72),
    );
    expect(identical(collapsed.state, editor.state), isTrue);
    expect(collapsed.history.canUndo, isTrue,
        reason: 'the prior margin action remains undoable');

    final nonFinite = reduceEditor(
      editor,
      SetActivePageSizeAction(double.infinity, 792),
    );
    expect(identical(nonFinite.state, editor.state), isTrue);
  });

  test('invalid line and paragraph spacing are no-ops', () {
    final editor = createInitialEditorState();
    final invalidLine =
        reduceEditor(editor, const SetLineSpacingAction(double.nan));
    expect(identical(invalidLine.state, editor.state), isTrue);
    final invalidEdge =
        reduceEditor(editor, const SetParagraphSpacingAction('sideways', 4));
    expect(identical(invalidEdge.state, editor.state), isTrue);
  });

  test('footnote policy action validates and writes root attrs', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
        editor,
        const SetFootnotePolicyAction(
            reset: 'restart-per-page', format: 'upper-roman'));
    final root = getBlock(editor.state, editor.state.rootId)!;
    expect(root.attrs['footnoteNumberingReset'], 'restart-per-page');
    expect(root.attrs['footnoteNumberingFormat'], 'upper-roman');
    final unchanged = reduceEditor(
        editor, const SetFootnotePolicyAction(reset: 'invalid-value'));
    expect(identical(unchanged.state, editor.state), isTrue);
    final repeated = reduceEditor(
        editor,
        const SetFootnotePolicyAction(
            reset: 'restart-per-page', format: 'upper-roman'));
    expect(identical(repeated.state, editor.state), isTrue);
  });
}
