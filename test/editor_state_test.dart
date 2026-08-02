import 'package:test/test.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/block_traversal.dart';
import 'package:taleweaver/src/core/state/find_matches.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/styles/tab_stops.dart';

void main() {
  test('editor reducer inserts text and records selection', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('hello'));
    expect(editor.selection.anchor.offset, 5);
    expect(editor.history.canUndo, isTrue);
    editor = reduceEditor(editor, const UndoAction());
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

  test('editor reducer inserts inline fields and tabs', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('x'));
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, const InsertTabAction());
    final items = getBlock(editor.state, paragraph)!.inlineContent!.items;
    expect(items.whereType<EmbedItem>().single.embedType, 'tab');
  });

  test('editor reducer creates a table through the table operation', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTableAction(2, 2));
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
  });

  test('editor reducer updates block image size, wrap and alt', () {
    var editor = createInitialEditorState();
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    editor = reduceEditor(editor, SetImageSizeAction(paragraph.value, 120, 80));
    editor = reduceEditor(editor, SetImageWrapAction(paragraph.value, 'left'));
    editor =
        reduceEditor(editor, SetImageAltAction(paragraph.value, 'diagram'));
    final attrs = getBlock(editor.state, paragraph)!.attrs;
    expect(attrs['width'], 120);
    expect(attrs['height'], 80);
    expect(attrs['wrap'], 'left');
    expect(attrs['alt'], 'diagram');
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
    final toc = getBlock(editor.state, paragraph)!.nextSiblingId!;
    expect(getBlock(editor.state, toc)!.type, 'table-of-contents');
  });

  test('editor reducer inserts header and footer template bodies', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertHeaderAction());
    final root = getBlock(editor.state, editor.state.rootId)!;
    expect(root.attrs['headerBlockId'], isA<String>());
    editor = reduceEditor(editor, const InsertFooterAction());
    expect(getBlock(editor.state, editor.state.rootId)!.attrs['footerBlockId'],
        isA<String>());
  });

  test('editor reducer inserts page fields and sets table headers', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertPageNumberAction());
    final paragraph =
        getBlock(editor.state, editor.state.rootId)!.firstChildId!;
    expect(
        getBlock(editor.state, paragraph)!
            .inlineContent!
            .items
            .whereType<EmbedItem>()
            .single
            .properties['fieldKind'],
        'page-number');
    editor = reduceEditor(editor, const InsertTableAction(2, 2));
    final table = iterateBlocksInDocumentOrder(editor.state)
        .firstWhere((block) => block.type == 'table')
        .id;
    editor = reduceEditor(editor, SetTableHeaderRowsAction(table.value, 1));
    expect(getBlock(editor.state, table)!.attrs['headerRowCount'], 1);
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
    expect(escaped.selection.focus.blockId, image.id);
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
    editor = reduceEditor(editor, const ToggleSectionLandscapeAction());
    final landscaped = getBlock(editor.state, editor.state.rootId)!;
    expect(landscaped.attrs['pageInlineSize'], isA<num>());
    expect(landscaped.attrs['pageBlockSize'], isA<num>());
  });

  test('invalid section column geometry is a no-op', () {
    final editor = createInitialEditorState();
    final reduced =
        reduceEditor(editor, const SetSectionColumnsAction(0, columnGap: -1));
    expect(identical(reduced.state, editor.state), isTrue);
    expect(reduced.history.canUndo, isFalse);
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
  });
}
