part of taleweaver_word_editor;

extension _TaleweaverEditorRibbonPanels on TaleweaverEditor {
  web.HTMLElement _buildTitleBar() {
    final chrome = WordEditorTitleBar(
      document: _document,
      initialTitle: options.documentTitle,
      onTitleChanged: setDocumentTitle,
      onUndo: () => dispatch(const UndoAction()),
      onRedo: () => dispatch(const RedoAction()),
      buttonBuilder: (id, label, action, {wide = false}) =>
          _commandCallback(id, label, action, wide: wide),
    );
    _titleInput = chrome.titleInput;
    return chrome.element;
  }

  web.HTMLElement _buildTabs() {
    return _ensureRibbonMarkup().tabs;
  }

  web.HTMLElement _buildRibbon() {
    return _ensureRibbonMarkup().ribbon;
  }

  WordEditorRibbonMarkup _ensureRibbonMarkup() {
    final existing = _ribbonMarkup;
    if (existing != null) return existing;
    final panels = <String, web.HTMLElement>{
      'file': _filePanel(),
      'home': _homePanel(),
      'insert': _insertPanel(),
      'layout': _layoutPanel(),
      'review': _reviewPanel(),
      'view': _viewPanel(),
      'table': _tablePanel(),
      'image': _imagePanel(),
      'drawing': _drawingPanel(),
    };
    final ribbon = WordEditorRibbon(
      document: _document,
      initialTab: _activeTab,
      onTabActivated: (id) => _activeTab = id,
      tabs: const [
        WordEditorRibbonTab('file', 'Arquivo'),
        WordEditorRibbonTab('home', 'Página Inicial'),
        WordEditorRibbonTab('insert', 'Inserir'),
        WordEditorRibbonTab('layout', 'Layout'),
        WordEditorRibbonTab('review', 'Revisão'),
        WordEditorRibbonTab('view', 'Exibir'),
        WordEditorRibbonTab('table', 'Layout da Tabela', contextual: true),
        WordEditorRibbonTab('image', 'Formato da Imagem', contextual: true),
        WordEditorRibbonTab('drawing', 'Formato da Forma', contextual: true),
      ],
      panels: panels,
    );
    _ribbonChrome = ribbon;
    final markup = ribbon.build();
    _ribbonMarkup = markup;
    return markup;
  }

  web.HTMLElement _filePanel() {
    final panel = _panel('file');
    panel
      ..appendChild(_group('Arquivo', [
        _commandCallback('open-docx', 'Abrir DOCX', _requestOpenDocx,
            large: true),
        _commandCallback('open-delta', 'Abrir Delta', _requestOpenDelta,
            large: true),
        _commandCallback('save', 'Salvar', () {
          options.onSave?.call(editorState);
          _setSaveState('Salvo');
        }, large: true),
        _commandCallback('export', 'Exportar', () {
          // The lossless built-in transport is binary.  The host application
          // owns the download/storage UI and can choose another serializer in
          // its callback, but the ribbon must not advertise a lossy JSON path
          // as the default for documents containing tables or templates.
          options.onExport?.call(editorState, 'taleweaver-binary');
        }, large: true),
        _commandCallback('export-delta', 'Exportar Delta', _requestExportDelta,
            large: true),
      ]))
      ..appendChild(_messageGroup('Integração',
          'Use os callbacks de arquivo para conectar DOCX, Delta e o armazenamento do aplicativo.'));
    return panel;
  }

