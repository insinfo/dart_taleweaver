@TestOn('browser')

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:taleweaver/taleweaver.dart';

void main() {
  test(
      'manual page break materializes the next physical page without a section',
      () async {
    final container = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '720px')
      ..style.setProperty('height', '620px');
    web.document.body!.appendChild(container);
    final editor = TaleweaverEditor.mount(
      container,
      options: const TaleweaverEditorOptions(
        initialText: 'Texto antes da quebra manual.',
        editorConfig: EditorConfig(
          pageConfig: PageConfig(
            width: 320,
            height: 240,
            margins: PageMargins(top: 24, right: 24, bottom: 24, left: 24),
          ),
        ),
      ),
    );
    addTearDown(() {
      editor.destroy();
      container.remove();
    });

    editor.dispatch(const PageBreakAction());
    editor.dispatch(const InsertTextAction('Texto depois da quebra manual.'));
    await Future<void>.delayed(const Duration(milliseconds: 750));

    final surface = editor.root
        .querySelector('[data-testid="tw-editor-surface"]') as web.HTMLElement;
    final target =
        surface.querySelector('[data-tw-manual-page-break]') as web.HTMLElement;
    final marker = surface.querySelector(
      '[data-tw-manual-page-break-decoration]',
    ) as web.HTMLElement;
    final targetPage = int.parse(marker.getAttribute('data-tw-target-page')!);
    final header = surface.querySelector(
      '.tw-editor__page-header[data-page-number="$targetPage"]',
    ) as web.HTMLElement;
    expect(targetPage, greaterThanOrEqualTo(2));
    expect(
      target.getBoundingClientRect().top,
      greaterThanOrEqualTo(header.getBoundingClientRect().bottom - 1),
    );
    expect(int.parse(surface.getAttribute('data-page-count')!),
        greaterThanOrEqualTo(targetPage));
    // It remains a page break, never a hidden section mutation.
    expect(surface.querySelectorAll('[data-tw-section]').length, 0);
  });

  test('sections own independent physical pages without cloning keyed content',
      () async {
    final container = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '720px')
      ..style.setProperty('height', '620px');
    web.document.body!.appendChild(container);
    final editor = TaleweaverEditor.mount(
      container,
      options: const TaleweaverEditorOptions(
        initialText: 'Primeira seção.',
        editorConfig: EditorConfig(
          pageConfig: PageConfig(
            width: 320,
            height: 240,
            margins: PageMargins(top: 24, right: 24, bottom: 24, left: 24),
          ),
        ),
      ),
    );
    addTearDown(() {
      editor.destroy();
      container.remove();
    });

    // Split the implicit root, then turn the two paragraphs into separate
    // sections. The second remains a normal model paragraph throughout.
    editor.dispatch(const SplitNodeAction());
    editor.dispatch(const SectionBreakAction());
    editor.dispatch(const InsertTextAction('Segunda seção.'));
    await Future<void>.delayed(const Duration(milliseconds: 750));

    final surface = editor.root
        .querySelector('[data-testid="tw-editor-surface"]') as web.HTMLElement;
    final sections = surface.querySelectorAll('[data-tw-section]');
    expect(sections.length, 2);
    final first = sections.item(0) as web.HTMLElement;
    final second = sections.item(1) as web.HTMLElement;
    expect(
        editor.root.classList.contains('tw-editor--sectioned-pages'), isTrue);
    expect(surface.getAttribute('data-tw-section-pages'), 'true');
    expect(
      surface
          .querySelectorAll('[data-tw-section-pagination-decoration]')
          .length,
      2,
    );
    // The old marker-only projection must not be mixed with the independent
    // section pager: each keyed section owns its own inert float chain.
    expect(
      surface.querySelectorAll('[data-tw-section-break-decoration]').length,
      0,
    );

    final firstHeader =
        first.querySelector('.tw-editor__page-header') as web.HTMLElement;
    final secondHeader =
        second.querySelector('.tw-editor__page-header') as web.HTMLElement;
    final firstPage = int.parse(firstHeader.getAttribute('data-page-number')!);
    final secondPage =
        int.parse(secondHeader.getAttribute('data-page-number')!);
    expect(secondPage, greaterThan(firstPage));
    final secondParagraph =
        second.querySelector('[data-block-id]') as web.HTMLElement;
    final textRange = web.document.createRange()
      ..selectNodeContents(secondParagraph);
    final firstTextRect = textRange.getClientRects().item(0)!;
    expect(
      firstTextRect.top,
      greaterThanOrEqualTo(secondHeader.getBoundingClientRect().bottom - 1),
      reason:
          'the second section text starts after its own generated page header',
    );
    expect(first.textContent, contains('Primeira seção.'));
    expect(second.textContent, contains('Segunda seção.'));

    // A document edit reconciles the model tree, briefly removes the inert
    // sibling and reattaches it. Both real section/paragraph elements retain
    // identity; no cloned editable section becomes a selection target.
    final secondParagraphId = secondParagraph.getAttribute('data-block-id');
    editor.dispatch(const InsertTextAction(' atualizada'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final nextSections = surface.querySelectorAll('[data-tw-section]');
    final nextSecond = nextSections.item(1) as web.HTMLElement;
    final nextParagraph =
        nextSecond.querySelector('[data-block-id]') as web.HTMLElement;
    expect(identical(nextSecond, second), isTrue);
    expect(identical(nextParagraph, secondParagraph), isTrue);
    expect(nextParagraph.getAttribute('data-block-id'), secondParagraphId);
    expect(nextParagraph.textContent, contains('Segunda seção. atualizada'));
    expect(
      surface
          .querySelectorAll('[data-tw-section-pagination-decoration]')
          .length,
      2,
    );
  });

  test('a section keeps its own paper geometry when another section is active',
      () async {
    final container = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '720px')
      ..style.setProperty('height', '620px');
    web.document.body!.appendChild(container);
    final editor = TaleweaverEditor.mount(
      container,
      options: TaleweaverEditorOptions(
        initialText: 'Primeira seção em retrato.',
        editorConfig: const EditorConfig(
          pageConfig: PageConfig(
            width: 320,
            height: 240,
            margins: PageMargins(top: 24, right: 24, bottom: 24, left: 24),
          ),
        ),
      ),
    );
    addTearDown(() {
      editor.destroy();
      container.remove();
    });

    editor.dispatch(const SplitNodeAction());
    editor.dispatch(const SectionBreakAction());
    editor.dispatch(const InsertTextAction('Segunda seção em paisagem.'));
    // The selection is in section two, so page setup changes only that
    // section. Its sibling must retain the original 320×240pt geometry.
    editor.dispatch(const SetActivePageSizeAction(480, 300));
    await Future<void>.delayed(const Duration(milliseconds: 950));

    final surface = editor.root
        .querySelector('[data-testid="tw-editor-surface"]') as web.HTMLElement;
    final sections = surface.querySelectorAll('[data-tw-section]');
    expect(sections.length, 2);
    final first = sections.item(0) as web.HTMLElement;
    final second = sections.item(1) as web.HTMLElement;
    expect(first.getAttribute('data-tw-section-page-width'), '426.67px');
    expect(first.getAttribute('data-tw-section-page-height'), '320.00px');
    expect(second.getAttribute('data-tw-section-page-width'), '640.00px');
    expect(second.getAttribute('data-tw-section-page-height'), '400.00px');

    final firstHeader =
        first.querySelector('.tw-editor__page-header') as web.HTMLElement;
    final secondHeader =
        second.querySelector('.tw-editor__page-header') as web.HTMLElement;
    expect(
      int.parse(secondHeader.getAttribute('data-page-number')!),
      greaterThan(int.parse(firstHeader.getAttribute('data-page-number')!)),
    );

    final firstParagraph =
        first.querySelector('[data-block-id]') as web.HTMLElement;
    final firstId = firstParagraph.getAttribute('data-block-id')!;
    editor.dispatch(SetSelectionAction(Selection(
      anchor: Position(blockId: BlockId(firstId), offset: 0),
      focus: Position(blockId: BlockId(firstId), offset: 0),
    )));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Moving the caret only changes ruler/page-setup context. It must never
    // resize the landscape section or overwrite its saved geometry.
    expect(second.getAttribute('data-tw-section-page-width'), '640.00px');
    expect(second.getAttribute('data-tw-section-page-height'), '400.00px');
  });

  test(
      'repeated templates stay with their owning section after selection moves',
      () async {
    final container = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '720px')
      ..style.setProperty('height', '620px');
    web.document.body!.appendChild(container);
    final firstText = List<String>.filled(
      600,
      'Conteúdo da primeira seção que precisa de várias páginas.',
    ).join(' ');
    final editor = TaleweaverEditor.mount(
      container,
      options: const TaleweaverEditorOptions(initialText: ''),
    );
    addTearDown(() {
      editor.destroy();
      container.remove();
    });

    editor.dispatch(InsertTextAction(firstText));
    editor.dispatch(const SplitNodeAction());
    editor.dispatch(const SectionBreakAction());
    editor.dispatch(const InsertTextAction('Segunda seção.'));
    final surface = editor.root
        .querySelector('[data-testid="tw-editor-surface"]') as web.HTMLElement;
    final sections = surface.querySelectorAll('[data-tw-section]');
    expect(sections.length, 2);
    final firstParagraph = (sections.item(0) as web.HTMLElement)
        .querySelector('[data-block-id]') as web.HTMLElement;
    final secondParagraph = (sections.item(1) as web.HTMLElement)
        .querySelector('[data-block-id]') as web.HTMLElement;

    void selectMain(web.HTMLElement paragraph) {
      final id = paragraph.getAttribute('data-block-id')!;
      editor.dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: BlockId(id), offset: 0),
        focus: Position(blockId: BlockId(id), offset: 0),
      )));
    }

    selectMain(firstParagraph);
    (editor.root.querySelector('[data-command="header"]')
            as web.HTMLButtonElement)
        .click();
    editor.dispatch(const InsertTextAction('Cabeçalho da primeira'));

    selectMain(secondParagraph);
    (editor.root.querySelector('[data-command="header"]')
            as web.HTMLButtonElement)
        .click();
    editor.dispatch(const InsertTextAction('Cabeçalho da segunda'));
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final firstSection = sections.item(0) as web.HTMLElement;
    final secondSection = sections.item(1) as web.HTMLElement;
    final firstRepeatedHeader = firstSection.querySelector(
      '.tw-editor__page-header[data-page-number="2"]',
    );
    expect(firstRepeatedHeader?.textContent, contains('Cabeçalho da primeira'));
    final secondHeader = secondSection.querySelector('.tw-editor__page-header');
    expect(secondHeader?.textContent, contains('Cabeçalho da segunda'));
    expect(secondHeader?.querySelector('[data-block-id]'), isNull);

    // A selection-only action must not make page two inherit the template of
    // the selected section. Its snapshot is tied to its original profile.
    selectMain(firstParagraph);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final stableFirstRepeatedHeader = firstSection.querySelector(
      '.tw-editor__page-header[data-page-number="2"]',
    );
    final stableSecondHeader =
        secondSection.querySelector('.tw-editor__page-header');
    expect(stableFirstRepeatedHeader?.textContent,
        contains('Cabeçalho da primeira'));
    expect(stableSecondHeader?.textContent, contains('Cabeçalho da segunda'));
    expect(stableSecondHeader?.querySelector('[data-block-id]'), isNull);
  });

  test('template editing is overlaid on the selected section page', () async {
    final container = web.document.createElement('div') as web.HTMLElement
      ..style.setProperty('width', '720px')
      ..style.setProperty('height', '620px');
    web.document.body!.appendChild(container);
    final editor = TaleweaverEditor.mount(
      container,
      options: const TaleweaverEditorOptions(initialText: 'Primeira seção.'),
    );
    addTearDown(() {
      editor.destroy();
      container.remove();
    });

    editor.dispatch(const SplitNodeAction());
    editor.dispatch(const SectionBreakAction());
    editor.dispatch(const InsertTextAction('Segunda seção.'));
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final surface = editor.root
        .querySelector('[data-testid="tw-editor-surface"]') as web.HTMLElement;
    final sections = surface.querySelectorAll('[data-tw-section]');
    final second = sections.item(1) as web.HTMLElement;
    final paragraph =
        second.querySelector('[data-block-id]') as web.HTMLElement;
    final id = paragraph.getAttribute('data-block-id')!;
    editor.dispatch(SetSelectionAction(Selection(
      anchor: Position(blockId: BlockId(id), offset: 0),
      focus: Position(blockId: BlockId(id), offset: 0),
    )));
    (editor.root.querySelector('[data-command="header"]')
            as web.HTMLButtonElement)
        .click();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final snapshot =
        second.querySelector('.tw-editor__page-header') as web.HTMLElement;
    final editable = editor.root.querySelector('.tw-editor__template--header')
        as web.HTMLElement;
    final snapshotRect = snapshot.getBoundingClientRect();
    final editableRect = editable.getBoundingClientRect();
    expect(snapshot.hasAttribute('data-tw-canonical-template'), isTrue);
    expect(editableRect.top, greaterThanOrEqualTo(snapshotRect.top - 1));
    expect(editableRect.top, lessThan(snapshotRect.bottom + 1));
    expect(
        editable.querySelector('[data-testid="tw-header-surface"]'), isNotNull);
  });
}
