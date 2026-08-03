part of taleweaver_word_editor;

extension _TaleweaverEditorDialogs on TaleweaverEditor {
  void _openPageMarginsDialog() {
    if (!_pageSetupCanEdit) return;
    _closeDialog();
    final page = _pageConfigForState(editorState);
    const pointsPerCentimetre = 72 / 2.54;
    String centimetres(double points) =>
        (points / pointsPerCentimetre).toStringAsFixed(2);
    web.HTMLInputElement field(String label, double value, String id) =>
        _document.createElement('input') as web.HTMLInputElement
          ..type = 'number'
          ..min = '0'
          ..step = '.01'
          ..value = centimetres(value)
          ..setAttribute('aria-label', label)
          ..setAttribute('data-testid', id);

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-page-setup-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-page-setup-dialog-title')
      ..setAttribute('data-testid', 'tw-page-setup-dialog');
    final heading = _element('h2', null, 'Margens personalizadas')
      ..id = 'tw-page-setup-dialog-title';
    final hint = _element('p', null,
        'As medidas são em centímetros e acompanham a seção ativa. A alteração entra em desfazer/refazer.');
    final top =
        field('Margem superior (cm)', page.margins.top, 'tw-margin-top');
    final right =
        field('Margem direita (cm)', page.margins.right, 'tw-margin-right');
    final bottom =
        field('Margem inferior (cm)', page.margins.bottom, 'tw-margin-bottom');
    final left =
        field('Margem esquerda (cm)', page.margins.left, 'tw-margin-left');
    final fields = _element('div', 'tw-editor__page-setup-fields')
      ..appendChild(_dialogField('Superior (cm)', top))
      ..appendChild(_dialogField('Inferior (cm)', bottom))
      ..appendChild(_dialogField('Esquerda (cm)', left))
      ..appendChild(_dialogField('Direita (cm)', right));
    final validation = _element('p', 'tw-editor__dialog-error')
      ..setAttribute('aria-live', 'polite');
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-page-setup-apply');

    void submit() {
      double? read(web.HTMLInputElement input) {
        final value = double.tryParse(input.value.replaceAll(',', '.'));
        if (value == null || !value.isFinite || value < 0) return null;
        return value * pointsPerCentimetre;
      }

      final nextTop = read(top);
      final nextRight = read(right);
      final nextBottom = read(bottom);
      final nextLeft = read(left);
      if (nextTop == null ||
          nextRight == null ||
          nextBottom == null ||
          nextLeft == null) {
        validation.textContent =
            'Informe quatro medidas numéricas não negativas.';
        return;
      }
      if (nextTop + nextBottom >= page.height ||
          nextLeft + nextRight >= page.width) {
        validation.textContent =
            'As margens precisam deixar uma área de texto na página.';
        return;
      }
      dispatch(SetActivePageMarginsAction.physical(
        top: _round2(nextTop),
        right: _round2(nextRight),
        bottom: _round2(nextBottom),
        left: _round2(nextLeft),
      ));
      _closeDialog();
      focus();
    }

    void keyHandler(web.Event event) {
      final key = event as web.KeyboardEvent;
      if (key.key == 'Escape') {
        key.preventDefault();
        _closeDialog();
        focus();
      } else if (key.key == 'Enter') {
        key.preventDefault();
        submit();
      }
    }

    for (final input in [top, right, bottom, left]) {
      input.addEventListener('keydown', keyHandler.toJS);
    }
    cancel.addEventListener('click', ((web.Event _) => _closeDialog()).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) _closeDialog();
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(fields)
      ..appendChild(validation)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    top.focus();
  }

