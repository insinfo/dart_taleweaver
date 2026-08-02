import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/layout/bfc.dart';
import 'package:taleweaver/src/core/print/layout/page_config.dart';
import 'package:taleweaver/src/core/print/layout/pagination.dart';
import 'package:taleweaver/src/core/print/layout/field_convergence.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/styles/style.dart';
import 'package:taleweaver/src/core/styles/writing_mode.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/footnotes/types.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/ops/insert_page_field.dart';

String? _firstTextRun(LayoutBox box) {
  if (box is TextRunBox) return box.text;
  final children = switch (box) {
    BlockBox(:final children) ||
    TableBox(:final children) ||
    TableRowBox(:final children) ||
    TableCellBox(:final children) ||
    LineBox(:final children) =>
      children,
    _ => const <LayoutBox>[],
  };
  for (final child in children) {
    final text = _firstTextRun(child);
    if (text != null) return text;
  }
  return null;
}

void main() {
  test('pagination splits block lines at content height', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcdefghijklmnopqrst',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 25);
    final pages = paginateBlock(
        block: block,
        config: const PrintLayoutConfig(
            pageSize: PrintPageSize(300, 180),
            margins:
                PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20)));
    expect(pages, hasLength(2));
    expect(pages[0].children, hasLength(7));
    expect(pages[1].children, hasLength(3));
    expect(pages[1].pageIndex, 1);
    expect(buildPageIndex(pages)[const BlockId('p')], 0);
  });

  test('pagination fragments a table at row boundaries', () {
    final rows = [
      for (var i = 0; i < 3; i++)
        TableRowBox(
            key: 'row-$i',
            inlineOffset: 0,
            blockOffset: i * 30,
            inlineSize: 200,
            blockSize: 30,
            x: 0,
            y: i * 30,
            width: 200,
            height: 30,
            writingMode: WritingMode.horizontalTb,
            direction: Direction.ltr),
    ];
    final table = TableBox(
        key: 'table',
        inlineOffset: 0,
        blockOffset: 0,
        inlineSize: 200,
        blockSize: 90,
        x: 0,
        y: 0,
        width: 200,
        height: 90,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        children: rows,
        rowHeights: const [30, 30, 30],
        columnWidths: const [200],
        headerRowCount: 1);
    final block = BlockBox(
        key: 'body',
        inlineOffset: 0,
        blockOffset: 0,
        inlineSize: 200,
        blockSize: 90,
        x: 0,
        y: 0,
        width: 200,
        height: 90,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        children: [table]);
    final pages = paginateBlock(
        block: block,
        config: const PrintLayoutConfig(
            pageSize: PrintPageSize(240, 100),
            margins:
                PrintPageMargins(top: 10, right: 10, bottom: 10, left: 10)));
    expect(pages, hasLength(2));
    expect((pages[0].children.single as TableBox).children, hasLength(2));
    expect((pages[1].children.single as TableBox).children, hasLength(2));
  });

  test('pagination repeats named header and footer slots on every page', () {
    final style = initialComputedStyle;
    final block = layoutBlockText(
        key: 'p',
        text: 'abcdefghijklmnopqrst',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 25);
    final header = layoutBlockText(
        key: 'header',
        text: 'Header',
        ownerBlockId: const BlockId('header'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 25);
    final footer = layoutBlockText(
        key: 'footer',
        text: 'Footer',
        ownerBlockId: const BlockId('footer'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 25);
    final pages = paginateBlock(
        block: block,
        config: const PrintLayoutConfig(
            pageSize: PrintPageSize(300, 180),
            margins:
                PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20)),
        headerSlot: header,
        footerSlot: footer);
    expect(pages, hasLength(2));
    expect(pages.every((page) => identical(page.headerSlot, header)), isTrue);
    expect(pages.every((page) => identical(page.footerSlot, footer)), isTrue);
    expect(
        pages.every((page) => !page.children.any(
            (child) => identical(child, header) || identical(child, footer))),
        isTrue);
  });

  test('converged pagination keeps pages paired with final field reservation',
      () {
    final style = initialComputedStyle;
    const config = PrintLayoutConfig(
        pageSize: PrintPageSize(300, 180),
        margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20));
    var passes = 0;
    final result = paginateBlockWithFieldConvergence(
      config: config,
      fields: const [ConvergenceField('header/inline/0', 2)],
      layout: (widths) {
        passes++;
        final reserved = widths['header/inline/0'] ?? 2;
        final block = layoutBlockText(
            key: 'p',
            text: reserved >= 6 ? 'abcdefghijklmnopqrst' : 'abcdefghij',
            ownerBlockId: const BlockId('p'),
            shaper: createMockShaper(10, 20),
            style: style,
            inlineSize: 25);
        return FieldLayoutPass(
            block: block, maxValueWidths: {'header/inline/0': 6});
      },
    );
    expect(passes, 2);
    expect(result.convergence.converged, isTrue);
    expect(result.convergence.grownWidths['header/inline/0'], 6);
    expect(result.pages, hasLength(2));
    expect(result.convergence.result.pages, same(result.pages));
  });

  test('pagination materializes rendered template slots automatically', () {
    final style = initialComputedStyle;
    final block = layoutBlockText(
        key: 'p',
        text: 'body',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    final header = createElementBox('header', const Style(), [
      createTextBox('header/inline/0', const Style(), 'Header'),
    ]);
    final pages = paginateBlockWithTemplateSlots(
      block: block,
      config: const PrintLayoutConfig(),
      headerRender: header,
      shaper: createMockShaper(10, 20),
      fallbackStyle: style,
    );
    expect(pages, hasLength(1));
    expect(pages.single.headerSlot, isNotNull);
    expect(pages.single.headerSlot!.children, hasLength(1));
  });

  test('per-page template slots receive one-based page and count', () {
    final style = initialComputedStyle;
    final block = layoutBlockText(
        key: 'p',
        text: 'abcdefghijklmnopqrst',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 25);
    final pages = paginateBlockWithPerPageTemplateSlots(
      block: block,
      config: const PrintLayoutConfig(
          pageSize: PrintPageSize(300, 180),
          margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20)),
      headerRenderForPage: (page, count) => createElementBox(
          'header-$page', const Style(), [
        createTextBox('header-$page/inline/0', const Style(), '$page/$count')
      ]),
      footerRenderForPage: (page, count) => createElementBox(
          'footer-$page', const Style(), [
        createTextBox('footer-$page/inline/0', const Style(), '$page/$count')
      ]),
      shaper: createMockShaper(10, 20),
      fallbackStyle: style,
    );
    expect(pages, hasLength(2));
    expect(pages[0].headerSlot!.children.single, isA<BlockBox>());
    expect(pages[0].headerSlot!.key, 'header-1');
    expect(pages[1].headerSlot!.key, 'header-2');
    expect(pages[0].footerSlot!.blockOffset + pages[0].footerSlot!.blockSize,
        closeTo(140, 0.001));
  });

  test('state template pagination resolves page-field values per page', () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final template = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      createTestAllocator('state-template-pagination'),
    );
    state = insertPageField(
      template.state,
      Position(blockId: template.firstParagraphId, offset: 0),
      'page-number',
    ).state;
    final body = layoutBlockText(
        key: 'p',
        text: 'abcdefghijklmnopqrst',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 25);
    final pages = paginateBlockWithStateTemplateSlots(
      block: body,
      config: const PrintLayoutConfig(
          pageSize: PrintPageSize(300, 180),
          margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20)),
      state: state,
      registry: createDefaultComponentRegistry(),
      headerBodyId: template.bodyRootId,
      shaper: createMockShaper(10, 20),
      fallbackStyle: initialComputedStyle,
    );
    expect(pages, hasLength(2));
    expect(_firstTextRun(pages[0].headerSlot!), '1');
    expect(_firstTextRun(pages[1].headerSlot!), '2');
    expect(pages[0].children.first.blockOffset,
        greaterThanOrEqualTo(pages[0].headerSlot!.blockSize));
  });

  test('pagination reserves footnote bodies on the anchor page', () {
    final style = initialComputedStyle;
    final block = layoutBlockText(
        key: 'p',
        text: 'abcdefghij',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    final body = layoutBlockText(
        key: 'fn',
        text: 'note',
        ownerBlockId: const BlockId('fn'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    const config = PrintLayoutConfig(
        pageSize: PrintPageSize(300, 180),
        margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20));
    final pages = paginateBlockWithFootnotes(
        block: block,
        config: config,
        anchors: const [
          FootnoteAnchorRef(
              contentBlockId: BlockId('fn'), blockId: BlockId('p'))
        ],
        bodies: {
          const BlockId('fn'): body
        });
    expect(pages, hasLength(1));
    expect(pages.single.footnoteSlot, isNotNull);
    expect(pages.single.footnoteSlot!.children.single.key, 'fn');
    expect(pages.single.footnoteSlot!.children.single.y, greaterThan(0));
  });

  test('pagination assigns nested footnote anchors to their host page', () {
    final style = initialComputedStyle;
    final nested = layoutBlockText(
        key: 'decorated-anchor-host',
        text: 'anchor',
        ownerBlockId: const BlockId('anchor-host'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    final container = BlockBox(
      key: 'table-cell',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 200,
      blockSize: nested.blockSize,
      x: 0,
      y: 0,
      width: 200,
      height: nested.blockSize,
      children: [nested],
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
    );
    final block = BlockBox(
      key: 'root',
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: 200,
      blockSize: container.blockSize,
      x: 0,
      y: 0,
      width: 200,
      height: container.blockSize,
      children: [container],
      writingMode: WritingMode.horizontalTb,
      direction: Direction.ltr,
    );
    final body = layoutBlockText(
        key: 'fn-nested',
        text: 'nested note',
        ownerBlockId: const BlockId('fn-nested'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    const config = PrintLayoutConfig(
        pageSize: PrintPageSize(300, 180),
        margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20));
    final pages = paginateBlockWithFootnotes(
      block: block,
      config: config,
      anchors: const [
        FootnoteAnchorRef(
            contentBlockId: BlockId('fn-nested'),
            blockId: BlockId('anchor-host'))
      ],
      bodies: {const BlockId('fn-nested'): body},
    );
    expect(
        pages.single.footnoteSlot?.children
                .any((child) => child.key == 'fn-nested') ??
            false,
        isTrue);
  });

  test('pagination carries a footnote when the host page has no slot left', () {
    final style = initialComputedStyle;
    final block = layoutBlockText(
        key: 'full',
        text: 'abcdefghijklmnopqrstuvwxyz' * 4,
        ownerBlockId: const BlockId('full'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 25);
    final body = layoutBlockText(
        key: 'fn-carry',
        text: 'note',
        ownerBlockId: const BlockId('fn-carry'),
        shaper: createMockShaper(10, 20),
        style: style,
        inlineSize: 200);
    const config = PrintLayoutConfig(
        pageSize: PrintPageSize(300, 180),
        margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20));
    final pages = paginateBlockWithFootnotes(
      block: block,
      config: config,
      anchors: const [
        FootnoteAnchorRef(
            contentBlockId: BlockId('fn-carry'), blockId: BlockId('full'))
      ],
      bodies: {const BlockId('fn-carry'): body},
    );
    expect(pages.length, greaterThan(1));
    expect(
        pages[0]
                .footnoteSlot
                ?.children
                .any((child) => child.key == 'fn-carry') ??
            false,
        isFalse);
    expect(
        pages.skip(1).any((page) =>
            page.footnoteSlot?.children
                .any((child) => child.key == 'fn-carry') ??
            false),
        isTrue);
  });

  test('pagination fragments an oversized footnote body across pages', () {
    final body = layoutBlockText(
        key: 'fn-large',
        text: 'abcdefghijklmnopqrstuvwxyz' * 3,
        ownerBlockId: const BlockId('fn-large'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 25);
    final host = layoutBlockText(
        key: 'host',
        text: 'anchor',
        ownerBlockId: const BlockId('host'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 200);
    const config = PrintLayoutConfig(
        pageSize: PrintPageSize(300, 180),
        margins: PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20));
    final pages = paginateBlockWithFootnotes(
      block: host,
      config: config,
      anchors: const [
        FootnoteAnchorRef(
            contentBlockId: BlockId('fn-large'), blockId: BlockId('host'))
      ],
      bodies: {const BlockId('fn-large'): body},
    );
    expect(pages.length, greaterThan(1));
    expect(
        pages.any((page) =>
            page.footnoteSlot?.children
                .any((child) => child.key.startsWith('fn-large-prefix')) ??
            false),
        isTrue);
  });
}
