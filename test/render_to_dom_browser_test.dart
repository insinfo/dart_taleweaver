@TestOn('browser')

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:taleweaver/src/core/cascade/cascade_pass.dart';
import 'package:taleweaver/src/core/cascade/attr_registry.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/digital/browser_selection_bridge.dart';
import 'package:taleweaver/src/core/digital/dom_browser_reconciler.dart';
import 'package:taleweaver/src/core/digital/render_to_dom.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/render/layout_metadata.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/block_schema.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/tw_doc.dart';
import 'package:taleweaver/src/core/styles/column_config.dart';
import 'package:taleweaver/src/core/styles/style.dart';
import 'package:taleweaver/src/core/styles/tab_stops.dart';

void main() {
  test('renders styled text with semantic wrappers and a safe link', () {
    final styled = cascadePass(createTextBox(
      'run',
      const Style(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        underline: true,
        lineThrough: true,
        color: '#8030a0',
        fontFamily: 'Georgia',
      ),
      'Styled',
      'https://example.test/docs',
    ));

    final dom = renderNodeToDom(styled, web.document) as web.Element;
    expect(dom.localName, 'a');
    expect(dom.getAttribute('href'), 'https://example.test/docs');
    expect(dom.querySelector('strong'), isNotNull);
    expect(dom.querySelector('em'), isNotNull);
    expect(dom.querySelector('u'), isNotNull);
    expect(dom.querySelector('s'), isNotNull);
    expect(dom.querySelector('span')?.getAttribute('style'), contains('color'));
  });

  test('does not emit executable link URLs', () {
    final text = cascadePass(createTextBox(
      'unsafe-link',
      const Style(),
      'Never execute',
      'javascript:alert(1)',
    ));

    final dom = renderNodeToDom(text, web.document);
    expect(dom, isA<web.Text>());
  });

  test('marks empty line fillers and non-editable inline atoms', () {
    final emptyLine = cascadePass(createElementBox(
      'empty',
      const Style(display: Display.block),
      [createTextBox('empty/run', const Style(), '')],
    ));
    final emptyDom =
        renderNodeToDom(emptyLine, web.document, stampBlockIds: true)
            as web.Element;
    expect(emptyDom.querySelector('br[data-tw-empty-line]'), isNotNull);

    final atom = cascadePass(createElementBox(
      'atom',
      const Style(display: Display.inlineBlock),
      const [],
      const LayoutBoxMetadata(embedType: 'mention'),
    ));
    final atomDom =
        renderNodeToDom(atom, web.document, stampBlockIds: true) as web.Element;
    expect(atomDom.hasAttribute('data-inline-embed'), isTrue);
    expect(atomDom.getAttribute('contenteditable'), 'false');
    expect(atomDom.hasAttribute('data-block-id'), isFalse);
  });

  test('projects a manual page break on its following authored block', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('AntesDepois'));
    final firstId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetSelectionAction(Selection(
        anchor: Position(blockId: firstId, offset: 5),
        focus: Position(blockId: firstId, offset: 5),
      )),
    );
    editor = reduceEditor(editor, const PageBreakAction());
    final followingId = getBlock(editor.state, firstId)!.nextSiblingId!;

    final dom = renderDocumentToDom(
      editor.state,
      createDefaultComponentRegistry(),
      createDefaultAttrRegistry(),
      web.document,
    );
    final following =
        dom.querySelector('[data-block-id="${followingId.value}"]')
            as web.HTMLElement;
    final style = following.getAttribute('style') ?? '';

    expect(following.hasAttribute('data-tw-manual-page-break'), isTrue);
    expect(style, contains('break-before: page'));
    expect(style, contains('page-break-before: always'));
    expect(dom.querySelector('[data-tw-section]'), isNull);
  });

  test('projects model tabs as atomic left stops with leaders', () {
    final paragraph = cascadePass(createElementBox(
      'tab-paragraph',
      const Style(
        display: Display.block,
        tabStops: [
          TabStop(
            position: 120,
            alignment: TabAlignment.left,
            leader: LeaderStyle.dot,
          ),
        ],
      ),
      [
        createTextBox('tab-paragraph/before', const Style(), 'A'),
        createElementBox(
          'tab-paragraph/inline/1',
          const Style(),
          const [],
          const LayoutBoxMetadata(embedType: 'tab'),
        ),
        createTextBox('tab-paragraph/after', const Style(), 'Depois'),
      ],
    ));
    final host = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '360px')
      ..style.setProperty('font-family', 'monospace')
      ..style.setProperty('font-size', '16px');
    web.document.body!.appendChild(host);
    addTearDown(() => host.remove());

    final dom = renderNodeToDom(paragraph, web.document, stampBlockIds: true)
        as web.HTMLElement;
    host.appendChild(dom);
    layoutTabStopsInDom(dom);

    final tab = dom.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(dom.getAttribute('data-tw-tab-stop-count'), '1');
    expect(tab.getAttribute('data-inline-embed'), '');
    expect(tab.getAttribute('contenteditable'), 'false');
    expect(tab.getAttribute('data-tw-tab-layout'), 'left');
    expect(tab.getAttribute('data-tw-tab-alignment'), 'left');
    expect(tab.getAttribute('data-tw-tab-leader'), 'dot');
    expect(tab.getAttribute('style'), contains('radial-gradient'));

    // The right edge of the generated atom is the next tab stop; following
    // browser-flowed text begins at that point without a synthetic text node.
    final relativeRight =
        tab.getBoundingClientRect().right - dom.getBoundingClientRect().left;
    expect(relativeRight, closeTo(120, 2));

    final bridge = BrowserSelectionBridge(dom);
    expect(
      bridge.domToPosition(tab, 0),
      const Position(blockId: BlockId('tab-paragraph'), offset: 1),
    );
    expect(
      bridge.domToPosition(tab, 1),
      const Position(blockId: BlockId('tab-paragraph'), offset: 2),
    );
  });

  test(
      'SetTabStopsAction reaches the browser renderer and reflows on reconcile',
      () async {
    var editor = createInitialEditorState();
    editor = reduceEditor(editor, const InsertTextAction('A'));
    editor = reduceEditor(editor, const InsertTabAction());
    editor = reduceEditor(editor, const InsertTextAction('Depois'));
    final blockId = editor.selection.focus.blockId;
    editor = reduceEditor(
      editor,
      SetTabStopsAction(
        blockId.value,
        const [
          TabStop(
            position: 144,
            alignment: TabAlignment.right,
            leader: LeaderStyle.line,
          ),
        ],
      ),
    );

    final host = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '400px')
      ..style.setProperty('font-family', 'monospace')
      ..style.setProperty('font-size', '16px');
    web.document.body!.appendChild(host);
    addTearDown(() => host.remove());
    final reconciler = DigitalDomReconciler(
      host: host,
      document: web.document,
      components: createDefaultComponentRegistry(),
      attrs: createDefaultAttrRegistry(),
    );
    reconciler.mount(editor.state);
    await Future<void>.delayed(const Duration(milliseconds: 35));

    final tab = host.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(tab.getAttribute('data-tw-tab-layout'), 'right');
    expect(tab.getAttribute('data-tw-tab-alignment'), 'right');
    expect(tab.getAttribute('data-tw-tab-leader'), 'line');
    expect(tab.getAttribute('style'), contains('linear-gradient'));
    expect(
        _followingRange(tab).getBoundingClientRect().right -
            (tab.parentNode! as web.HTMLElement).getBoundingClientRect().left,
        closeTo(144, 2));
    final initialTab = tab;

    final next = reduceEditor(editor, const InsertTextAction('!'));
    reconciler.reconcile(next.state);
    await Future<void>.delayed(const Duration(milliseconds: 35));

    final reconciledTab =
        host.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(identical(reconciledTab, initialTab), isTrue);
    expect(reconciledTab.getAttribute('data-tw-tab-layout'), 'right');
    expect(
      _followingRange(reconciledTab).getBoundingClientRect().right -
          (reconciledTab.parentNode! as web.HTMLElement)
              .getBoundingClientRect()
              .left,
      closeTo(144, 2),
    );
    expect(
      BrowserSelectionBridge(reconciler.root! as web.HTMLElement)
          .domToPosition(reconciledTab, 1),
      Position(blockId: blockId, offset: 2),
    );
    reconciler.destroy();
  });

  test('measures center, right and decimal tabs in horizontal LTR flow', () {
    const stop = 208.0;
    final host = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '420px')
      ..style.setProperty('font-family', 'monospace')
      ..style.setProperty('font-size', '16px');
    web.document.body!.appendChild(host);
    addTearDown(() => host.remove());

    final center = _mountTabParagraph(
      host,
      key: 'center',
      alignment: TabAlignment.center,
      stop: stop,
      textAfterTab: 'Centro',
    );
    final centerTab = center.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(centerTab.getAttribute('data-tw-tab-layout'), 'center');
    final centerRect = _followingRange(centerTab).getBoundingClientRect();
    expect(
      (centerRect.left + centerRect.right) / 2 -
          center.getBoundingClientRect().left,
      closeTo(stop, 2),
    );

    final right = _mountTabParagraph(
      host,
      key: 'right',
      alignment: TabAlignment.right,
      stop: stop,
      textAfterTab: 'Direita',
    );
    final rightTab = right.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(rightTab.getAttribute('data-tw-tab-layout'), 'right');
    expect(
      _followingRange(rightTab).getBoundingClientRect().right -
          right.getBoundingClientRect().left,
      closeTo(stop, 2),
    );

    final decimal = _mountTabParagraph(
      host,
      key: 'decimal',
      alignment: TabAlignment.decimal,
      stop: stop,
      textAfterTab: '12.345,67',
    );
    final decimalTab =
        decimal.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(decimalTab.getAttribute('data-tw-tab-layout'), 'decimal');
    final decimalText = _firstTextNode(decimalTab.nextSibling!);
    const decimalIndex = 6; // 12.345,67: the final comma is the separator.
    final decimalRange = web.document.createRange()
      ..setStart(decimalText, decimalIndex)
      ..setEnd(decimalText, decimalIndex + 1);
    final decimalRect = decimalRange.getBoundingClientRect();
    expect(
      decimalRect.left +
          decimalRect.width / 2 -
          decimal.getBoundingClientRect().left,
      closeTo(stop, 2),
    );

    // Each tab reads only up to the next tab. Resolving the first therefore
    // cannot consume or replace the second atom, and the later tab observes
    // its current browser-flow pen after the first advance was applied.
    final multiple = cascadePass(createElementBox(
      'tab-multiple',
      const Style(
        display: Display.block,
        tabStops: [
          TabStop(
            position: 120,
            alignment: TabAlignment.center,
            leader: LeaderStyle.none,
          ),
          TabStop(
            position: 280,
            alignment: TabAlignment.right,
            leader: LeaderStyle.none,
          ),
        ],
      ),
      [
        createTextBox('tab-multiple/before', const Style(), 'A'),
        createElementBox(
          'tab-multiple/one',
          const Style(),
          const [],
          const LayoutBoxMetadata(embedType: 'tab'),
        ),
        createTextBox('tab-multiple/one-text', const Style(), 'Um'),
        createElementBox(
          'tab-multiple/two',
          const Style(),
          const [],
          const LayoutBoxMetadata(embedType: 'tab'),
        ),
        createTextBox('tab-multiple/two-text', const Style(), 'Dois'),
      ],
    ));
    final multipleDom =
        renderNodeToDom(multiple, web.document, stampBlockIds: true)
            as web.HTMLElement;
    host.appendChild(multipleDom);
    layoutTabStopsInDom(multipleDom);
    final multipleTabs = multipleDom.querySelectorAll('[data-tw-tab]');
    final firstTab = multipleTabs.item(0)! as web.HTMLElement;
    final secondTab = multipleTabs.item(1)! as web.HTMLElement;
    expect(firstTab.getAttribute('data-tw-tab-layout'), 'center');
    expect(secondTab.getAttribute('data-tw-tab-layout'), 'right');
    final firstRect = _followingRange(firstTab).getBoundingClientRect();
    expect(
      (firstRect.left + firstRect.right) / 2 -
          multipleDom.getBoundingClientRect().left,
      closeTo(120, 2),
    );
    expect(
      _followingRange(secondTab).getBoundingClientRect().right -
          multipleDom.getBoundingClientRect().left,
      closeTo(280, 2),
    );
  });

  test('keeps RTL tabs on an explicit safe fallback', () {
    final host = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '360px')
      ..style.setProperty('font-family', 'monospace')
      ..style.setProperty('font-size', '16px');
    web.document.body!.appendChild(host);
    addTearDown(() => host.remove());

    final paragraph = _mountTabParagraph(
      host,
      key: 'rtl',
      alignment: TabAlignment.right,
      stop: 180,
      textAfterTab: 'ימין',
    )..setAttribute('dir', 'rtl');
    layoutTabStopsInDom(paragraph);

    final tab = paragraph.querySelector('[data-tw-tab]') as web.HTMLElement;
    expect(tab.getAttribute('data-tw-tab-layout'), 'fallback-rtl');
    expect(tab.getAttribute('data-tw-tab-advance'), '4ch');
  });

  test('renders generated list markers outside editable content', () {
    final root = cascadePass(createElementBox(
      'root',
      const Style(display: Display.block),
      [
        createElementBox(
          'item',
          const Style(display: Display.listItem, markerText: '1.'),
          const [],
          const LayoutBoxMetadata(
            list: ListMetadata(level: 0, listId: 'list', ordered: true),
          ),
        ),
      ],
    ));
    final rootDom =
        renderNodeToDom(root, web.document, stampBlockIds: true) as web.Element;
    final itemDom = rootDom.querySelector('ol > li');
    expect(itemDom, isNotNull);
    final marker = itemDom!.querySelector('[data-tw-marker]');
    expect(marker, isNotNull);
    expect(marker!.getAttribute('contenteditable'), 'false');
    expect(itemDom.querySelector('br[data-tw-empty-line]'), isNotNull);
  });

  test('projects a multi-column section into a keyed CSS column container', () {
    final section = cascadePass(createElementBox(
      'section-1',
      const Style(display: Display.contents),
      [
        createElementBox(
          'paragraph-1',
          const Style(display: Display.block),
          [createTextBox('paragraph-1/run', const Style(), 'Colunas')],
        ),
      ],
      const LayoutBoxMetadata(
        blockType: 'section',
        columnCount: 2,
        columnGap: 24,
        columnRule: ColumnRule(
          width: 1,
          style: BorderStyle.solid,
          color: '#5b9bd5',
        ),
      ),
    ));

    final dom = renderNodeToDom(section, web.document, stampBlockIds: true)
        as web.HTMLElement;
    final style = dom.getAttribute('style') ?? '';

    expect(dom.localName, 'section');
    expect(dom.getAttribute('data-block-id'), 'section-1');
    expect(dom.getAttribute('data-tw-column-count'), '2');
    expect(style, contains('display: block'));
    expect(style, contains('column-count: 2'));
    expect(style, contains('column-gap: 24px'));
    expect(style, contains('column-rule: 1px solid #5b9bd5'));

    final paragraph =
        dom.querySelector('[data-block-id="paragraph-1"]') as web.HTMLElement;
    expect(paragraph.textContent, 'Colunas');
    // The nearest keyed element remains the authored paragraph rather than the
    // column container, so model offsets keep their leaf-block identity.
    final position =
        BrowserSelectionBridge(dom).domToPosition(_firstTextNode(paragraph), 3);
    expect(
        position, const Position(blockId: BlockId('paragraph-1'), offset: 3));
  });

  test('projects single-column sections as keyed page boundaries', () {
    final section = cascadePass(createElementBox(
      'section-one',
      const Style(display: Display.contents),
      [
        createElementBox(
          'paragraph-one',
          const Style(display: Display.block),
          [createTextBox('paragraph-one/run', const Style(), 'Uma coluna')],
        ),
      ],
      const LayoutBoxMetadata(blockType: 'section', columnCount: 1),
    ));

    final dom = renderNodeToDom(section, web.document, stampBlockIds: true)
        as web.HTMLElement;
    final style = dom.getAttribute('style') ?? '';

    expect(dom.localName, 'section');
    expect(dom.getAttribute('data-block-id'), 'section-one');
    expect(dom.hasAttribute('data-tw-section'), isTrue);
    expect(dom.getAttribute('data-tw-section-break'), 'page');
    expect(style, contains('display: block'));
    expect(style, contains('break-before: page'));
    expect(style, contains('page-break-before: always'));
  });

  test('explicit sections span an inherited column set before owning columns',
      () {
    final section = cascadePass(createElementBox(
      'section-spanning',
      const Style(display: Display.contents),
      [
        createElementBox(
          'section-paragraph',
          const Style(display: Display.block),
          [createTextBox('section-paragraph/run', const Style(), 'Seção')],
        ),
      ],
      const LayoutBoxMetadata(blockType: 'section', columnCount: 1),
    ));
    final root = cascadePass(createElementBox(
      'column-root',
      const Style(display: Display.block),
      [section],
      const LayoutBoxMetadata(columnCount: 2, columnGap: 20),
    ));
    final dom = renderNodeToDom(root, web.document, stampBlockIds: true)
        as web.HTMLElement;
    dom.style.setProperty('width', '360px');
    web.document.body!.appendChild(dom);
    addTearDown(() => dom.remove());

    final sectionDom =
        dom.querySelector('[data-tw-section]') as web.HTMLElement;
    final documentWidth = dom.getBoundingClientRect().width;
    final sectionWidth = sectionDom.getBoundingClientRect().width;
    expect(sectionDom.hasAttribute('data-tw-section-spans-parent-columns'),
        isTrue);
    expect(sectionWidth, closeTo(documentWidth, 1),
        reason:
            'a new section cannot be squeezed into the preceding section/root columns');
  });

  test('projects columns from the implicit document section', () {
    final dom = renderDocumentToDom(
      _stateWithImplicitColumns('Documento em colunas'),
      createDefaultComponentRegistry(),
      createDefaultAttrRegistry(),
      web.document,
    );
    final style = dom.getAttribute('style') ?? '';

    expect(dom.localName, 'div');
    expect(dom.getAttribute('data-tw-column-count'), '3');
    expect(style, contains('column-count: 3'));
    expect(style, contains('column-gap: 18px'));
    expect(dom.textContent, 'Documento em colunas');
  });

  test('reconciles a multi-column section without replacing leaf DOM identity',
      () {
    var state = _stateWithMultiColumnSection('Antes');
    final host = web.document.createElement('div') as web.HTMLElement;
    final reconciler = DigitalDomReconciler(
      host: host,
      document: web.document,
      components: createDefaultComponentRegistry(),
      attrs: createDefaultAttrRegistry(),
    );
    reconciler.mount(state);

    final section =
        host.querySelector('[data-block-id="section"]') as web.HTMLElement;
    final paragraph =
        host.querySelector('[data-block-id="paragraph"]') as web.HTMLElement;
    final bridge = BrowserSelectionBridge(reconciler.root! as web.HTMLElement);
    expect(
      bridge.domToPosition(_firstTextNode(paragraph), 2),
      const Position(blockId: BlockId('paragraph'), offset: 2),
    );

    state = insertText(
      state,
      const Position(blockId: BlockId('paragraph'), offset: 5),
      ' depois',
      const {},
    ).state;
    reconciler.reconcile(state);

    final nextSection =
        host.querySelector('[data-block-id="section"]') as web.HTMLElement;
    final nextParagraph =
        host.querySelector('[data-block-id="paragraph"]') as web.HTMLElement;
    expect(identical(nextSection, section), isTrue);
    expect(identical(nextParagraph, paragraph), isTrue);
    expect(nextParagraph.textContent, 'Antes depois');
    expect(
      bridge.domToPosition(_firstTextNode(nextParagraph), 8),
      const Position(blockId: BlockId('paragraph'), offset: 8),
    );
  });
}