  /// Word-like paper-size picker backed by the active document page setup.
  /// Presets are conveniences only; custom centimetre values remain available
  /// and are persisted as point values by [SetActivePageSizeAction].
  void _openPageSizeDialog() {
    if (!_pageSetupCanEdit) return;
    _closeDialog();
    final page = _pageConfigForState(editorState);
    const pointsPerCentimetre = 72 / 2.54;
    String centimetres(double points) =>
        (points / pointsPerCentimetre).toStringAsFixed(2);
    web.HTMLInputElement field(String label, double value, String id) =>
        _document.createElement('input') as web.HTMLInputElement
          ..type = 'number'
          ..min = '.01'
          ..step = '.01'
          ..value = centimetres(value)
          ..setAttribute('aria-label', label)
          ..setAttribute('data-testid', id);

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-page-size-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-page-size-dialog-title')
      ..setAttribute('data-testid', 'tw-page-size-dialog');
    final heading = _element('h2', null, 'Tamanho do papel')
      ..id = 'tw-page-size-dialog-title';
    final hint = _element('p', null,
        'Escolha um formato ou informe largura e altura em centímetros para a seção ativa.');
    final preset = _document.createElement('select') as web.HTMLSelectElement
      ..setAttribute('aria-label', 'Formato de papel')
      ..setAttribute('data-testid', 'tw-page-size-preset');
    for (final choice in const [
      ('custom', 'Personalizado', ''),
      ('a4', 'A4 — 21,00 × 29,70 cm', '21.00,29.70'),
      ('letter', 'Carta — 21,59 × 27,94 cm', '21.59,27.94'),
      ('legal', 'Ofício — 21,59 × 35,56 cm', '21.59,35.56'),
    ]) {
      preset.appendChild(_document.createElement('option')
        ..setAttribute('value', choice.$1)
        ..setAttribute('data-size', choice.$3)
        ..textContent = choice.$2);
    }
    final width = field('Largura (cm)', page.width, 'tw-page-width');
    final height = field('Altura (cm)', page.height, 'tw-page-height');
    final fields = _element('div', 'tw-editor__page-setup-fields')
      ..appendChild(_dialogField('Formato', preset))
      ..appendChild(_element('span', 'tw-editor__page-setup-spacer'))
      ..appendChild(_dialogField('Largura (cm)', width))
      ..appendChild(_dialogField('Altura (cm)', height));
    final validation = _element('p', 'tw-editor__dialog-error')
      ..setAttribute('aria-live', 'polite');
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-page-size-apply');

    void submit() {
      double? read(web.HTMLInputElement input) {
        final value = double.tryParse(input.value.replaceAll(',', '.'));
        if (value == null || !value.isFinite || value <= 0) return null;
        return value * pointsPerCentimetre;
      }

      final inlineSize = read(width);
      final blockSize = read(height);
      if (inlineSize == null || blockSize == null) {
        validation.textContent =
            'Informe largura e altura numéricas positivas.';
        return;
      }
      if (inlineSize <= page.margins.left + page.margins.right ||
          blockSize <= page.margins.top + page.margins.bottom) {
        validation.textContent =
            'O papel precisa comportar as margens atuais da página.';
        return;
      }
      dispatch(
          SetActivePageSizeAction(_round2(inlineSize), _round2(blockSize)));
      _closeDialog();
      focus();
    }

    preset.addEventListener(
        'change',
        ((web.Event _) {
          final option = preset.selectedOptions.item(0);
          final encoded = option?.getAttribute('data-size') ?? '';
          final values = encoded.split(',');
          if (values.length != 2 || values[0].isEmpty) return;
          width.value = values[0];
          height.value = values[1];
        }).toJS);
    void keyHandler(web.Event event) {
      final key = event as web.KeyboardEvent;
      if (key.key == 'Escape') {
        key.preventDefault();
        _closeDialog();
        focus();
      } else if (key.key == 'Enter') {
        key.preventDefault();
        submit();
      }
    }

    for (final input in [width, height]) {
      input.addEventListener('keydown', keyHandler.toJS);
    }
    cancel.addEventListener('click', ((web.Event _) => _closeDialog()).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) _closeDialog();
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(fields)
      ..appendChild(validation)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    width.focus();
  }

  void _openLinkDialog() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    _closeDialog();

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-link-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-link-dialog-title')
      ..setAttribute('data-testid', 'tw-link-dialog');
    final heading = _element('h2', null, 'Inserir link')
      ..id = 'tw-link-dialog-title';
    final hint = _element('p', null,
        'Cole um endereço seguro (https, http, mailto ou tel). Deixe vazio para remover o link.');
    final field = _document.createElement('input') as web.HTMLInputElement
      ..type = 'url'
      ..placeholder = 'https://exemplo.com'
      ..setAttribute('aria-label', 'Endereço do link')
      ..setAttribute('data-testid', 'tw-link-url');
    final current = _activeAttrs()['link'];
    if (current is String) field.value = current;
    final validation = _element('p', 'tw-editor__dialog-error')
      ..setAttribute('aria-live', 'polite');
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-link-apply');

