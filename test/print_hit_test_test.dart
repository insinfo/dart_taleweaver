import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/cursor/hit_test.dart';
import 'package:taleweaver/src/core/print/layout/bfc.dart';
import 'package:taleweaver/src/core/print/layout/page_config.dart';
import 'package:taleweaver/src/core/print/layout/pagination.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';
import 'package:taleweaver/src/core/print/layout/page_box.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/styles/writing_mode.dart';

void main() {
  test('hit-test maps a line x coordinate to a block position', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final position = hitTestPage(page, 25, 5);
    expect(position!.blockId, const BlockId('p'));
    expect(position.offset, 3);
  });

  test('hit-test traverses multiple inline text runs on one line', () {
    const blockId = BlockId('multi-run');
    const line = LineBox(
      key: 'line',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 40,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 40,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      ownerBlockId: blockId,
      children: [
        TextRunBox(
          key: 'first',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 20,
          blockSize: 20,
          x: 0,
          y: 0,
          width: 20,
          height: 20,
          writingMode: WritingMode.horizontalTb,
          direction: Direction.ltr,
          text: 'ab',
          offsetLength: 2,
        ),
        TextRunBox(
          key: 'second',
          inlineOffset: 20,
          blockOffset: 0,
          inlineSize: 20,
          blockSize: 20,
          x: 20,
          y: 0,
          width: 20,
          height: 20,
          writingMode: WritingMode.horizontalTb,
          direction: Direction.ltr,
          text: 'cd',
          offsetLength: 2,
        ),
      ],
    );
    final page = createPageBox(
      key: 'multi-run-page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: const [line],
      pageIndex: 0,
    );
    expect(
        hitTestPage(page, 30, 10), const Position(blockId: blockId, offset: 3));
  });

  test('hit-test and caret mirror offsets inside an RTL text run', () {
    const blockId = BlockId('rtl-run');
    const line = LineBox(
      key: 'rtl-line',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.rtl,
      ownerBlockId: blockId,
      children: [
        TextRunBox(
          key: 'rtl-text',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 20,
          blockSize: 20,
          x: 0,
          y: 0,
          width: 20,
          height: 20,
          writingMode: WritingMode.horizontalTb,
          direction: Direction.rtl,
          text: 'אב',
          offsetLength: 2,
        ),
      ],
    );
    final page = createPageBox(
      key: 'rtl-page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.rtl,
      containingInlineSize: 100,
      children: const [line],
      pageIndex: 0,
    );
    expect(
        hitTestPage(page, 5, 10), const Position(blockId: blockId, offset: 2));
    expect(
        caretRectForPosition(page, const Position(blockId: blockId, offset: 0))!
            .x,
        20);
    expect(
        caretRectForPosition(page, const Position(blockId: blockId, offset: 2))!
            .x,
        0);
    final rect = selectionRectForRange(
        page,
        const Position(blockId: blockId, offset: 0),
        const Position(blockId: blockId, offset: 2));
    expect(rect!.x, 0);
    expect(rect.width, 20);
  });

  test('vertical hit-test and caret use physical Y as the inline axis', () {
    const blockId = BlockId('vertical-run');
    const line = LineBox(
      key: 'vertical-line',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 16,
      x: 30,
      y: 0,
      width: 16,
      height: 20,
      writingMode: WritingMode.verticalLr,
      direction: Direction.ltr,
      ownerBlockId: blockId,
      children: [
        TextRunBox(
          key: 'vertical-text',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 20,
          blockSize: 16,
          x: 0,
          y: 0,
          width: 16,
          height: 20,
          writingMode: WritingMode.verticalLr,
          direction: Direction.ltr,
          text: 'ab',
          offsetLength: 2,
        ),
      ],
    );
    final page = createPageBox(
      key: 'vertical-page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.verticalLr,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: const [line],
      pageIndex: 0,
    );
    expect(
        hitTestPage(page, 35, 15), const Position(blockId: blockId, offset: 2));
    final caret =
        caretRectForPosition(page, const Position(blockId: blockId, offset: 1));
    expect(caret!.x, 10);
    expect(caret.y, 30);
    expect(caret.height, 16);
    final selection = selectionRectForRange(
      page,
      const Position(blockId: blockId, offset: 0),
      const Position(blockId: blockId, offset: 2),
    );
    expect(selection!.x, 30);
    expect(selection.y, 0);
    expect(selection.width, 16);
    expect(selection.height, 20);

    const rtlLine = LineBox(
      key: 'vertical-rtl-line',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 16,
      x: 50,
      y: 0,
      width: 16,
      height: 20,
      writingMode: WritingMode.verticalLr,
      direction: Direction.rtl,
      ownerBlockId: blockId,
      children: [
        TextRunBox(
          key: 'vertical-rtl-text',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 20,
          blockSize: 16,
          x: 0,
          y: 0,
          width: 16,
          height: 20,
          writingMode: WritingMode.verticalLr,
          direction: Direction.rtl,
          text: 'אב',
          offsetLength: 2,
        ),
      ],
    );
    final rtlPage = createPageBox(
      key: 'vertical-rtl-page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.verticalLr,
      direction: Direction.rtl,
      containingInlineSize: 100,
      children: const [rtlLine],
      pageIndex: 0,
    );
    expect(hitTestPage(rtlPage, 55, 5),
        const Position(blockId: blockId, offset: 2));
    expect(
        caretRectForPosition(
                rtlPage, const Position(blockId: blockId, offset: 0))!
            .x,
        20);
  });

  test('hit-test misses outside all lines', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'a',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    expect(hitTestPage(page, 10, 1000), isNull);
  });

  test('atomic hit-test indexes block images without a text line', () {
    const rootId = BlockId('root-atomic');
    const imageId = BlockId('image-atomic');
    final state = createState(rootId: rootId);
    state.doc.setBlockMap(rootId.value, {
      'id': rootId.value,
      'type': 'document',
      'firstChildId': imageId.value,
      'lastChildId': imageId.value,
    });
    state.doc.setBlockMap(imageId.value, {
      'id': imageId.value,
      'type': 'image',
      'parentId': rootId.value,
      'attrs': <String, dynamic>{},
    });
    final image = BlockBox(
      key: imageId.value,
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 40,
      blockSize: 30,
      x: 10,
      y: 5,
      width: 40,
      height: 30,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
    );
    final page = PageBox(
      key: 'atomic-page',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 100,
      blockSize: 100,
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [image],
      pageIndex: 0,
      effectiveTopInset: 0,
      effectiveBottomInset: 0,
    );
    final index = atomicBlockIndex(page, state);
    expect(index[imageId]!.x, 10);
    expect(hitTestAtomicBlock(page, state, 20, 15), imageId);
    expect(hitTestPage(page, 20, 15, state: state)?.blockId, imageId);
    expect(hitTestPage(page, 20, 15, state: state)?.offset, 0);
    expect(hitTestAtomicBlock(page, state, 90, 90), isNull);
  });

  test('selection geometry returns a same-line highlight rectangle', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final rect = selectionRectForRange(
      page,
      const Position(blockId: BlockId('p'), offset: 1),
      const Position(blockId: BlockId('p'), offset: 3),
    );
    expect(rect, isNotNull);
    expect(rect!.width, 20);
    expect(rect.height, 20);
  });

  test('selection geometry fragments a range across visual lines', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final rects = selectionRectsForRange(
      page,
      const Position(blockId: BlockId('p'), offset: 1),
      const Position(blockId: BlockId('p'), offset: 3),
    );
    expect(rects, hasLength(2));
    expect(rects[0].width, 10);
    expect(rects[1].width, 10);
    expect(rects[1].y, greaterThan(rects[0].y));
  });

  test('caret geometry resolves a UTF-16 position in a text run', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final caret = caretRectForPosition(
        page, const Position(blockId: BlockId('p'), offset: 2));
    expect(caret, isNotNull);
    expect(caret!.x, 20);
    expect(caret.height, 20);
  });

  test(
      'selection geometry keeps UTF-16 offsets when pagination starts a later page',
      () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final pages = paginateBlock(
      block: block,
      config: const PrintLayoutConfig(
        pageSize: PrintPageSize(100, 20),
        margins: PrintPageMargins(top: 0, right: 0, bottom: 0, left: 0),
      ),
    );
    expect(pages, hasLength(2));
    final rects = selectionRectsForRange(
      pages[1],
      const Position(blockId: BlockId('p'), offset: 2),
      const Position(blockId: BlockId('p'), offset: 4),
    );
    expect(rects, hasLength(1));
    expect(rects.single.width, 20);
  });

  test('selection geometry aggregates fragments across pages', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final pages = paginateBlock(
      block: block,
      config: const PrintLayoutConfig(
        pageSize: PrintPageSize(100, 20),
        margins: PrintPageMargins(top: 0, right: 0, bottom: 0, left: 0),
      ),
    );
    final rects = selectionRectsAcrossPages(
        pages,
        const Position(blockId: BlockId('p'), offset: 0),
        const Position(blockId: BlockId('p'), offset: 4));
    expect(rects, hasLength(2));
  });

  test('selection geometry spans different blocks across pages', () {
    final first = layoutBlockText(
        key: 'first',
        text: 'ab',
        ownerBlockId: const BlockId('first'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final second = layoutBlockText(
        key: 'second',
        text: 'cd',
        ownerBlockId: const BlockId('second'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final pages = [
      createPageBox(
        key: 'first-page',
        inlineSize: 100,
        blockSize: 100,
        blockOffset: 0,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        containingInlineSize: 100,
        children: [first],
        pageIndex: 0,
      ),
      createPageBox(
        key: 'second-page',
        inlineSize: 100,
        blockSize: 100,
        blockOffset: 100,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        containingInlineSize: 100,
        children: [second],
        pageIndex: 1,
      ),
    ];
    final rects = selectionRectsAcrossPages(
        pages,
        const Position(blockId: BlockId('first'), offset: 1),
        const Position(blockId: BlockId('second'), offset: 1));
    expect(rects, hasLength(2));
    expect(rects.first.width, 10);
    expect(rects.last.width, 10);
  });

  test('selection geometry across pages preserves vertical physical axes', () {
    const id = BlockId('vertical-span');
    const firstLine = LineBox(
      key: 'vertical-span-1',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 16,
      x: 10,
      y: 0,
      width: 16,
      height: 20,
      writingMode: WritingMode.verticalLr,
      direction: Direction.ltr,
      ownerBlockId: id,
      children: [
        TextRunBox(
            key: 'v1',
            inlineOffset: 0,
            blockOffset: 0,
            inlineSize: 20,
            blockSize: 16,
            x: 0,
            y: 0,
            width: 16,
            height: 20,
            writingMode: WritingMode.verticalLr,
            direction: Direction.ltr,
            text: 'ab',
            offsetLength: 2)
      ],
    );
    const secondLine = LineBox(
      key: 'vertical-span-2',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 16,
      x: 30,
      y: 0,
      width: 16,
      height: 20,
      writingMode: WritingMode.verticalLr,
      direction: Direction.ltr,
      ownerBlockId: id,
      children: [
        TextRunBox(
            key: 'v2',
            inlineOffset: 0,
            blockOffset: 0,
            inlineSize: 20,
            blockSize: 16,
            x: 0,
            y: 0,
            width: 16,
            height: 20,
            writingMode: WritingMode.verticalLr,
            direction: Direction.ltr,
            text: 'cd',
            offsetLength: 2)
      ],
    );
    final pages = [
      createPageBox(
          key: 'vp1',
          inlineSize: 100,
          blockSize: 100,
          blockOffset: 0,
          writingMode: WritingMode.verticalLr,
          direction: Direction.ltr,
          containingInlineSize: 100,
          children: const [firstLine],
          pageIndex: 0),
      createPageBox(
          key: 'vp2',
          inlineSize: 100,
          blockSize: 100,
          blockOffset: 100,
          writingMode: WritingMode.verticalLr,
          direction: Direction.ltr,
          containingInlineSize: 100,
          children: const [secondLine],
          pageIndex: 1),
    ];
    final rects = selectionRectsAcrossPages(
        pages,
        const Position(blockId: id, offset: 1),
        const Position(blockId: id, offset: 3));
    expect(rects, hasLength(2));
    expect(rects.first.width, 16);
    expect(rects.first.height, 10);
    expect(rects.last.width, 16);
    expect(rects.last.height, 10);
  });

  test('caret affinity selects the before or after side of a soft wrap', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 20);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final before = caretRectForPosition(
        page, const Position(blockId: BlockId('p'), offset: 2), 'before');
    final after = caretRectForPosition(
        page, const Position(blockId: BlockId('p'), offset: 2), 'after');
    expect(before, isNotNull);
    expect(after, isNotNull);
    expect(after!.y, greaterThan(before!.y));
    expect(after.x, 0);
  });

  test('image hit-test traverses nested print boxes', () {
    const image = ImageBox(
      key: 'image',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 30,
      blockSize: 20,
      x: 10,
      y: 5,
      width: 30,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      src: 'asset.png',
    );
    final page = createPageBox(
      key: 'page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: [image],
      pageIndex: 0,
    );
    expect(hitTestImage(page, 20, 10), same(image));
    expect(hitTestImage(page, 90, 90), isNull);
  });

  test('text hit-test traverses table rows and cells', () {
    const run = TextRunBox(
      key: 'run',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      text: 'ab',
      offsetLength: 2,
    );
    const line = LineBox(
      key: 'line',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      ownerBlockId: BlockId('cell'),
      children: [run],
    );
    const cell = TableCellBox(
      key: 'cell',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 30,
      blockSize: 20,
      x: 10,
      y: 5,
      width: 30,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [line],
    );
    const row = TableRowBox(
      key: 'row',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 40,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 40,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [cell],
    );
    const table = TableBox(
      key: 'table',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 40,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 40,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [row],
    );
    final page = createPageBox(
      key: 'page',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: [table],
      pageIndex: 0,
    );
    final position = hitTestPage(page, 15, 10);
    expect(position, isNotNull);
    expect(position!.blockId, const BlockId('cell'));
    expect(position.offset, 1);
  });

  test('caret geometry traverses nested table cells', () {
    const run = TextRunBox(
      key: 'run-caret',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      text: 'ab',
      offsetLength: 2,
    );
    const line = LineBox(
      key: 'line-caret',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      ownerBlockId: BlockId('cell-caret'),
      children: [run],
    );
    const cell = TableCellBox(
      key: 'cell-caret',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 30,
      blockSize: 20,
      x: 10,
      y: 5,
      width: 30,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [line],
    );
    const row = TableRowBox(
      key: 'row-caret',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 40,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 40,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      children: [cell],
    );
    final page = createPageBox(
      key: 'page-caret',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: [
        TableBox(
          key: 'table-caret',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 40,
          blockSize: 20,
          x: 0,
          y: 0,
          width: 40,
          height: 20,
          writingMode: WritingMode.horizontalTb,
          direction: Direction.ltr,
          children: [row],
        )
      ],
      pageIndex: 0,
    );
    final caret = caretRectForPosition(
        page, const Position(blockId: BlockId('cell-caret'), offset: 1));
    expect(caret, isNotNull);
    expect(caret!.x, 20);
    expect(caret.y, 5);
  });

  test('selection geometry traverses nested table cells', () {
    const run = TextRunBox(
      key: 'run-selection',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      text: 'ab',
      offsetLength: 2,
    );
    const line = LineBox(
      key: 'line-selection',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 20,
      blockSize: 20,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      ownerBlockId: BlockId('cell-selection'),
      children: [run],
    );
    final page = createPageBox(
      key: 'page-selection',
      inlineSize: 100,
      blockSize: 100,
      blockOffset: 0,
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
      containingInlineSize: 100,
      children: [
        TableBox(
          key: 'table-selection',
          inlineOffset: 0,
          blockOffset: 0,
          inlineSize: 40,
          blockSize: 20,
          x: 0,
          y: 0,
          width: 40,
          height: 20,
          writingMode: WritingMode.horizontalTb,
          direction: Direction.ltr,
          children: [
            TableRowBox(
              key: 'row-selection',
              inlineOffset: 0,
              blockOffset: 0,
              inlineSize: 40,
              blockSize: 20,
              x: 0,
              y: 0,
              width: 40,
              height: 20,
              writingMode: WritingMode.horizontalTb,
              direction: Direction.ltr,
              children: [
                TableCellBox(
                  key: 'cell-selection',
                  inlineOffset: 0,
                  blockOffset: 0,
                  inlineSize: 30,
                  blockSize: 20,
                  x: 10,
                  y: 5,
                  width: 30,
                  height: 20,
                  writingMode: WritingMode.horizontalTb,
                  direction: Direction.ltr,
                  children: [line],
                )
              ],
            )
          ],
        )
      ],
      pageIndex: 0,
    );
    final rects = selectionRectsForRange(
        page,
        const Position(blockId: BlockId('cell-selection'), offset: 0),
        const Position(blockId: BlockId('cell-selection'), offset: 2));
    expect(rects, hasLength(1));
    expect(rects.single.x, 10);
    expect(rects.single.width, 20);
    expect(rects.single.y, 5);
  });
}
