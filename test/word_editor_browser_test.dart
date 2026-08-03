@TestOn('browser')

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:taleweaver/taleweaver.dart';

void main() {
  group('DigitalEditorHost', () {
    test('mounts exactly one embeddable contenteditable surface', () {
      final container = _appendContainer();
      var mounts = 0;
      var changes = 0;
      final editor = DigitalEditorHost.mount(
        container,
        config: DigitalEditorHostConfig(
          surfaceClassName: 'consumer-document-surface',
          ariaLabel: 'Documento incorporado',
          surfaceAttributes: const {'data-owner': 'browser-test'},
          onMount: (_) => mounts++,
          onChange: (_) => changes++,
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      expect(mounts, 1);
      expect(container.querySelectorAll('[data-tw-digital-surface]').length, 1);
      expect(container.querySelectorAll('[contenteditable]').length, 1);
      expect(editor.surface.classList.contains('consumer-document-surface'),
          isTrue);
      expect(editor.surface.getAttribute('role'), 'textbox');
      expect(editor.surface.getAttribute('aria-multiline'), 'true');
      expect(
          editor.surface.getAttribute('aria-label'), 'Documento incorporado');
      expect(editor.surface.getAttribute('data-owner'), 'browser-test');
      expect(editor.surface.getAttribute('contenteditable'), 'true');
      expect(editor.blockElement(editor.editorState.selection.focus.blockId),
          isNotNull);

      editor.dispatch(const PasteTextAction('Dart puro incorporável'));
      expect(editor.surface.textContent, contains('Dart puro incorporável'));
      expect(changes, greaterThanOrEqualTo(1));

      editor.setReadOnly(true);
      expect(editor.surface.getAttribute('contenteditable'), 'false');
      expect(editor.surface.getAttribute('aria-readonly'), 'true');
    });

    test('rejects competing controller and initial state sources', () {
      final container = _appendContainer();
      addTearDown(() => container.remove());
      final controller = DigitalEditorController();

      expect(
        () => DigitalEditorHost.mount(
          container,
          controller: controller,
          config: DigitalEditorHostConfig(
            initialEditorState: createInitialEditorState(),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('Ctrl+Enter creates a manual page break through the host pipeline',
        () {
      final container = _appendContainer();
      final editor = DigitalEditorHost.mount(container);
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      editor.dispatch(const PasteTextAction('AntesDepois'));
      final firstId = editor.editorState.selection.focus.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: firstId, offset: 5),
        focus: Position(blockId: firstId, offset: 5),
      )));
      editor.surface.dispatchEvent(web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'Enter',
          ctrlKey: true,
          bubbles: true,
          cancelable: true,
        ),
      ));

      final followingId =
          getBlock(editor.editorState.state, firstId)!.nextSiblingId!;
      expect(
          getBlock(editor.editorState.state, followingId)!.attrs['breakBefore'],
          'page');
      expect(editor.surface.querySelector('[data-tw-manual-page-break]'),
          isNotNull);
    });
  });

  group('TaleweaverEditor', () {
    test('builds a complete Word shell around one controlled surface', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(
          documentTitle: 'Contrato incorporado',
          initialText: 'Documento inicial para integração.',
          height: '640px',
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      expect(container.querySelectorAll('[data-taleweaver-editor-root]').length,
          1);
      expect(editor.root.querySelector('[data-testid="tw-ribbon-tabs"]'),
          isNotNull);
      expect(editor.root.querySelector('[data-testid="tw-ribbon-panel-home"]'),
          isNotNull);
      expect(editor.root.querySelector('[data-testid="tw-rulers"]'), isNotNull);
      expect(editor.root.querySelector('[data-testid="tw-vertical-ruler"]'),
          isNotNull);
      expect(editor.root.querySelector('[data-testid="tw-editor-workspace"]'),
          isNotNull);
      expect(editor.root.querySelector('[data-testid="tw-status"]'), isNotNull);

      final surfaces =
          editor.root.querySelectorAll('[data-tw-digital-surface]');
      expect(surfaces.length, 1);
      expect(
          editor.root.querySelectorAll('[contenteditable="true"]').length, 1);
      final surface = surfaces.item(0) as web.HTMLElement;
      expect(surface.getAttribute('data-testid'), 'tw-editor-surface');
      expect(surface.getAttribute('contenteditable'), 'true');
      expect(
          surface.textContent, contains('Documento inicial para integração.'));
      expect(editor.root.style.height, '640px');
      // An embeddable editor must not impose a second application title bar.
      expect(editor.root.classList.contains('tw-editor--no-titlebar'), isTrue);
    });

    test('allows the host to opt into the document title bar', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(
          documentTitle: 'Contrato com capa',
          showTitleBar: true,
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      expect(editor.root.classList.contains('tw-editor--no-titlebar'), isFalse);
      expect(
        (editor.root.querySelector('.tw-editor__document-title')
                as web.HTMLInputElement)
            .value,
        'Contrato com capa',
      );
    });

    test('keeps controlled callbacks, page metrics and host lifecycle honest',
        () {
      final container = _appendContainer();
      container.style.setProperty('min-height', '11px');
      var documentChanges = 0;
      var stateChanges = 0;
      final modes = <TaleweaverEditorMode>[];
      final views = <TaleweaverDocumentView>[];
      final zooms = <double>[];
      final titles = <String>[];
      final editor = TaleweaverEditor.mount(
        container,
        options: TaleweaverEditorOptions(
          initialText: 'estado',
          hostStyles: const {'min-height': '650px'},
          themeVariables: const {'--tw-accent': '#7c3aed'},
          editorConfig: const EditorConfig(
            pageConfig: PageConfig(
              width: 720,
              height: 900,
              margins: PageMargins(left: 54, right: 54),
            ),
          ),
          onChanged: (_) => documentChanges++,
          onStateChanged: (_) => stateChanges++,
          onModeChanged: modes.add,
          onDocumentViewChanged: views.add,
          onZoomChanged: zooms.add,
          onTitleChanged: titles.add,
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      expect(editor.root.style.getPropertyValue('--tw-page-width'), '960.00px');
      expect(editor.root.style.getPropertyValue('--tw-accent'), '#7c3aed');
      expect(container.style.getPropertyValue('min-height'), '650px');
      expect(editor.root.getAttribute('lang'), 'pt-BR');

      final blockId = editor.editorState.selection.focus.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 0),
      )));
      expect(documentChanges, 0);
      expect(stateChanges, 1);
      expect(
          editor.root
              .querySelector('[data-testid="tw-save-state"]')!
              .textContent,
          'Salvo');

      editor.dispatch(const InsertTextAction('novo '));
      expect(documentChanges, 1);
      expect(stateChanges, 2);
      expect(
          editor.root
              .querySelector('[data-testid="tw-save-state"]')!
              .textContent,
          'Alterado');

      editor.setMode(TaleweaverEditorMode.viewer);
      editor.setDocumentView(TaleweaverDocumentView.continuous);
      editor.setZoom(.9);
      editor.setDocumentTitle('Contrato controlado');
      expect(modes, [TaleweaverEditorMode.viewer]);
      expect(views, [TaleweaverDocumentView.continuous]);
      expect(zooms, [.9]);
      expect(editor.root.querySelector('.tw-editor__zoom-percent')!.textContent,
          '90%');
      expect(titles, ['Contrato controlado']);

      editor.destroy();
      expect(container.style.getPropertyValue('min-height'), '11px');
    });

    test('rejects ambiguous controller and initial text options', () {
      final container = _appendContainer();
      addTearDown(() => container.remove());

      expect(
        () => TaleweaverEditor.mount(
          container,
          options: TaleweaverEditorOptions(
            controller: DigitalEditorController(),
            initialText: 'não deve ser ignorado',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('ribbon controls switch document view, rulers and reader mode', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(
          initialText: 'Conteúdo de leitura',
          documentView: TaleweaverDocumentView.paginated,
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final viewTab = _button(editor.root, 'tw-ribbon-tab-view');
      viewTab.click();
      expect(viewTab.getAttribute('aria-selected'), 'true');
      expect(
        editor.root
            .querySelector('[data-testid="tw-ribbon-panel-view"]')!
            .classList
            .contains('tw-editor__ribbon-panel--active'),
        isTrue,
      );

      _command(editor.root, 'view-continuous').click();
      expect(editor.documentView, TaleweaverDocumentView.continuous);
      expect(editor.root.classList.contains('tw-editor--continuous'), isTrue);
      expect(
        editor.root
            .querySelector('[data-testid="tw-status-mode"]')!
            .textContent,
        'Layout web',
      );

      _command(editor.root, 'rulers').click();
      expect(editor.root.classList.contains('tw-editor--no-rulers'), isTrue);
      _command(editor.root, 'rulers').click();
      expect(editor.root.classList.contains('tw-editor--no-rulers'), isFalse);

      _command(editor.root, 'viewer').click();
      final surface =
          editor.root.querySelector('[data-testid="tw-editor-surface"]')
              as web.HTMLElement;
      expect(editor.mode, TaleweaverEditorMode.viewer);
      expect(editor.root.classList.contains('tw-editor--viewer'), isTrue);
      expect(surface.getAttribute('contenteditable'), 'false');
      expect(surface.getAttribute('aria-readonly'), 'true');
      expect(
          (editor.root.querySelector('.tw-editor__document-title')
                  as web.HTMLInputElement)
              .disabled,
          isTrue);

      _command(editor.root, 'editor').click();
      expect(editor.mode, TaleweaverEditorMode.editor);
      expect(surface.getAttribute('contenteditable'), 'true');
      expect(
          (editor.root.querySelector('.tw-editor__document-title')
                  as web.HTMLInputElement)
              .disabled,
          isFalse);
    });

    test('Insert ribbon creates a manual page break without changing section',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'AntesDepois'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final firstId = editor.editorState.selection.focus.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: firstId, offset: 5),
        focus: Position(blockId: firstId, offset: 5),
      )));
      _button(editor.root, 'tw-ribbon-tab-insert').click();
      _command(editor.root, 'page-break').click();

      final followingId =
          getBlock(editor.editorState.state, firstId)!.nextSiblingId!;
      final following = getBlock(editor.editorState.state, followingId)!;
      expect(following.attrs['breakBefore'], 'page');
      expect(
          iterateBlocksInDocumentOrder(editor.editorState.state)
              .where((block) => block.type == 'section'),
          isEmpty);
      final marker =
          editor.root.querySelector('[data-block-id="${followingId.value}"]');
      expect(marker?.hasAttribute('data-tw-manual-page-break'), isTrue);
    });

    test('Word rulers persist margins, paragraph indents and tab markers', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Régua ativa'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final marginLeft =
          editor.root.querySelector('[data-ruler-handle="margin-left"]')
              as web.HTMLElement;
      expect(marginLeft.getAttribute('role'), 'slider');
      final zero = editor.root.querySelector('.tw-editor__ruler-number')
          as web.HTMLElement;
      expect(zero.textContent, '0');
      expect(zero.style.left, startsWith('11.764'));
      marginLeft.dispatchEvent(web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'ArrowRight', bubbles: true),
      ));
      final root =
          getBlock(editor.editorState.state, editor.editorState.state.rootId)!;
      final margins = root.attrs['pageMargins'] as Map;
      expect(margins['inlineStart'], 75.0);
      expect(
          editor.root.style.getPropertyValue('--tw-margin-left'), '100.00px');

      editor.dispatch(const SetParagraphIndentsAction(48, 24, -12));
      final blockId = editor.editorState.selection.focus.blockId;
      final paragraph = getBlock(editor.editorState.state, blockId)!;
      expect(paragraph.attrs['marginInlineStart'], 48.0);
      expect(paragraph.attrs['marginInlineEnd'], 24.0);
      expect(paragraph.attrs['textIndent'], -12.0);
      final leftIndent =
          editor.root.querySelector('[data-ruler-handle="indent-left"]')
              as web.HTMLElement;
      expect(leftIndent.style.left, isNotEmpty);

      editor.dispatch(SetTabStopsAction(blockId.value, const [
        TabStop(
          position: 96,
          alignment: TabAlignment.left,
          leader: LeaderStyle.dot,
        ),
      ]));
      editor.dispatch(const InsertTabAction());
      expect(editor.root.querySelector('[data-tw-tab]'), isNotNull);
      expect(editor.root.querySelector('.tw-editor__ruler-tab'), isNotNull);
      final selector =
          editor.root.querySelector('[data-testid="tw-ruler-tab-selector"]')
              as web.HTMLButtonElement;
      selector.click();
      expect(selector.getAttribute('aria-label'), contains('centralizada'));
    });

    test('style gallery supports semantic and custom heading titles', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(
          initialText: 'Cláusula do contrato',
          headingStyles: [
            TaleweaverHeadingStyle(
              id: 'clause',
              label: 'Cláusula',
              description: 'Título de cláusula',
              level: 2,
            ),
          ],
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-style-clause').click();
      final id = editor.editorState.selection.focus.blockId;
      final heading = getBlock(editor.editorState.state, id)!;
      expect(heading.type, 'heading');
      expect(heading.attrs['level'], 2);
      expect(editor.root.querySelector('h2'), isNotNull);
      expect(
          _button(editor.root, 'tw-style-clause').getAttribute('aria-pressed'),
          'true');

      _button(editor.root, 'tw-style-paragraph').click();
      expect(getBlock(editor.editorState.state, id)!.type, 'paragraph');
      expect(
          _button(editor.root, 'tw-style-paragraph')
              .getAttribute('aria-pressed'),
          'true');
    });

    test('Layout ribbon applies page margins through the document action', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Página'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-layout').click();
      _command(editor.root, 'margins').click();
      final dialog =
          editor.root.querySelector('[data-testid="tw-page-setup-dialog"]');
      expect(dialog, isNotNull);
      (editor.root.querySelector('[data-testid="tw-margin-top"]')
              as web.HTMLInputElement)
          .value = '2.50';
      (editor.root.querySelector('[data-testid="tw-margin-bottom"]')
              as web.HTMLInputElement)
          .value = '2.00';
      (editor.root.querySelector('[data-testid="tw-margin-left"]')
              as web.HTMLInputElement)
          .value = '3.00';
      (editor.root.querySelector('[data-testid="tw-margin-right"]')
              as web.HTMLInputElement)
          .value = '1.50';
      _button(editor.root, 'tw-page-setup-apply').click();

      final root =
          getBlock(editor.editorState.state, editor.editorState.state.rootId)!;
      final margins = root.attrs['pageMargins'] as Map;
      expect((margins['blockStart'] as num).toDouble(), closeTo(70.87, .01));
      expect((margins['inlineStart'] as num).toDouble(), closeTo(85.04, .01));
      expect(editor.root.querySelector('[data-testid="tw-page-setup-dialog"]'),
          isNull);
      expect(
          editor.root.style.getPropertyValue('--tw-margin-left'), '113.39px');
    });

    test('Layout ribbon persists a paper size through the document action', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Papel A4'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-layout').click();
      _command(editor.root, 'page-size').click();
      expect(editor.root.querySelector('[data-testid="tw-page-size-dialog"]'),
          isNotNull);
      final preset =
          editor.root.querySelector('[data-testid="tw-page-size-preset"]')
              as web.HTMLSelectElement;
      preset.value = 'a4';
      preset.dispatchEvent(web.Event('change'));
      _button(editor.root, 'tw-page-size-apply').click();

      final root =
          getBlock(editor.editorState.state, editor.editorState.state.rootId)!;
      expect((root.attrs['pageInlineSize'] as num).toDouble(),
          closeTo(595.28, .01));
      expect((root.attrs['pageBlockSize'] as num).toDouble(),
          closeTo(841.89, .01));
      expect(editor.root.querySelector('[data-testid="tw-page-size-dialog"]'),
          isNull);
      expect(editor.root.style.getPropertyValue('--tw-page-width'), '793.71px');
      expect(
          editor.root.style.getPropertyValue('--tw-page-height'), '1122.52px');
    });

    test('active section layout updates the Word paper and browser columns',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Seção de página'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      editor.dispatch(const SplitNodeAction());
      editor.dispatch(const SectionBreakAction());
      _button(editor.root, 'tw-ribbon-tab-layout').click();
      _command(editor.root, 'orientation').click();
      expect(
          editor.root.style.getPropertyValue('--tw-page-width'), '1056.00px');
      expect(
          editor.root.style.getPropertyValue('--tw-page-height'), '816.00px');

      editor.dispatch(const SetSectionColumnsAction(2, columnGap: 24));
      final columns = editor.root.querySelector('[data-tw-column-count="2"]');
      expect(columns, isNotNull);
      expect(columns!.getAttribute('data-block-id'), isNotNull);
      expect(columns.getAttribute('style'), contains('column-count: 2'));
    });

    test('paginated view creates physical page breaks without cloning content',
        () async {
      final container = _appendContainer();
      final longText = List<String>.filled(
        1200,
        'Texto longo que continua em uma nova página mantendo a mesma seleção.',
      ).join(' ');
      final editor = TaleweaverEditor.mount(
        container,
        options: TaleweaverEditorOptions(
          initialText: longText,
          height: '640px',
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      // The paginator measures after layout in an animation frame.
      await Future<void>.delayed(const Duration(milliseconds: 550));

      final surface =
          editor.root.querySelector('[data-testid="tw-editor-surface"]')
              as web.HTMLElement;
      final pageCount =
          int.parse(surface.getAttribute('data-page-count') ?? '1');
      final pagination =
          surface.querySelector('[data-tw-pagination-decoration]');
      expect(pageCount, greaterThan(1));
      expect(pagination, isNotNull);
      expect(
        pagination!.querySelectorAll('.tw-editor__page-break').length,
        pageCount + 1,
      );
      expect(
        pagination.querySelectorAll('.tw-editor__page-header').length,
        pageCount,
      );
      expect(
        pagination.querySelectorAll('.tw-editor__page-footer').length,
        pageCount,
      );
      expect(pagination.querySelector('[data-block-id]'), isNull);
      expect(pagination.getAttribute('contenteditable'), 'false');
      expect(surface.textContent, contains('Texto longo que continua'));
      final blockId = editor.editorState.selection.focus.blockId.value;
      final paragraph = surface.querySelector('[data-block-id="$blockId"]');
      expect(paragraph, isNotNull);
      final range = web.document.createRange()..selectNodeContents(paragraph!);
      final rects = range.getClientRects();
      var largestLineJump = 0.0;
      double? previousTop;
      for (var index = 0; index < rects.length; index++) {
        final rect = rects.item(index);
        if (rect == null) continue;
        if (previousTop != null) {
          largestLineJump = (rect.top - previousTop) > largestLineJump
              ? rect.top - previousTop
              : largestLineJump;
        }
        previousTop = rect.top;
      }
      expect(largestLineJump, greaterThan(40));
      // The initial caret is at the end of this long paragraph. The status
      // bar must follow its physical page rather than claiming page one.
      expect(
        editor.root.querySelector('[data-testid="tw-status"]')!.textContent,
        contains('Página $pageCount de $pageCount'),
      );

      editor.setDocumentView(TaleweaverDocumentView.continuous);
      expect(surface.querySelector('[data-tw-pagination-decoration]'), isNull);
      expect(surface.hasAttribute('data-tw-pages'), isFalse);
    });

    test('physical page count is stable across visual zoom levels', () async {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: TaleweaverEditorOptions(
          initialText: List<String>.filled(
            900,
            'O zoom deve ampliar apenas a visualização, sem mudar a paginação física.',
          ).join(' '),
          editorConfig: const EditorConfig(
            pageConfig: PageConfig(
              width: 360,
              height: 270,
              margins: PageMargins(top: 30, right: 30, bottom: 30, left: 30),
            ),
          ),
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final surface =
          editor.root.querySelector('[data-testid="tw-editor-surface"]')
              as web.HTMLElement;
      int pageCount() =>
          int.parse(surface.getAttribute('data-page-count') ?? '1');

      // Measurement settles on a timer and an animation frame. Use the same
      // long document at all levels so this asserts only the coordinate-space
      // conversion, not a content or page-setup change.
      await Future<void>.delayed(const Duration(milliseconds: 750));
      final at100Percent = pageCount();
      expect(at100Percent, greaterThan(1));

      editor.setZoom(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(pageCount(), at100Percent);

      editor.setZoom(2.0);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(pageCount(), at100Percent);
    });

    test('repeats template projections with concrete page fields', () async {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: TaleweaverEditorOptions(
          initialText: List<String>.filled(
            1200,
            'Corpo suficiente para repetir cabeçalhos e rodapés em páginas.',
          ).join(' '),
          height: '640px',
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-insert').click();
      _command(editor.root, 'header').click();
      editor.dispatch(const InsertTextAction('Cabeçalho repetido '));
      _command(editor.root, 'page-number').click();
      _command(editor.root, 'footer').click();
      editor.dispatch(const InsertTextAction('Rodapé repetido'));

      await Future<void>.delayed(const Duration(milliseconds: 650));

      final surface =
          editor.root.querySelector('[data-testid="tw-editor-surface"]')
              as web.HTMLElement;
      final pageCount =
          int.parse(surface.getAttribute('data-page-count') ?? '1');
      expect(pageCount, greaterThan(1));
      final header = surface
          .querySelector('.tw-editor__page-header[data-page-number="2"]');
      final footer = surface
          .querySelector('.tw-editor__page-footer[data-page-number="2"]');
      expect(header?.textContent, contains('Cabeçalho repetido'));
      expect(header?.textContent, contains('2'));
      expect(footer?.textContent, contains('Rodapé repetido'));
      expect(header?.querySelector('[data-block-id]'), isNull);
      expect(footer?.querySelector('[data-block-id]'), isNull);
    });

    test('ribbon formatting changes the selected document content', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'texto rico'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final blockId = editor.editorState.selection.anchor.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 5),
      )));

      _command(editor.root, 'bold').click();
      _command(editor.root, 'italic').click();

      final block = getBlock(editor.editorState.state, blockId)!;
      final formatted = block.inlineContent!.items
          .whereType<TextItem>()
          .where((item) =>
              item.attrs['bold'] == true && item.attrs['italic'] == true)
          .toList();
      expect(formatted, isNotEmpty);
      expect(editor.root.querySelector('strong'), isNotNull);
      expect(editor.root.querySelector('em'), isNotNull);
      expect(
          _command(editor.root, 'bold').getAttribute('aria-pressed'), 'true');
      expect(
          _command(editor.root, 'italic').getAttribute('aria-pressed'), 'true');
    });

    test('Ribbon restores selected text for font size and mirrors its context',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'forte normal'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final blockId = editor.editorState.selection.anchor.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 5),
      )));
      _command(editor.root, 'bold').click();

      final size =
          editor.root.querySelector('select[aria-label="Tamanho da fonte"]')
              as web.HTMLSelectElement;
      size.value = '18';
      size.dispatchEvent(web.Event('change'));

      final selectedRun = getBlock(editor.editorState.state, blockId)!
          .inlineContent!
          .items
          .whereType<TextItem>()
          .firstWhere((item) => item.text.contains('forte'));
      expect(selectedRun.attrs['bold'], isTrue);
      expect(selectedRun.attrs['fontSize'], 18.0);
      expect(size.value, '18');
      expect(
          _command(editor.root, 'bold').getAttribute('aria-pressed'), 'true');

      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 6),
        focus: Position(blockId: blockId, offset: 6),
      )));
      expect(
          _command(editor.root, 'bold').getAttribute('aria-pressed'), 'false');
      expect(size.value, '12');
    });

    test('Arquivo ribbon exposes DOCX and Delta integrations', () {
      final container = _appendContainer();
      String? exportedFormat;
      final editor = TaleweaverEditor.mount(
        container,
        options: TaleweaverEditorOptions(
          onExportDelta: (request) => exportedFormat = request.format,
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-file').click();
      expect(_command(editor.root, 'open-docx').getAttribute('aria-label'),
          'Abrir DOCX');
      expect(_command(editor.root, 'open-delta').getAttribute('aria-label'),
          'Abrir Delta');
      _command(editor.root, 'export-delta').click();
      expect(exportedFormat, 'quill-delta');
    });

    test('header and footer are real shared-controller template surfaces', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Corpo da página'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-insert').click();
      _command(editor.root, 'header').click();
      final header =
          editor.root.querySelector('[data-testid="tw-header-surface"]')
              as web.HTMLElement?;
      expect(header, isNotNull);
      expect(header!.getAttribute('contenteditable'), 'true');
      editor.dispatch(const InsertTextAction('Cabeçalho editável'));
      expect(header.textContent, contains('Cabeçalho editável'));

      _command(editor.root, 'page-number').click();
      // Template rendering resolves the field to its concrete value for the
      // visible first page rather than exposing its internal embed node.
      expect(header.textContent, contains('1'));

      _command(editor.root, 'footer').click();
      final footer =
          editor.root.querySelector('[data-testid="tw-footer-surface"]')
              as web.HTMLElement?;
      expect(footer, isNotNull);
      expect(footer!.getAttribute('contenteditable'), 'true');
      editor.dispatch(const InsertTextAction('Rodapé editável'));
      expect(footer.textContent, contains('Rodapé editável'));

      editor.setMode(TaleweaverEditorMode.viewer);
      expect(header.getAttribute('contenteditable'), 'false');
      expect(footer.getAttribute('contenteditable'), 'false');
    });

    test('link dialog preserves the model selection and emits only safe links',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'linkável'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      final blockId = editor.editorState.selection.anchor.blockId;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 4),
      )));
      _button(editor.root, 'tw-ribbon-tab-insert').click();
      _command(editor.root, 'link').click();
      final dialog =
          editor.root.querySelector('[data-testid="tw-link-dialog"]');
      expect(dialog, isNotNull);
      final field = editor.root.querySelector('[data-testid="tw-link-url"]')
          as web.HTMLInputElement;
      field.value = 'https://example.com/documento';
      _button(editor.root, 'tw-link-apply').click();
      final anchor = editor.root.querySelector('a');
      expect(anchor, isNotNull);
      expect(anchor!.getAttribute('href'), 'https://example.com/documento');

      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: blockId, offset: 0),
        focus: Position(blockId: blockId, offset: 4),
      )));
      _command(editor.root, 'link').click();
      final removeField = editor.root
          .querySelector('[data-testid="tw-link-url"]') as web.HTMLInputElement;
      removeField.value = '';
      _button(editor.root, 'tw-link-apply').click();
      expect(editor.root.querySelector('a'), isNull);
    });

    test('find and replace use document actions instead of browser DOM edits',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(
          initialText: 'Dart é puro. dart também é incorporável.',
        ),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _command(editor.root, 'find').click();
      expect(editor.root.querySelector('[data-testid="tw-find-dialog"]'),
          isNotNull);
      final query = editor.root.querySelector('[data-testid="tw-find-query"]')
          as web.HTMLInputElement;
      final replacement =
          editor.root.querySelector('[data-testid="tw-find-replacement"]')
              as web.HTMLInputElement;
      query.value = 'dart';
      query.dispatchEvent(web.Event('input'));
      expect(
        editor.root
            .querySelector('[data-testid="tw-find-result"]')!
            .textContent,
        '1 de 2 ocorrências',
      );
      expect(editor.editorState.selection.anchor.offset, 0);
      expect(editor.editorState.selection.focus.offset, 4);

      replacement.value = 'Dart';
      _button(editor.root, 'tw-find-replace-all').click();
      expect(
          editor.root
              .querySelector('[data-testid="tw-find-result"]')!
              .textContent,
          '1 de 2 ocorrências');
      expect(editor.root.textContent, contains('Dart é puro. Dart também'));
      expect(editor.editorState.history.canUndo, isTrue);
    });

    test('contextual table ribbon follows the active cell and mutates rows',
        () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Tabela'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      editor.dispatch(const InsertTableAction(2, 2));
      expect(editor.root.classList.contains('tw-editor--in-table'), isTrue);
      final tableTab = _button(editor.root, 'tw-ribbon-tab-table');
      tableTab.click();
      expect(tableTab.getAttribute('aria-selected'), 'true');
      expect(_command(editor.root, 'table-row-below').disabled, isFalse);
      expect(_command(editor.root, 'table-delete-row').disabled, isFalse);
      expect(_command(editor.root, 'table-delete-column').disabled, isFalse);
      expect(_command(editor.root, 'table-header-row').disabled, isFalse);
      expect(editor.root.querySelectorAll('table tr').length, 2);

      _command(editor.root, 'table-header-row').click();
      final table = iterateBlocksInDocumentOrder(editor.editorState.state)
          .firstWhere((block) => block.type == 'table');
      expect(
          getBlock(editor.editorState.state, table.id)!.attrs['headerRowCount'],
          1);
      expect(
          _command(editor.root, 'table-header-row')
              .getAttribute('aria-pressed'),
          'true');

      _command(editor.root, 'table-row-below').click();
      expect(editor.root.querySelectorAll('table tr').length, 3);

      _command(editor.root, 'table-delete-column').click();
      expect(editor.root.querySelectorAll('table td').length, 3);
      _command(editor.root, 'table-delete-row').click();
      expect(editor.root.querySelectorAll('table td').length, 2);

      _command(editor.root, 'table-delete').click();
      expect(editor.root.querySelector('table'), isNull);
      expect(editor.root.classList.contains('tw-editor--in-table'), isFalse);
    });

    test('drawing contextual ribbon inserts and formats Word text boxes', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Formas'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      _button(editor.root, 'tw-ribbon-tab-insert').click();
      _command(editor.root, 'text-box').click();
      final textBox = iterateBlocksInDocumentOrder(editor.editorState.state)
          .firstWhere((block) => block.type == 'text-box');
      final textBoxElement =
          editor.root.querySelector('[data-block-id="${textBox.id.value}"]')
              as web.HTMLElement;

      textBoxElement.click();
      expect(editor.root.classList.contains('tw-editor--in-drawing'), isTrue);
      expect(textBoxElement.hasAttribute('data-tw-drawing-selected'), isTrue);
      final drawingTab = _button(editor.root, 'tw-ribbon-tab-drawing');
      expect(drawingTab.getAttribute('aria-selected'), 'true');
      expect(
        editor.root
            .querySelector('[data-testid="tw-ribbon-panel-drawing"]')!
            .classList
            .contains('tw-editor__ribbon-panel--active'),
        isTrue,
      );

      _command(editor.root, 'drawing-align-center').click();
      expect(getBlock(editor.editorState.state, textBox.id)!.attrs['alignment'],
          DrawingAlignment.center.value);

      _command(editor.root, 'drawing-size').click();
      final width =
          editor.root.querySelector('[data-testid="tw-drawing-width"]')
              as web.HTMLInputElement;
      final height =
          editor.root.querySelector('[data-testid="tw-drawing-height"]')
              as web.HTMLInputElement;
      final outline =
          editor.root.querySelector('[data-testid="tw-drawing-outline-width"]')
              as web.HTMLInputElement;
      width.value = '220';
      height.value = '110';
      outline.value = '3';
      _button(editor.root, 'tw-drawing-size-apply').click();

      final resized = getBlock(editor.editorState.state, textBox.id)!;
      expect(resized.attrs['width'], 220.0);
      expect(resized.attrs['height'], 110.0);
      expect(resized.attrs['outlineWidth'], 3.0);
      expect(resized.attrs['alignment'], DrawingAlignment.center.value);

      _command(editor.root, 'drawing-new-line').click();
      expect(
        iterateBlocksInDocumentOrder(editor.editorState.state).any(
          (block) =>
              block.type == 'shape' && block.attrs['shapeKind'] == 'line',
        ),
        isTrue,
      );
    });

    test('image contextual ribbon selects, formats and describes an image', () {
      final container = _appendContainer();
      final editor = TaleweaverEditor.mount(
        container,
        options: const TaleweaverEditorOptions(initialText: 'Imagem'),
      );
      addTearDown(() {
        editor.destroy();
        container.remove();
      });

      expect(_command(editor.root, 'image-size').disabled, isTrue);
      editor.dispatch(const InsertImageAction(
        'https://example.test/diagram.png',
        width: 120,
        height: 80,
      ));
      final image = iterateBlocksInDocumentOrder(editor.editorState.state)
          .firstWhere((block) => block.type == 'image');
      final imageElement =
          editor.root.querySelector('[data-block-id="${image.id.value}"]')
              as web.HTMLElement;

      imageElement.click();
      expect(editor.root.classList.contains('tw-editor--in-image'), isTrue);
      expect(imageElement.hasAttribute('data-tw-image-selected'), isTrue);
      final imageTab = _button(editor.root, 'tw-ribbon-tab-image');
      expect(imageTab.getAttribute('aria-selected'), 'true');
      expect(
        editor.root
            .querySelector('[data-testid="tw-ribbon-panel-image"]')!
            .classList
            .contains('tw-editor__ribbon-panel--active'),
        isTrue,
      );

      _command(editor.root, 'image-align-right').click();
      expect(
          getBlock(editor.editorState.state, image.id)!.attrs['wrap'], 'right');
      expect(
        _command(editor.root, 'image-align-right').getAttribute('aria-pressed'),
        'true',
      );
      _command(editor.root, 'image-wrap-inline').click();
      expect(
          getBlock(editor.editorState.state, image.id)!
              .attrs
              .containsKey('wrap'),
          isFalse);

      _command(editor.root, 'image-size').click();
      final width = editor.root.querySelector('[data-testid="tw-image-width"]')
          as web.HTMLInputElement;
      final height =
          editor.root.querySelector('[data-testid="tw-image-height"]')
              as web.HTMLInputElement;
      width.value = '180';
      height.value = '90';
      _button(editor.root, 'tw-image-size-apply').click();
      final resized = getBlock(editor.editorState.state, image.id)!;
      expect(resized.attrs['width'], 180.0);
      expect(resized.attrs['height'], 90.0);

      _command(editor.root, 'image-alt').click();
      final alt =
          editor.root.querySelector('[data-testid="tw-image-alt-input"]')
              as web.HTMLInputElement;
      alt.value = 'Diagrama do fluxo editorial';
      _button(editor.root, 'tw-image-alt-apply').click();
      expect(getBlock(editor.editorState.state, image.id)!.attrs['alt'],
          'Diagrama do fluxo editorial');
      expect(
        (editor.root.querySelector('[data-block-id="${image.id.value}"]')
                as web.HTMLImageElement)
            .alt,
        'Diagrama do fluxo editorial',
      );
    });
  });
}

web.HTMLElement _appendContainer() {
  final container = web.document.createElement('div') as web.HTMLElement;
  container.setAttribute('data-test-container', '');
  web.document.body!.appendChild(container);
  return container;
}

web.HTMLButtonElement _button(web.HTMLElement root, String testId) {
  final element = root.querySelector('[data-testid="$testId"]');
  expect(element, isA<web.HTMLButtonElement>(),
      reason: 'Botão $testId ausente');
  return element! as web.HTMLButtonElement;
}

web.HTMLButtonElement _command(web.HTMLElement root, String command) {
  final element = root.querySelector('[data-command="$command"]');
  expect(element, isA<web.HTMLButtonElement>(),
      reason: 'Comando $command ausente');
  return element! as web.HTMLButtonElement;
}
