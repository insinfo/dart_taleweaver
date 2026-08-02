import 'package:test/test.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/ops/insert_footnote.dart';
import 'package:taleweaver/src/core/state/find_matches.dart';
import 'package:taleweaver/src/core/state/ops/insert_inline_image.dart';
import 'package:taleweaver/src/core/state/ops/insert_page_field.dart';
import 'package:taleweaver/src/core/state/ops/insert_tab.dart';
import 'package:taleweaver/src/core/state/ops/insert_blocks_after.dart';
import 'package:taleweaver/src/core/state/ops/insert_items.dart';
import 'package:taleweaver/src/core/state/ops/replace_matches.dart';
import 'package:taleweaver/src/core/state/ops/replace_block_with_text.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/ops/create_table.dart';
import 'package:taleweaver/src/core/state/ops/insert_table_row.dart';
import 'package:taleweaver/src/core/state/ops/insert_table_column.dart';
import 'package:taleweaver/src/core/state/ops/delete_table_row.dart';
import 'package:taleweaver/src/core/state/ops/delete_table_column.dart';
import 'package:taleweaver/src/core/state/ops/insert_table_row_span_aware.dart';
import 'package:taleweaver/src/core/state/ops/delete_table_row_span_aware.dart';
import 'package:taleweaver/src/core/state/ops/set_block_attrs.dart';
import 'package:taleweaver/src/core/state/ops/insert_table_column_span_aware.dart';
import 'package:taleweaver/src/core/state/ops/delete_table_column_span_aware.dart';
import 'package:taleweaver/src/core/state/ops/insert_new_blocks.dart';
import 'package:taleweaver/src/core/state/ops/merge_block_attrs.dart';
import 'package:taleweaver/src/core/state/ops/insert_comment_markers.dart';
import 'package:taleweaver/src/core/state/comments.dart';
import 'package:taleweaver/src/core/state/ops/section_break.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/ops/merge_cells.dart';
import 'package:taleweaver/src/core/state/table_cell_range.dart';
import 'package:taleweaver/src/core/state/ops/merge_section.dart';
import 'package:taleweaver/src/core/state/ops/insert_cross_reference.dart';
import 'package:taleweaver/src/core/state/ops/suggestion_ops/insert.dart';
import 'package:taleweaver/src/core/state/suggestions.dart';
import 'package:taleweaver/src/core/state/table_context.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/block_id.dart';