    void submit() {
      final url = field.value.trim();
      if (url.isNotEmpty && !isExportSafeLinkUrl(url)) {
        validation.textContent = 'Esse tipo de endereço não é permitido.';
        field.focus();
        return;
      }
      if (isCollapsed(editorState.selection)) {
        validation.textContent = 'Selecione um texto antes de aplicar um link.';
        field.focus();
        return;
      }
      dispatch(SetLinkAction(url.isEmpty ? null : url));
      _closeDialog();
      focus();
    }

    cancel.addEventListener('click', ((web.Event _) => _closeDialog()).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    field.addEventListener(
        'keydown',
        ((web.Event event) {
          final key = event as web.KeyboardEvent;
          if (key.key == 'Enter') {
            key.preventDefault();
            submit();
          } else if (key.key == 'Escape') {
            key.preventDefault();
            _closeDialog();
            focus();
          }
        }).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) _closeDialog();
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(field)
      ..appendChild(validation)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    field.focus();
  }

  /// Opens Word-style find/replace against the engine's visible-text matcher.
  ///
  /// Matches retain the document's UTF-16 offsets, so replacement is routed
  /// through [ReplaceMatchAction]/[ReplaceAllAction] instead of mutating the
  /// browser DOM.  That keeps undo, tracked changes and embedded hosts in
  /// sync with the rendered document.
  void _openFindDialog() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    _closeDialog();

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-find-dialog-backdrop');
    final dialog =
        _element('section', 'tw-editor__dialog tw-editor__find-dialog')
          ..setAttribute('role', 'dialog')
          ..setAttribute('aria-modal', 'true')
          ..setAttribute('aria-labelledby', 'tw-find-dialog-title')
          ..setAttribute('data-testid', 'tw-find-dialog');
    final heading = _element('h2', null, 'Localizar e substituir')
      ..id = 'tw-find-dialog-title';
    final hint = _element('p', null,
        'A busca usa o texto real do documento e as substituições entram no histórico de desfazer.');
    final query = _document.createElement('input') as web.HTMLInputElement
      ..type = 'search'
      ..placeholder = 'Localizar'
      ..setAttribute('aria-label', 'Localizar')
      ..setAttribute('data-testid', 'tw-find-query');
    final replacement = _document.createElement('input') as web.HTMLInputElement
      ..type = 'text'
      ..placeholder = 'Substituir por'
      ..setAttribute('aria-label', 'Substituir por')
      ..setAttribute('data-testid', 'tw-find-replacement');
    final caseSensitive =
        _document.createElement('input') as web.HTMLInputElement
          ..type = 'checkbox'
          ..setAttribute('data-testid', 'tw-find-case-sensitive');
    final wholeWord = _document.createElement('input') as web.HTMLInputElement
      ..type = 'checkbox'
      ..setAttribute('data-testid', 'tw-find-whole-word');
    final result = _element('p', 'tw-editor__find-result')
      ..setAttribute('aria-live', 'polite')
      ..setAttribute('data-testid', 'tw-find-result');

    List<TextMatch> matches = const [];
    var matchIndex = 0;
    late final web.HTMLButtonElement previous;
    late final web.HTMLButtonElement next;
    late final web.HTMLButtonElement replace;
    late final web.HTMLButtonElement replaceAll;

    void selectCurrent() {
      if (matches.isEmpty) return;
      final match = matches[matchIndex];
      dispatch(SetSelectionAction(Selection(
        anchor: Position(blockId: match.blockId, offset: match.start),
        focus: Position(blockId: match.blockId, offset: match.end),
      )));
    }