State _stateWithMultiColumnSection(String text) {
  const rootId = BlockId('root');
  const sectionId = BlockId('section');
  const paragraphId = BlockId('paragraph');
  final doc = TwDoc.create(rootId: rootId);
  doc.transact(() {
    doc.setBlockMap(rootId.value, {
      BlockFields.type: 'document',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.firstChildId: sectionId.value,
      BlockFields.lastChildId: sectionId.value,
    });
    doc.setBlockMap(sectionId.value, {
      BlockFields.type: 'section',
      BlockFields.attrs: <String, dynamic>{
        'columnCount': 2,
        'columnGap': 24,
      },
      BlockFields.parentId: rootId.value,
      BlockFields.firstChildId: paragraphId.value,
      BlockFields.lastChildId: paragraphId.value,
    });
    doc.setBlockMap(paragraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: sectionId.value,
      BlockFields.inlineContent: InlineContent([TextItem(text: text)]),
    });
  });
  return createState(rootId: rootId, doc: doc);
}

State _stateWithImplicitColumns(String text) {
  const rootId = BlockId('implicit-root');
  const paragraphId = BlockId('implicit-paragraph');
  final doc = TwDoc.create(rootId: rootId);
  doc.transact(() {
    doc.setBlockMap(rootId.value, {
      BlockFields.type: 'document',
      BlockFields.attrs: <String, dynamic>{
        'columnCount': 3,
        'columnGap': 18,
      },
      BlockFields.firstChildId: paragraphId.value,
      BlockFields.lastChildId: paragraphId.value,
    });
    doc.setBlockMap(paragraphId.value, {
      BlockFields.type: 'paragraph',
      BlockFields.attrs: <String, dynamic>{},
      BlockFields.parentId: rootId.value,
      BlockFields.inlineContent: InlineContent([TextItem(text: text)]),
    });
  });
  return createState(rootId: rootId, doc: doc);
}