  web.HTMLElement _homePanel() {
    final panel = _panel('home', active: true);
    final cutRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_commandCallback('cut', 'Recortar', _cutSelection));
    final copyRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_commandCallback('copy', 'Copiar', _copySelection));
    final clipboardRows = _element('div', 'tw-editor__ribbon-rows')
      ..appendChild(cutRow)
      ..appendChild(copyRow);
    final fontRows = _element('div', 'tw-editor__ribbon-rows');
    final firstFontRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_fontFamilySelect())
      ..appendChild(_fontSizeSelect())
      ..appendChild(_commandCallback(
          'font-grow', 'Aumentar fonte', () => _adjustFontSize(1)))
      ..appendChild(_commandCallback(
          'font-shrink', 'Diminuir fonte', () => _adjustFontSize(-1)));
    final secondFontRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_command('bold', 'Negrito', const ToggleStyleAction('bold'),
          text: true))
      ..appendChild(_command(
          'italic', 'Itálico', const ToggleStyleAction('italic'),
          text: true))
      ..appendChild(_command(
          'underline', 'Sublinhado', const ToggleStyleAction('underline'),
          underline: true))
      ..appendChild(_command(
          'strikethrough', 'Tachado', const ToggleStyleAction('strikethrough'),
          strike: true))
      ..appendChild(_colorInput(
          'text-color', 'Cor da fonte', (color) => SetTextColorAction(color)))
      ..appendChild(_colorInput(
          'highlight', 'Realce', (color) => SetHighlightAction(color)))
      ..appendChild(_command(
          'clear-format', 'Limpar formatação', const ClearFormattingAction()));
    fontRows
      ..appendChild(firstFontRow)
      ..appendChild(secondFontRow);

    final paragraphFirstRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_command(
          'bullets', 'Marcadores', const ToggleListAction('unordered')))
      ..appendChild(
          _command('numbering', 'Numeração', const ToggleListAction('ordered')))
      ..appendChild(
          _command('outdent', 'Diminuir recuo', const OutdentAction()))
      ..appendChild(_command('indent', 'Aumentar recuo', const IndentAction()))
      ..appendChild(_commandCallback('line-spacing', 'Espaçamento 1,5',
          () => dispatch(const SetLineSpacingAction(1.5))))
      ..appendChild(_commandCallback('line-spacing-single', 'Espaçamento 1,0',
          () => dispatch(const SetLineSpacingAction(1))))
      ..appendChild(_commandCallback('line-spacing-double', 'Espaçamento 2,0',
          () => dispatch(const SetLineSpacingAction(2))));
    final paragraphSecondRow = _element('div', 'tw-editor__ribbon-row')
      ..appendChild(_command(
          'align-left', 'Alinhar à esquerda', const SetTextAlignAction('left')))
      ..appendChild(_command(
          'align-center', 'Centralizar', const SetTextAlignAction('center')))
      ..appendChild(_command('align-right', 'Alinhar à direita',
          const SetTextAlignAction('right')))
      ..appendChild(_command(
          'align-justify', 'Justificar', const SetTextAlignAction('justify')));
    final paragraphRows = _element('div', 'tw-editor__ribbon-rows')
      ..appendChild(paragraphFirstRow)
      ..appendChild(paragraphSecondRow);

    panel
      ..appendChild(_group(
          'Área de Transferência',
          [
            _commandCallback('paste', 'Colar', focus, large: true),
            clipboardRows,
          ],
          modifier: 'clipboard'))
      ..appendChild(_group('Fonte', [fontRows], modifier: 'font'))
      ..appendChild(_group('Parágrafo', [paragraphRows], modifier: 'paragraph'))
      ..appendChild(_group('Estilos', [_styleGallery()], modifier: 'styles'))
      ..appendChild(_group('Edição', [
        _commandCallback('find', 'Localizar e substituir', _openFindDialog,
            large: true),
      ]));
    return panel;
  }

  web.HTMLElement _insertPanel() {
    final panel = _panel('insert');
    panel
      ..appendChild(_group('Páginas', [
        _command('page-break', 'Quebra de página', const PageBreakAction(),
            large: true),
        _command('section-break', 'Quebra de seção', const SectionBreakAction(),
            large: true),
        _command('horizontal-line', 'Linha horizontal',
            const InsertHorizontalLineAction(),
            large: true),
      ]))
      ..appendChild(_group('Tabela', [
        _command('table-2x2', 'Tabela 2×2', const InsertTableAction(2, 2),
            large: true),
        _command('table-3x3', 'Tabela 3×3', const InsertTableAction(3, 3),
            large: true),
      ]))
      ..appendChild(_group('Ilustrações', [
        _commandCallback(
            'image', 'Inserir imagem do computador', _insertImageFromFile,
            large: true),
        _command('drawing-new-text-box', 'Caixa de texto',
            const InsertTextBoxAction(text: 'Texto'),
            large: true),
        _command('drawing-new-rectangle', 'Retângulo',
            const InsertShapeAction(DrawingShapeKind.rectangle, text: 'Texto'),
            large: true),
        _command('drawing-new-ellipse', 'Elipse',
            const InsertShapeAction(DrawingShapeKind.ellipse, text: 'Texto'),
            large: true),
        _command('drawing-new-line', 'Linha',
            const InsertShapeAction(DrawingShapeKind.line),
            large: true),
      ]))
      ..appendChild(_group('Links', [
        _commandCallback('link', 'Inserir ou editar link', _openLinkDialog,
            large: true),
      ]))
      ..appendChild(_group('Referências', [
        _command('toc', 'Sumário', const InsertTableOfContentsAction(),
            large: true),
        _command('footnote', 'Nota de rodapé', const InsertFootnoteAction(),
            large: true),
      ]))
      ..appendChild(_group('Cabeçalho e Rodapé', [
        _command('header', 'Cabeçalho', const InsertHeaderAction(),
            large: true),
        _command('footer', 'Rodapé', const InsertFooterAction(), large: true),
        _command('page-number', 'Número', const InsertPageNumberAction(),
            large: true),
      ]));
    return panel;
  }

  web.HTMLElement _layoutPanel() {
    final panel = _panel('layout');
    panel
      ..appendChild(_group('Configuração de página', [
        _commandCallback('margins', 'Margens', _openPageMarginsDialog,
            large: true),
        _commandCallback('page-size', 'Tamanho', _openPageSizeDialog,
            large: true),
        _commandCallback('orientation', 'Orientação', _toggleSectionOrientation,
            large: true),
        _command('columns-one', 'Uma coluna', const SetSectionColumnsAction(1),
            large: true),
        _command(
            'columns-two', 'Duas colunas', const SetSectionColumnsAction(2),
            large: true),
      ]))
      ..appendChild(_messageGroup('Régua',
          'Arraste margens e recuos; clique na régua para criar tabulações.'));
    return panel;
  }

  web.HTMLElement _reviewPanel() {
    final panel = _panel('review');
    panel
      ..appendChild(_group('Alterações', [
        _command(
            'accept-all', 'Aceitar tudo', const AcceptAllSuggestionsAction(),
            large: true),
        _command(
            'reject-all', 'Rejeitar tudo', const RejectAllSuggestionsAction(),
            large: true),
      ]))
      ..appendChild(_messageGroup(
          'Revisão',
          options.editorConfig.suggestingAuthor == null
              ? 'Ative suggestingAuthor no EditorConfig para registrar alterações.'
              : 'Alterações rastreadas por ${options.editorConfig.suggestingAuthor}.'));
    return panel;
  }

  web.HTMLElement _viewPanel() {
    final panel = _panel('view');
    panel
      ..appendChild(_group('Exibição', [
        _commandCallback('view-paginated', 'Layout de impressão',
            () => setDocumentView(TaleweaverDocumentView.paginated),
            large: true),
        _commandCallback('view-continuous', 'Layout web',
            () => setDocumentView(TaleweaverDocumentView.continuous),
            large: true),
        _commandCallback('rulers', 'Régua', () {
          final isHidden = root.classList.contains('tw-editor--no-rulers');
          setRulersVisible(isHidden);
        }, large: true),
      ]))
      ..appendChild(_group('Modo', [
        _commandCallback('viewer', 'Somente leitura',
            () => setMode(TaleweaverEditorMode.viewer),
            large: true),
        _commandCallback(
            'editor', 'Editar', () => setMode(TaleweaverEditorMode.editor),
            large: true),
      ]));
    return panel;
  }

  web.HTMLElement _tablePanel() {
    final panel = _panel('table');
    panel
      ..appendChild(_group('Linhas e colunas', [
        _command('table-row-above', 'Inserir linha acima',
            const InsertTableRowAction('above'),
            large: true),
        _command('table-row-below', 'Inserir linha abaixo',
            const InsertTableRowAction('below'),
            large: true),
        _command('table-column-left', 'Inserir coluna à esquerda',
            const InsertTableColumnAction('left'),
            large: true),
        _command('table-column-right', 'Inserir coluna à direita',
            const InsertTableColumnAction('right'),
            large: true),
      ]))
      ..appendChild(_group('Células', [
        _command('table-split-cell', 'Dividir célula mesclada',
            const SplitCellAction(),
            large: true),
      ]))
      ..appendChild(_group('Excluir', [
        _command(
            'table-delete-row', 'Excluir linha', const DeleteTableRowAction(),
            large: true),
        _command('table-delete-column', 'Excluir coluna',
            const DeleteTableColumnAction(),
            large: true),
        _command('table-delete', 'Excluir tabela', const DeleteTableAction(),
            large: true),
      ]))
      ..appendChild(_group('Opções', [
        _commandCallback('table-header-row', 'Repetir linha de cabeçalho',
            _toggleTableHeaderRow,
            large: true),
      ]))
      ..appendChild(_messageGroup('Tabela',
          'Os comandos acompanham a célula atual e preservam células mescladas.'));
    return panel;
  }

  web.HTMLElement _imagePanel() {
    final panel = _panel('image');
    panel
      ..appendChild(_group('Posição e quebra', [
        _commandCallback('image-align-left', 'Alinhar à esquerda',
            () => _setActiveImageWrap('left'),
            large: true),
        _commandCallback('image-align-right', 'Alinhar à direita',
            () => _setActiveImageWrap('right'),
            large: true),
        _commandCallback('image-wrap-inline', 'Em linha com o texto',
            () => _setActiveImageWrap('break'),
            large: true),
      ]))
      ..appendChild(_group('Tamanho', [
        _commandCallback('image-size', 'Tamanho', _openImageSizeDialog,
            large: true),
      ]))
      ..appendChild(_group('Acessibilidade', [
        _commandCallback('image-alt', 'Texto alternativo', _openImageAltDialog,
            large: true),
      ]))
      ..appendChild(_messageGroup('Imagem',
          'Ajuste a posição, a quebra de texto, as dimensões e a descrição da imagem selecionada.'));
    return panel;
  }

  /// Contextual mini-Ribbon for the selected text box, rectangle, ellipse or
  /// line. The controls dispatch model actions; they never mutate inline DOM
  /// styles directly, so undo/redo and non-browser rendering remain correct.
  web.HTMLElement _drawingPanel() {
    final panel = _panel('drawing');
    panel
      ..appendChild(_group('Posição', [
        _commandCallback('drawing-align-left', 'Alinhar à esquerda',
            () => _updateActiveDrawing(alignment: DrawingAlignment.inlineStart),
            large: true),
        _commandCallback('drawing-align-center', 'Centralizar',
            () => _updateActiveDrawing(alignment: DrawingAlignment.center),
            large: true),
        _commandCallback('drawing-align-right', 'Alinhar à direita',
            () => _updateActiveDrawing(alignment: DrawingAlignment.inlineEnd),
            large: true),
      ]))
      ..appendChild(_group('Tamanho', [
        _commandCallback(
            'drawing-size', 'Tamanho e contorno', _openDrawingSizeDialog,
            large: true),
      ]))
      ..appendChild(_group('Estilo', [
        _drawingColorInput('drawing-fill', 'Preenchimento da forma', (color) {
          _updateActiveDrawing(fill: color);
        }),
        _drawingColorInput('drawing-outline', 'Contorno da forma', (color) {
          _updateActiveDrawing(outline: color);
        }),
      ]))
      ..appendChild(_group('Inserir', [
        _command('text-box', 'Caixa de texto',
            const InsertTextBoxAction(text: 'Texto'),
            large: true),
        _command('shape-rectangle', 'Retângulo',
            const InsertShapeAction(DrawingShapeKind.rectangle, text: 'Texto'),
            large: true),
        _command('shape-ellipse', 'Elipse',
            const InsertShapeAction(DrawingShapeKind.ellipse, text: 'Texto'),
            large: true),
        _command('shape-line', 'Linha',
            const InsertShapeAction(DrawingShapeKind.line),
            large: true),
      ]))
      ..appendChild(_messageGroup('Forma',
          'Ajuste alinhamento, tamanho, preenchimento e contorno da forma selecionada.'));
    return panel;
  }

  web.HTMLElement _buildStatusBar() {
    final chrome = WordEditorStatusBar(
      document: _document,
      onZoomChanged: setZoom,
      onZoomOut: () => setZoom(_zoom - .1),
      onZoomIn: () => setZoom(_zoom + .1),
      buttonBuilder: (id, label, action, {wide = false}) =>
          _commandCallback(id, label, action, wide: wide),
      initialZoom: _zoom,
    );
    _statusState = chrome.state;
    _statusPage = chrome.page;
    _statusWords = chrome.words;
    _statusMode = chrome.mode;
    _zoomInput = chrome.zoomInput;
    _zoomLabel = chrome.zoomLabel;
    return chrome.element;
  }

  web.HTMLElement _panel(String id, {bool active = false}) {
    final panel = _element('div',
        'tw-editor__ribbon-panel${active ? ' tw-editor__ribbon-panel--active' : ''}')
      ..setAttribute('role', 'tabpanel')
      ..setAttribute('data-ribbon-panel', id)
      ..setAttribute('data-testid', 'tw-ribbon-panel-$id');
    return panel;
  }

  web.HTMLElement _group(String label, List<web.HTMLElement> children,
      {String? modifier}) {
    final group = _element('div',
        'tw-editor__group${modifier == null ? '' : ' tw-editor__group--$modifier'}')
      ..setAttribute('data-label', label);
    for (final child in children) {
      group.appendChild(child);
    }
    return group;
  }

  web.HTMLElement _messageGroup(String heading, String body) =>
      _element('div', 'tw-editor__group-message')
        ..appendChild(_element('strong', null, heading))
        ..appendChild(_element('span', null, body));

  TaleweaverEditorIcon _iconForCommand(String id) => switch (id) {
        'bold' => TaleweaverEditorIcon.bold,
        'italic' => TaleweaverEditorIcon.italic,
        'underline' || 'strikethrough' => TaleweaverEditorIcon.underline,
        'undo' => TaleweaverEditorIcon.undo,
        'redo' => TaleweaverEditorIcon.redo,
        'cut' ||
        'clear-format' ||
        'reject-all' ||
        'table-delete-row' ||
        'table-delete-column' ||
        'table-delete' =>
          TaleweaverEditorIcon.cut,
        'copy' ||
        'export' ||
        'export-delta' ||
        'link' ||
        'accept-all' =>
          TaleweaverEditorIcon.copy,
        'paste' => TaleweaverEditorIcon.paste,
        'align-left' ||
        'outdent' ||
        'image-align-left' ||
        'drawing-align-left' =>
          TaleweaverEditorIcon.alignLeft,
        'align-center' ||
        'drawing-align-center' =>
          TaleweaverEditorIcon.alignCenter,
        'align-right' ||
        'indent' ||
        'image-align-right' ||
        'drawing-align-right' =>
          TaleweaverEditorIcon.alignRight,
        'align-justify' ||
        'line-spacing' ||
        'line-spacing-single' ||
        'line-spacing-double' ||
        'image-wrap-inline' =>
          TaleweaverEditorIcon.alignJustify,
        'bullets' ||
        'toc' ||
        'view-continuous' =>
          TaleweaverEditorIcon.listBullets,
        'numbering' => TaleweaverEditorIcon.listNumbered,
        'table-2x2' ||
        'table-3x3' ||
        'table-row-above' ||
        'table-row-below' ||
        'table-column-left' ||
        'table-column-right' ||
        'table-split-cell' ||
        'table-header-row' ||
        'columns-one' ||
        'columns-two' =>
          TaleweaverEditorIcon.table,
        'image' => TaleweaverEditorIcon.image,
        'text-box' || 'drawing-new-text-box' => TaleweaverEditorIcon.textBox,
        'shape-rectangle' ||
        'drawing-new-rectangle' ||
        'drawing-size' =>
          TaleweaverEditorIcon.rectangle,
        'shape-ellipse' ||
        'drawing-new-ellipse' =>
          TaleweaverEditorIcon.ellipse,
        'shape-line' || 'drawing-new-line' => TaleweaverEditorIcon.line,
        'font-grow' ||
        'font-shrink' ||
        'footnote' ||
        'header' ||
        'footer' ||
        'page-number' ||
        'image-alt' ||
        'viewer' ||
        'editor' =>
          TaleweaverEditorIcon.textBox,
        'open-docx' || 'open-delta' => TaleweaverEditorIcon.paste,
        'page-break' ||
        'section-break' ||
        'margins' ||
        'page-size' ||
        'orientation' ||
        'view-paginated' ||
        'image-size' =>
          TaleweaverEditorIcon.rectangle,
        'horizontal-line' ||
        'rulers' ||
        'zoom-out' ||
        'zoom-in' =>
          TaleweaverEditorIcon.line,
        'save' => TaleweaverEditorIcon.save,
        'find' => TaleweaverEditorIcon.find,
        _ => TaleweaverEditorIcon.rectangle,
      };

  web.HTMLButtonElement _command(String id, String label, EditorAction action,
          {bool large = false,
          bool text = false,
          bool underline = false,
          bool strike = false}) =>
      _commandCallback(id, label, () => dispatch(action),
          large: large, text: text, underline: underline, strike: strike);

  web.HTMLButtonElement _commandCallback(
    String id,
    String label,
    void Function() callback, {
    bool large = false,
    bool wide = false,
    bool text = false,
    bool underline = false,
    bool strike = false,
  }) {
    final button = _document.createElement('button') as web.HTMLButtonElement
      ..className = 'tw-editor__command'
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..setAttribute('data-command', id)
      ..setAttribute('data-testid', 'tw-command-$id');
    if (large) button.classList.add('tw-editor__command--large');
    if (wide) button.classList.add('tw-editor__command--wide');
    if (text) button.classList.add('tw-editor__command--text');
    if (underline) button.classList.add('tw-editor__command--underline');
    if (strike) button.classList.add('tw-editor__command--strike');
    final icon = _element(
      'span',
      'tw-editor__icon',
      options.assets.iconResolver(_iconForCommand(id)),
    )
      ..setAttribute('aria-hidden', 'true')
      ..setAttribute('data-tw-icon', _iconForCommand(id).name);
    button.appendChild(icon);
    if (large) button.appendChild(_element('span', null, label));
    button.addEventListener(
        'pointerdown',
        ((web.Event event) {
          // Preserve the model/DOM selection while a ribbon command is chosen.
          event.preventDefault();
        }).toJS);
    button.addEventListener(
        'click',
        ((web.Event _) {
          if (_mode == TaleweaverEditorMode.viewer &&
              !{
                'editor',
                'viewer',
                'view-paginated',
                'view-continuous',
                'rulers',
                'copy',
                'zoom-in',
                'zoom-out'
              }.contains(id)) {
            return;
          }
          _restoreRibbonSelection();
          callback();
        }).toJS);
    _commands[id] = button;
    return button;
  }

  web.HTMLElement _fontFamilySelect() {
    final wrapper = _element('div', 'tw-editor__font-select');
    _fontFamily = _document.createElement('select') as web.HTMLSelectElement
      ..setAttribute('aria-label', 'Fonte');
    for (final family in const [
      'Calibri',
      'Arial',
      'Times New Roman',
      'Georgia',
      'Courier New',
    ]) {
      _fontFamily!.appendChild(_document.createElement('option')
        ..setAttribute('value', family)
        ..textContent = family);
    }
    _fontFamily!.addEventListener(
        'change',
        ((web.Event _) {
          if (_mode == TaleweaverEditorMode.editor) {
            _restoreRibbonSelection();
            dispatch(SetFontFamilyAction(_fontFamily!.value));
          }
        }).toJS);
    wrapper.appendChild(_fontFamily!);
    return wrapper;
  }

  web.HTMLElement _fontSizeSelect() {
    final wrapper =
        _element('div', 'tw-editor__font-select tw-editor__font-select--size');
    _fontSize = _document.createElement('select') as web.HTMLSelectElement
      ..setAttribute('aria-label', 'Tamanho da fonte');
    for (final size in const [
      '9',
      '10',
      '11',
      '12',
      '14',
      '16',
      '18',
      '20',
      '24',
      '28',
      '32'
    ]) {
      _fontSize!.appendChild(_document.createElement('option')
        ..setAttribute('value', size)
        ..textContent = size);
    }
    _fontSize!.value = '12';
    _fontSize!.addEventListener(
        'change',
        ((web.Event _) {
          final size = double.tryParse(_fontSize!.value);
          if (_mode == TaleweaverEditorMode.editor && size != null) {
            _restoreRibbonSelection();
            dispatch(SetFontSizeAction(size));
          }
        }).toJS);
    wrapper.appendChild(_fontSize!);
    return wrapper;
  }

  web.HTMLElement _colorInput(
      String id, String tooltip, EditorAction Function(String color) action) {
    final input = _document.createElement('input') as web.HTMLInputElement
      ..className = 'tw-editor__color-command'
      ..type = 'color'
      ..value = id == 'highlight' ? '#fff59d' : '#202124'
      ..setAttribute('aria-label', tooltip)
      ..setAttribute('title', tooltip)
      ..setAttribute('data-testid', 'tw-command-$id');
    input.addEventListener(
        'change',
        ((web.Event _) {
          if (_mode == TaleweaverEditorMode.editor) {
            _restoreRibbonSelection();
            dispatch(action(input.value));
          }
        }).toJS);
    return input;
  }

  web.HTMLElement _drawingColorInput(
    String id,
    String tooltip,
    void Function(String color) onChanged,
  ) {
    final input = _document.createElement('input') as web.HTMLInputElement
      ..className = 'tw-editor__color-command'
      ..type = 'color'
      ..value = id == 'drawing-fill' ? '#d9eaf7' : '#1f4e79'
      ..setAttribute('aria-label', tooltip)
      ..setAttribute('title', tooltip)
      ..setAttribute('data-testid', 'tw-command-$id');
    input.addEventListener(
        'change',
        ((web.Event _) {
          if (_mode == TaleweaverEditorMode.editor) {
            _restoreRibbonSelection();
            onChanged(input.value);
          }
        }).toJS);
    return input;
  }

  web.HTMLElement _styleGallery() {
    final gallery = _element('div', 'tw-editor__style-gallery');
    final styles =
        <({String id, String label, String description, int? level})>[
      (
        id: 'paragraph',
        label: 'Normal',
        description: 'Texto normal',
        level: null
      ),
      for (final style in options.headingStyles)
        (
          id: style.id,
          label: style.label,
          description: style.description,
          level: style.level,
        ),
    ];
    for (final style in styles) {
      final button = _document.createElement('button') as web.HTMLButtonElement
        ..className = 'tw-editor__style'
        ..type = 'button'
        ..setAttribute('data-testid', 'tw-style-${style.id}')
        ..setAttribute('data-tw-style-level', '${style.level ?? 0}')
        ..setAttribute('aria-pressed', 'false')
        ..appendChild(_element('strong', null, style.label))
        ..appendChild(_element('small', null, style.description));
      button.addEventListener(
          'pointerdown', ((web.Event e) => e.preventDefault()).toJS);
      button.addEventListener(
          'click',
          ((web.Event _) {
            if (_mode == TaleweaverEditorMode.editor) {
              _restoreRibbonSelection();
              final level = style.level;
              if (level == null) {
                dispatch(const SetBlockTypeAction('paragraph'));
              } else {
                dispatch(SetHeadingLevelAction(level));
              }
            }
          }).toJS);
      gallery.appendChild(button);
    }
    return gallery;
  }
}