void main() {
  test('inline insertion operations preserve ordered content', () {
    final state = createEmptyDocument(allocator: createTestAllocator('ops'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final position = Position(blockId: paragraph, offset: 0);
    insertTab(state, position);
    insertPageField(state, position, 'page');
    insertInlineImage(
        state,
        position,
        const InlineImageProperties(
            src: 'x.png', width: 10, height: 10, alt: 'x'));
    final content = getBlock(state, paragraph)!.inlineContent!;
    expect(content.items.whereType<EmbedItem>(), hasLength(3));
  });

  test('footnote insertion creates anchor and body blocks', () {
    final state = createEmptyDocument(allocator: createTestAllocator('fn'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final result = insertFootnote(
        state,
        Position(blockId: paragraph, offset: 0),
        createTestAllocator('fn-body'));
    expect(result.bodyRootId.value, isNotEmpty);
    expect(resolveBlock(state, result.firstParagraphId), isNotNull);
  });

  test('insertBlocksAfter links a sibling run and preserves parent tail', () {
    final state =
        createEmptyDocument(allocator: createTestAllocator('siblings'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final result = insertBlocksAfter(
      state,
      paragraph,
      const [
        SiblingBlockInit(type: 'paragraph'),
        SiblingBlockInit(type: 'heading'),
      ],
      createTestAllocator('siblings-new'),
    );
    expect(result.newBlockIds, hasLength(2));
    final updated = result.result.state;
    final first = getBlock(updated, result.newBlockIds[0])!;
    final second = getBlock(updated, result.newBlockIds[1])!;
    expect(getBlock(updated, paragraph)!.nextSiblingId, first.id);
    expect(first.prevSiblingId, paragraph);
    expect(first.nextSiblingId, second.id);
    expect(second.prevSiblingId, first.id);
    expect(second.nextSiblingId, isNull);
    expect(getBlock(updated, updated.rootId)!.lastChildId, second.id);
  });

  test('insertItems plans an in-place split and merges adjacent text', () {
    final state = createEmptyDocument(allocator: createTestAllocator('items'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final plan = planInsertItemsSplitInPlace(
      paragraph,
      ResolvedBlockKind.main,
      [const TextItem(text: 'hello')],
      2,
      [const TextItem(text: 'X')],
    );
    final result = applyOperation(state, (doc) => insertItemsInTx(doc, plan));
    final content = getBlock(result.state, paragraph)!.inlineContent!;
    expect(content.items.whereType<TextItem>().map((e) => e.text).join(),
        'heXllo');
  });

  test('replaceAllMatches replaces ranges from right to left', () {
    var state = createEmptyDocument(allocator: createTestAllocator('replace'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final inserted = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'one two one',
      const {},
    );
    state = inserted.state;
    final result = replaceAllMatches(
        state,
        [
          TextMatch(paragraph, 0, 3, 'one'),
          TextMatch(paragraph, 8, 11, 'one'),
        ],
        'X');
    final content = getBlock(result.state, paragraph)!.inlineContent!;
    expect(content.items.whereType<TextItem>().map((e) => e.text).join(),
        'X two X');
  });

  test('table row and column operations preserve grid sibling topology', () {
    var state = createEmptyDocument(allocator: createTestAllocator('table'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final created = createTable(
      state,
      Position(blockId: paragraph, offset: 0),
      2,
      2,
      createTestAllocator('table-tree'),
    );
    state = created.result.state;
    final table = getBlock(state, created.newTableId)!;
    expect(getChildIds(state, created.newTableId), hasLength(2));
    final firstRow = table.firstChildId!;
    final firstCell = getBlock(state, firstRow)!.firstChildId!;
    final firstPara = getBlock(state, firstCell)!.firstChildId!;
    final ctx = resolveTableContext(state, firstPara)!;
    final addedRow = insertTableRow(
        state, ctx, RowPosition.below, createTestAllocator('table-row'));
    state = addedRow.result.state;
    expect(getChildIds(state, created.newTableId), hasLength(3));
    final ctx2 = resolveTableContext(state, firstPara)!;
    state = insertTableColumn(
            state, ctx2, ColumnPosition.right, createTestAllocator('table-col'))
        .state;
    final rows = getChildIds(state, created.newTableId);
    expect(getChildIds(state, rows.first), hasLength(3));
    final ctx3 = resolveTableContext(state, firstPara)!;
    state = deleteTableColumn(state, ctx3).state;
    expect(getChildIds(state, rows.first), hasLength(2));
    final remainingCell = getBlock(state, rows.first)!.firstChildId!;
    final remainingPara = getBlock(state, remainingCell)!.firstChildId!;
    final ctx4 = resolveTableContext(state, remainingPara)!;
    state = deleteTableRow(state, ctx4).state;
    expect(getChildIds(state, created.newTableId), hasLength(2));
  });

  test('span-aware row deletion rehomes spanning cells', () {
    var state = createEmptyDocument(allocator: createTestAllocator('span'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final created = createTable(state, Position(blockId: paragraph, offset: 0),
        2, 2, createTestAllocator('span-tree'));
    state = created.result.state;
    final tableId = created.newTableId;
    final row = getBlock(state, tableId)!.firstChildId!;
    final cell = getBlock(state, row)!.firstChildId!;
    final cellPara = getBlock(state, cell)!.firstChildId!;
    state = setBlockAttrs(state, cell, {'rowSpan': 2}).state;
    final ctx = resolveTableContext(state, cellPara)!;
    state = insertTableRowSpanAware(
            state, ctx, RowPosition.below, createTestAllocator('span-row'))
        .state;
    final ctx2 = resolveTableContext(state, cellPara)!;
    final plan = planDeleteTableRowSpanAware(state, ctx2)!;
    expect(plan.reHomeRow, isNotNull);
    state = deleteTableRowSpanAware(state, ctx2).state;
    expect(getBlock(state, cell), isNotNull);
    expect(getChildIds(state, tableId), hasLength(2));
  });

  test('insertNewBlocks writes resolved main-tree block specs', () {
    final state = createEmptyDocument(allocator: createTestAllocator('new'));
    final parent = state.rootId;
    final prev = getBlock(state, parent)!.firstChildId!;
    final id = createTestAllocator('new-block').allocate();
    final result = applyOperation(state, (doc) {
      insertNewBlocksInTx(doc, [
        NewBlockSpec(
          id: id,
          kind: ResolvedBlockKind.main,
          type: 'paragraph',
          attrs: const {},
          items: const [TextItem(text: 'resolved')],
          parentId: parent,
          prevSiblingId: prev,
        ),
      ]);
    });
    final block = getBlock(result.state, id)!;
    expect(block.type, 'paragraph');
    expect(block.inlineContent!.items.single, const TextItem(text: 'resolved'));
  });

  test('span-aware column deletion reduces spanning cells', () {
    var state = createEmptyDocument(allocator: createTestAllocator('cspan'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final created = createTable(state, Position(blockId: paragraph, offset: 0),
        2, 2, createTestAllocator('cspan-tree'));
    state = created.result.state;
    final tableId = created.newTableId;
    final row = getBlock(state, tableId)!.firstChildId!;
    final cell = getBlock(state, row)!.firstChildId!;
    final cellPara = getBlock(state, cell)!.firstChildId!;
    state = setBlockAttrs(state, cell, {'colSpan': 2}).state;
    final ctx = resolveTableContext(state, cellPara)!;
    state = insertTableColumnSpanAware(
            state, ctx, ColumnPosition.right, createTestAllocator('cspan-col'))
        .state;
    final ctx2 = resolveTableContext(state, cellPara)!;
    state = deleteTableColumnSpanAware(state, ctx2).state;
    expect(getBlock(state, cell), isNotNull);
    expect(getBlock(state, cell)!.attrs['colSpan'], isNull);
    expect(getChildIds(state, tableId), hasLength(2));
  });

  test('mergeBlockAttrs preserves existing keys while overlaying incoming', () {
    var state = createEmptyDocument(allocator: createTestAllocator('attrs'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state =
        setBlockAttrs(state, paragraph, {'align': 'left', 'keep': true}).state;
    state = mergeBlockAttrs(state, paragraph, {'align': 'center'}).state;
    expect(
        getBlock(state, paragraph)!.attrs, {'align': 'center', 'keep': true});
  });

  test('insertCommentMarkers inserts paired embeds at UTF-16 offsets', () {
    var state = createEmptyDocument(allocator: createTestAllocator('comment'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
            state, Position(blockId: paragraph, offset: 0), 'hello', const {})
        .state;
    final span = Span(
      anchor: Position(blockId: paragraph, offset: 1),
      focus: Position(blockId: paragraph, offset: 4),
    );
    state = insertCommentMarkers(state, span, const CommentId('c1')).state;
    final embeds = getBlock(state, paragraph)!
        .inlineContent!
        .items
        .whereType<EmbedItem>()
        .toList();
    expect(embeds.map((e) => e.embedType),
        [commentStartEmbedType, commentEndEmbedType]);
  });

  test('section break partitions an implicit root into two sections', () {
    var state = createEmptyDocument(allocator: createTestAllocator('section'));
    final first = getBlock(state, state.rootId)!.firstChildId!;
    final inserted = insertBlocksAfter(
      state,
      first,
      const [
        SiblingBlockInit(type: 'paragraph', inlineContent: InlineContent([]))
      ],
      createTestAllocator('section-block'),
    );
    state = inserted.result.state;
    final second = inserted.newBlockIds.single;
    final result = applySectionBreak(
      state,
      Position(blockId: second, offset: 0),
      createTestAllocator('section-break'),
    );
    final root = getBlock(result.result.state, result.result.state.rootId)!;
    final sections = getChildIds(result.result.state, root.id);
    expect(sections, hasLength(2));
    expect(sections.map((id) => getBlock(result.result.state, id)!.type),
        everyElement('section'));
    expect(result.newCursorBlockId, isNotNull);
  });

  test('insertTemplateBody creates a template tree and links section attrs',
      () {
    var state = createEmptyDocument(allocator: createTestAllocator('template'));
    final first = getBlock(state, state.rootId)!.firstChildId!;
    state = insertBlocksAfter(
            state,
            first,
            const [SiblingBlockInit(type: 'paragraph')],
            createTestAllocator('template-block'))
        .result
        .state;
    final broken = applySectionBreak(state, Position(blockId: first, offset: 0),
        createTestAllocator('template-section'));
    state = broken.result.state;
    final section = getBlock(state, state.rootId)!.firstChildId!;
    final result = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: section),
      createTestAllocator('template-body'),
    );
    expect(getTemplateContent(result.state, result.bodyRootId), isNotNull);
    expect(
        getTemplateContent(result.state, result.firstParagraphId), isNotNull);
    expect(getBlock(result.state, section)!.attrs['headerBlockId'],
        result.bodyRootId.value);
  });

  test('mergeCells collapses a rectangular table range into its survivor', () {
    var state = createEmptyDocument(allocator: createTestAllocator('merge'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final created = createTable(state, Position(blockId: paragraph, offset: 0),
        2, 2, createTestAllocator('merge-table'));
    state = created.result.state;
    final tableId = created.newTableId;
    final firstRow = getBlock(state, tableId)!.firstChildId!;
    final survivor = getBlock(state, firstRow)!.firstChildId!;
    state = mergeCells(
      state,
      CellRange(tableId: tableId, minRow: 0, maxRow: 1, minCol: 0, maxCol: 1),
    ).state;
    expect(getBlock(state, survivor)!.attrs['rowSpan'], 2);
    expect(getBlock(state, survivor)!.attrs['colSpan'], 2);
    expect(getChildIds(state, firstRow), [survivor]);
  });

  test('mergeSectionWithPrevious joins section children and removes donor', () {
    var state = createEmptyDocument(allocator: createTestAllocator('msection'));
    final first = getBlock(state, state.rootId)!.firstChildId!;
    state = insertBlocksAfter(
            state,
            first,
            const [SiblingBlockInit(type: 'paragraph')],
            createTestAllocator('msection-block'))
        .result
        .state;
    final second = getBlock(state, first)!.nextSiblingId!;
    state = applySectionBreak(state, Position(blockId: second, offset: 0),
            createTestAllocator('msection-break'))
        .result
        .state;
    final root = getBlock(state, state.rootId)!;
    final sections = getChildIds(state, root.id);
    final previous = sections.first;
    final donor = sections.last;
    state = mergeSectionWithPrevious(state, donor).state;
    expect(getBlock(state, donor), isNull);
    expect(getChildIds(state, root.id), [previous]);
  });

  test('insertCrossReference inserts a page reference embed with style', () {
    var state = createEmptyDocument(allocator: createTestAllocator('xref'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
        state, Position(blockId: paragraph, offset: 0), 'See ', const {}).state;
    final target = getBlock(state, state.rootId)!.id;
    state = insertCrossReference(
      state,
      Position(blockId: paragraph, offset: 4),
      target,
      'page',
      'roman',
    ).state;
    final ref = getBlock(state, paragraph)!
        .inlineContent!
        .items
        .whereType<EmbedItem>()
        .single;
    expect(ref.embedType, crossReferenceEmbedType);
    expect(ref.properties['targetId'], target.value);
    expect(ref.properties['numberStyle'], 'roman');
  });

  test('replaceWithSuggestion marks deletion and insertion records', () {
    var state = createEmptyDocument(allocator: createTestAllocator('suggest'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
            state, Position(blockId: paragraph, offset: 0), 'hello', const {})
        .state;
    state = replaceWithSuggestion(
      state,
      Span(
        anchor: Position(blockId: paragraph, offset: 1),
        focus: Position(blockId: paragraph, offset: 4),
      ),
      'X',
      const {},
      const ReplaceSuggestionInput(
        deletionId: SuggestionId('del'),
        insertionId: SuggestionId('ins'),
        author: 'tester',
        createdAt: 1,
      ),
    ).state;
    expect(state.doc.suggestions.keys, containsAll(['del', 'ins']));
    final content = getBlock(state, paragraph)!.inlineContent!;
    expect(content.items.whereType<TextItem>().map((e) => e.text).join(),
        'hXello');
  });

  test('replaceBlockWithText removes a block and inserts into its sibling', () {
    var state =
        createEmptyDocument(allocator: createTestAllocator('replace-block'));
    final first = getBlock(state, state.rootId)!.firstChildId!;
    final inserted = insertBlocksAfter(
      state,
      first,
      const [
        SiblingBlockInit(type: 'paragraph', inlineContent: InlineContent([]))
      ],
      createTestAllocator('replace-block-sibling'),
    );
    state = inserted.result.state;
    final second = inserted.newBlockIds.single;
    state = replaceBlockWithText(
      state,
      first,
      Position(blockId: second, offset: 0),
      'replacement',
      const {},
    ).state;
    expect(getBlock(state, first), isNull);
    final item =
        getBlock(state, second)!.inlineContent!.items.single as TextItem;
    expect(item.text, 'replacement');
  });

  test('findMatches maps visible text to UTF-16 positions', () {
    var state = createEmptyDocument();
    final block = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: block, offset: 0),
      'Hello world',
      const {},
    ).state;
    final matches = findMatches(state, 'WORLD');
    expect(matches.single.blockId, block);
    expect(matches.single.start, 6);
    expect(matches.single.end, 11);
  });

  test('findMatches whole-word matching understands Unicode letters', () {
    var state = createEmptyDocument();
    final block = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: block, offset: 0),
      'ação açãox',
      const {},
    ).state;
    final matches =
        findMatches(state, 'AÇÃO', const FindMatchesOptions(wholeWord: true));
    expect(matches, hasLength(1));
    expect(matches.single.text, 'ação');
    expect(matches.single.start, 0);
    expect(matches.single.end, 4);
  });

  test('findMatches preserves UTF-16 range when case folding expands', () {
    var state = createEmptyDocument();
    final block = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: block, offset: 0),
      '\u0130x',
      const {},
    ).state;
    final matches = findMatches(state, 'i');
    expect(matches, hasLength(1));
    expect(matches.single.text, '\u0130');
    expect(matches.single.start, 0);
    expect(matches.single.end, 1);
  });
}