web.HTMLElement _mountTabParagraph(
  web.HTMLElement host, {
  required String key,
  required TabAlignment alignment,
  required double stop,
  required String textAfterTab,
}) {
  final paragraph = cascadePass(createElementBox(
    'tab-$key',
    Style(
      display: Display.block,
      tabStops: [
        TabStop(
          position: stop,
          alignment: alignment,
          leader: LeaderStyle.none,
        ),
      ],
    ),
    [
      createTextBox('tab-$key/before', const Style(), 'A'),
      createElementBox(
        'tab-$key/inline',
        const Style(),
        const [],
        const LayoutBoxMetadata(embedType: 'tab'),
      ),
      createTextBox('tab-$key/after', const Style(), textAfterTab),
    ],
  ));
  final dom = renderNodeToDom(paragraph, web.document, stampBlockIds: true)
      as web.HTMLElement;
  host.appendChild(dom);
  layoutTabStopsInDom(dom);
  return dom;
}

web.Range _followingRange(web.HTMLElement tab) {
  final parent = tab.parentNode!;
  final range = web.document.createRange()..setStartAfter(tab);
  web.Node? current = tab.nextSibling;
  while (current != null) {
    if (current.nodeType == web.Node.ELEMENT_NODE &&
        (current as web.HTMLElement).hasAttribute('data-tw-tab')) {
      range.setEndBefore(current);
      return range;
    }
    current = current.nextSibling;
  }
  range.setEnd(parent, parent.childNodes.length);
  return range;
}

web.Node _firstTextNode(web.Node node) {
  if (node.nodeType == web.Node.TEXT_NODE) return node;
  for (var index = 0; index < node.childNodes.length; index++) {
    final child = node.childNodes.item(index);
    if (child != null) return _firstTextNode(child);
  }
  throw StateError('Expected a text node below the rendered paragraph.');
}