    void refresh({bool select = false}) {
      final text = query.value;
      matches = findMatches(
        editorState.state,
        text,
        FindMatchesOptions(
          caseSensitive: caseSensitive.checked,
          wholeWord: wholeWord.checked,
        ),
      );
      if (matches.isEmpty) {
        matchIndex = 0;
      } else {
        matchIndex = matchIndex.clamp(0, matches.length - 1).toInt();
      }
      final enabled = matches.isNotEmpty;
      previous.disabled = !enabled;
      next.disabled = !enabled;
      replace.disabled = !enabled;
      replaceAll.disabled = !enabled;
      result.textContent = text.trim().isEmpty
          ? 'Digite um termo para localizar.'
          : enabled
              ? '${matchIndex + 1} de ${matches.length} ocorrência${matches.length == 1 ? '' : 's'}'
              : 'Nenhuma ocorrência.';
      if (select && enabled) selectCurrent();
    }

    final queryField = _dialogField('Localizar', query);
    final replacementField = _dialogField('Substituir por', replacement);
    final options = _element('div', 'tw-editor__find-options')
      ..appendChild(_findOption(caseSensitive, 'Diferenciar maiúsculas'))
      ..appendChild(_findOption(wholeWord, 'Palavra inteira'));
    final actions = _element('div', 'tw-editor__dialog-actions');
    final close = _dialogButton('Fechar', secondary: true);
    previous = _dialogButton('Anterior')
      ..setAttribute('data-testid', 'tw-find-previous');
    next = _dialogButton('Próximo')
      ..setAttribute('data-testid', 'tw-find-next');
    replace = _dialogButton('Substituir')
      ..setAttribute('data-testid', 'tw-find-replace');
    replaceAll = _dialogButton('Substituir tudo')
      ..setAttribute('data-testid', 'tw-find-replace-all');

    void move(int delta) {
      if (matches.isEmpty) return;
      matchIndex = (matchIndex + delta) % matches.length;
      if (matchIndex < 0) matchIndex += matches.length;
      refresh(select: true);
    }

    void replaceCurrent() {
      if (matches.isEmpty) return;
      dispatch(ReplaceMatchAction(matches[matchIndex], replacement.value));
      refresh(select: true);
    }

    void replaceEveryMatch() {
      if (matches.isEmpty) return;
      // Copy the offset snapshot before the reducer mutates document blocks.
      dispatch(
          ReplaceAllAction(List<TextMatch>.of(matches), replacement.value));
      matchIndex = 0;
      refresh(select: true);
    }

    void closeAndFocus() {
      _closeDialog();
      focus();
    }

    void onKey(web.Event event) {
      final key = event as web.KeyboardEvent;
      if (key.key == 'Escape') {
        key.preventDefault();
        closeAndFocus();
      } else if (key.key == 'Enter' && !key.shiftKey) {
        key.preventDefault();
        move(1);
      }
    }

    query.addEventListener(
        'input',
        ((web.Event _) {
          matchIndex = 0;
          refresh(select: true);
        }).toJS);
    replacement.addEventListener('keydown', onKey.toJS);
    query.addEventListener('keydown', onKey.toJS);
    caseSensitive.addEventListener(
        'change',
        ((web.Event _) {
          matchIndex = 0;
          refresh(select: true);
        }).toJS);
    wholeWord.addEventListener(
        'change',
        ((web.Event _) {
          matchIndex = 0;
          refresh(select: true);
        }).toJS);
    close.addEventListener('click', ((web.Event _) => closeAndFocus()).toJS);
    previous.addEventListener('click', ((web.Event _) => move(-1)).toJS);
    next.addEventListener('click', ((web.Event _) => move(1)).toJS);
    replace.addEventListener('click', ((web.Event _) => replaceCurrent()).toJS);
    replaceAll.addEventListener(
        'click', ((web.Event _) => replaceEveryMatch()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) _closeDialog();
        }).toJS);

    actions
      ..appendChild(close)
      ..appendChild(previous)
      ..appendChild(next)
      ..appendChild(replace)
      ..appendChild(replaceAll);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(queryField)
      ..appendChild(replacementField)
      ..appendChild(options)
      ..appendChild(result)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    refresh();
    query.focus();
  }

  web.HTMLElement _dialogField(String label, web.HTMLElement input) =>
      _element('label', 'tw-editor__dialog-field')
        ..appendChild(_element('span', null, label))
        ..appendChild(input);

  web.HTMLElement _findOption(web.HTMLInputElement input, String label) =>
      _element('label', 'tw-editor__find-option')
        ..appendChild(input)
        ..appendChild(_element('span', null, label));

  /// Opens a pixel-based size dialog for the currently selected block image.
  /// The model intentionally stores image dimensions as plain finite numbers,
  /// so this shell does not invent a second responsive-image configuration.
  void _openImageSizeDialog() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final image = _activeImageBlock();
    if (image == null) return;
    _closeDialog();

    double initialDimension(String key, double fallback) {
      final value = image.attrs[key];
      return value is num && value.isFinite && value > 0
          ? value.toDouble()
          : fallback;
    }

    web.HTMLInputElement field(String label, double value, String id) =>
        _document.createElement('input') as web.HTMLInputElement
          ..type = 'number'
          ..min = '.01'
          ..step = '1'
          ..value =
              value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)
          ..setAttribute('aria-label', label)
          ..setAttribute('data-testid', id);

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-image-size-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-image-size-dialog-title')
      ..setAttribute('data-testid', 'tw-image-size-dialog');
    final heading = _element('h2', null, 'Tamanho da imagem')
      ..id = 'tw-image-size-dialog-title';
    final hint = _element('p', null,
        'Informe largura e altura em pixels. A alteração preserva a imagem selecionada.');
    final width =
        field('Largura (px)', initialDimension('width', 320), 'tw-image-width');
    final height = field(
        'Altura (px)', initialDimension('height', 240), 'tw-image-height');
    final fields = _element('div', 'tw-editor__page-setup-fields')
      ..appendChild(_dialogField('Largura (px)', width))
      ..appendChild(_dialogField('Altura (px)', height));
    final validation = _element('p', 'tw-editor__dialog-error')
      ..setAttribute('aria-live', 'polite');
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-image-size-apply');

    void submit() {
      double? read(web.HTMLInputElement input) {
        final value = double.tryParse(input.value.replaceAll(',', '.'));
        if (value == null || !value.isFinite || value <= 0) return null;
        return value;
      }

      final nextWidth = read(width);
      final nextHeight = read(height);
      if (nextWidth == null || nextHeight == null) {
        validation.textContent =
            'Informe largura e altura numéricas positivas.';
        return;
      }
      dispatch(SetImageSizeAction(image.id.value, nextWidth, nextHeight));
      _closeDialog();
      focus();
    }

    void keyHandler(web.Event event) {
      final key = event as web.KeyboardEvent;
      if (key.key == 'Escape') {
        key.preventDefault();
        _closeDialog();
        focus();
      } else if (key.key == 'Enter') {
        key.preventDefault();
        submit();
      }
    }

    for (final input in [width, height]) {
      input.addEventListener('keydown', keyHandler.toJS);
    }
    cancel.addEventListener(
        'click',
        ((web.Event _) {
          _closeDialog();
          focus();
        }).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) {
            _closeDialog();
            focus();
          }
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(fields)
      ..appendChild(validation)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    width.focus();
  }

  /// Edits the persisted geometry of the selected text box or shape.
  ///
  /// This stays distinct from image sizing because drawings have a validated
  /// outline width and their identifiers must remain model actions rather
  /// than browser style mutations.
  void _openDrawingSizeDialog() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final drawing = _activeDrawingBlock();
    if (drawing == null) return;
    _closeDialog();

    final shapeKind = drawing.type == 'shape'
        ? DrawingShapeKind.fromValue(drawing.attrs['shapeKind']) ??
            DrawingShapeKind.rectangle
        : null;
    final fallback = shapeKind == null
        ? DrawingProperties.textBoxDefaults
        : DrawingProperties.defaultsFor(shapeKind);
    final properties =
        DrawingProperties.fromAttrs(drawing.attrs, fallback: fallback);

    web.HTMLInputElement field(
      String label,
      double value,
      String id, {
      double min = .01,
      double step = 1,
    }) =>
        _document.createElement('input') as web.HTMLInputElement
          ..type = 'number'
          ..min = min.toString()
          ..step = step.toString()
          ..value =
              value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)
          ..setAttribute('aria-label', label)
          ..setAttribute('data-testid', id);

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-drawing-size-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-drawing-size-dialog-title')
      ..setAttribute('data-testid', 'tw-drawing-size-dialog');
    final heading = _element('h2', null, 'Formato da forma')
      ..id = 'tw-drawing-size-dialog-title';
    final hint = _element('p', null,
        'Informe largura, altura e espessura do contorno em pixels.');
    final width = field('Largura (px)', properties.width, 'tw-drawing-width');
    final height = field('Altura (px)', properties.height, 'tw-drawing-height');
    final outlineWidth = field(
      'Espessura do contorno (px)',
      properties.outlineWidth,
      'tw-drawing-outline-width',
      min: 0,
      step: .5,
    );
    final fields = _element('div', 'tw-editor__page-setup-fields')
      ..appendChild(_dialogField('Largura (px)', width))
      ..appendChild(_dialogField('Altura (px)', height))
      ..appendChild(_dialogField('Contorno (px)', outlineWidth));
    final validation = _element('p', 'tw-editor__dialog-error')
      ..setAttribute('aria-live', 'polite');
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-drawing-size-apply');

    double? read(
      web.HTMLInputElement input, {
      required double minimum,
      required double maximum,
    }) {
      final value = double.tryParse(input.value.replaceAll(',', '.'));
      if (value == null ||
          !value.isFinite ||
          value < minimum ||
          value > maximum) {
        return null;
      }
      return value;
    }

    void submit() {
      final nextWidth = read(width, minimum: .01, maximum: 10000);
      final nextHeight = read(height, minimum: .01, maximum: 10000);
      final nextOutline = read(outlineWidth, minimum: 0, maximum: 256);
      if (nextWidth == null || nextHeight == null || nextOutline == null) {
        validation.textContent =
            'Informe dimensões positivas e contorno entre 0 e 256.';
        return;
      }
      dispatch(UpdateDrawingAction(
        drawing.id.value,
        width: nextWidth,
        height: nextHeight,
        outlineWidth: nextOutline,
      ));
      _closeDialog();
      focus();
    }

    void keyHandler(web.Event event) {
      final key = event as web.KeyboardEvent;
      if (key.key == 'Escape') {
        key.preventDefault();
        _closeDialog();
        focus();
      } else if (key.key == 'Enter') {
        key.preventDefault();
        submit();
      }
    }

    for (final input in [width, height, outlineWidth]) {
      input.addEventListener('keydown', keyHandler.toJS);
    }
    cancel.addEventListener(
        'click',
        ((web.Event _) {
          _closeDialog();
          focus();
        }).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) {
            _closeDialog();
            focus();
          }
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(fields)
      ..appendChild(validation)
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    width.focus();
  }

  /// Opens the accessibility description editor for the selected block image.
  void _openImageAltDialog() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final image = _activeImageBlock();
    if (image == null) return;
    _closeDialog();

    final backdrop = _element('div', 'tw-editor__dialog-backdrop')
      ..setAttribute('data-testid', 'tw-image-alt-dialog-backdrop');
    final dialog = _element('section', 'tw-editor__dialog')
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-labelledby', 'tw-image-alt-dialog-title')
      ..setAttribute('data-testid', 'tw-image-alt-dialog');
    final heading = _element('h2', null, 'Texto alternativo')
      ..id = 'tw-image-alt-dialog-title';
    final hint = _element('p', null,
        'Descreva a imagem para leitores de tela. Deixe vazio para remover a descrição.');
    final input = _document.createElement('input') as web.HTMLInputElement
      ..type = 'text'
      ..placeholder = 'Descrição da imagem'
      ..setAttribute('aria-label', 'Texto alternativo da imagem')
      ..setAttribute('data-testid', 'tw-image-alt-input');
    final current = image.attrs['alt'];
    if (current is String) input.value = current;
    final actions = _element('div', 'tw-editor__dialog-actions');
    final cancel = _dialogButton('Cancelar', secondary: true);
    final apply = _dialogButton('Aplicar')
      ..setAttribute('data-testid', 'tw-image-alt-apply');

    void submit() {
      final value = input.value.trim();
      dispatch(SetImageAltAction(image.id.value, value.isEmpty ? null : value));
      _closeDialog();
      focus();
    }

    input.addEventListener(
        'keydown',
        ((web.Event event) {
          final key = event as web.KeyboardEvent;
          if (key.key == 'Escape') {
            key.preventDefault();
            _closeDialog();
            focus();
          } else if (key.key == 'Enter') {
            key.preventDefault();
            submit();
          }
        }).toJS);
    cancel.addEventListener(
        'click',
        ((web.Event _) {
          _closeDialog();
          focus();
        }).toJS);
    apply.addEventListener('click', ((web.Event _) => submit()).toJS);
    backdrop.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == backdrop) {
            _closeDialog();
            focus();
          }
        }).toJS);
    actions
      ..appendChild(cancel)
      ..appendChild(apply);
    dialog
      ..appendChild(heading)
      ..appendChild(hint)
      ..appendChild(_dialogField('Descrição', input))
      ..appendChild(actions);
    backdrop.appendChild(dialog);
    root.appendChild(backdrop);
    _dialog = backdrop;
    input.focus();
  }

  void _insertImageFromFile() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final input = _document.createElement('input') as web.HTMLInputElement
      ..className = 'tw-editor__file-input'
      ..type = 'file'
      ..accept = 'image/png,image/jpeg,image/gif,image/webp,image/avif';
    root.appendChild(input);
    input.addEventListener(
        'change',
        ((web.Event _) {
          final file = input.files?.item(0);
          input.remove();
          if (file == null) return;
          if (!file.type.startsWith('image/') || file.size > 20 * 1024 * 1024) {
            _statusState.textContent =
                'Escolha uma imagem de até 20 MB (PNG, JPEG, GIF, WebP ou AVIF).';
            return;
          }
          _readImageFile(file);
        }).toJS);
    input.click();
  }

  void _readImageFile(web.File file) {
    _statusState.textContent = 'Carregando imagem…';
    final reader = web.FileReader();
    reader.onerror = ((web.Event _) {
      _statusState.textContent = 'Não foi possível ler a imagem.';
    }).toJS;
    reader.onload = ((web.Event _) {
      final result = reader.result;
      if (result == null || !result.isA<JSString>()) {
        _statusState.textContent = 'A imagem não retornou dados válidos.';
        return;
      }
      final source = (result as JSString).toDart;
      if (!isSafeImageUrl(source)) {
        _statusState.textContent = 'Esse formato de imagem não é aceito.';
        return;
      }
      _insertLoadedImage(source);
    }).toJS;
    reader.readAsDataURL(file);
  }

  void _insertLoadedImage(String source) {
    final image = _document.createElement('img') as web.HTMLImageElement;
    image.onerror = ((web.Event _) {
      _statusState.textContent = 'A imagem não pôde ser decodificada.';
    }).toJS;
    image.onload = ((web.Event _) {
      final naturalWidth =
          image.naturalWidth > 0 ? image.naturalWidth : image.width;
      final naturalHeight =
          image.naturalHeight > 0 ? image.naturalHeight : image.height;
      if (naturalWidth <= 0 || naturalHeight <= 0) {
        _statusState.textContent = 'A imagem não possui dimensões válidas.';
        return;
      }
      // Keep a large photo inside an A4-like page while preserving its ratio.
      const maxWidth = 620.0;
      final scale = naturalWidth > maxWidth ? maxWidth / naturalWidth : 1.0;
      dispatch(InsertImageAction(
        source,
        width: naturalWidth * scale,
        height: naturalHeight * scale,
      ));
      _setSaveState('Alterado');
    }).toJS;
    image.src = source;
  }

  web.HTMLButtonElement _dialogButton(String label, {bool secondary = false}) {
    final button = _document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..textContent = label;
    if (secondary) button.classList.add('tw-editor__dialog-button--secondary');
    return button;
  }

  void _closeDialog() {
    final dialog = _dialog;
    _dialog = null;
    dialog?.remove();
  }

}
