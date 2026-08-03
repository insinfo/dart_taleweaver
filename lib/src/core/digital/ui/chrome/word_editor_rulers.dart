part of taleweaver_word_editor;

/// Pointer capture state for a ruler operation.  Preview positions are kept
/// only in the shell until pointer-up, at which point exactly one editor
/// action is dispatched and therefore exactly one undo step is recorded.
class _RulerDrag {
  final String handle;
  final int pointerId;
  final web.HTMLElement origin;
  final PageConfig page;
  final TabStop? tabStop;

  const _RulerDrag({
    required this.handle,
    required this.pointerId,
    required this.origin,
    required this.page,
    this.tabStop,
  });
}

// `package:web` exposes MouseEvent.clientX/clientY as `int`, while real
// pointer coordinates may be fractional under zoom or high-DPI displays.
// Read the raw JS number so a ruler drag never throws merely because the
// browser reported a half CSS pixel.
double _eventClientX(web.MouseEvent event) =>
    ((event as JSObject).getProperty('clientX'.toJS) as JSNumber).toDartDouble;

double _eventClientY(web.MouseEvent event) =>
    ((event as JSObject).getProperty('clientY'.toJS) as JSNumber).toDartDouble;

extension _TaleweaverEditorRulers on TaleweaverEditor {
  web.HTMLElement _buildRulers() {
    final rulers = _element('div', 'tw-editor__rulers')
      ..setAttribute('aria-label', 'Régua do documento')
      ..setAttribute('data-testid', 'tw-rulers');
    _rulerTabSelector =
        _document.createElement('button') as web.HTMLButtonElement
          ..className = 'tw-editor__ruler-corner'
          ..type = 'button'
          ..setAttribute('aria-label', 'Tipo de tabulação: esquerda')
          ..setAttribute('title', 'Tipo de tabulação: esquerda')
          ..setAttribute('data-tab-alignment', _newTabAlignment.value)
          ..setAttribute('data-testid', 'tw-ruler-tab-selector');
    _rulerTabSelector.addEventListener(
        'pointerdown', ((web.Event event) => event.preventDefault()).toJS);
    _rulerTabSelector.addEventListener(
        'click', ((web.Event _) => _cycleRulerTabAlignment()).toJS);
    _horizontalRulerViewport =
        _element('div', 'tw-editor__horizontal-ruler-viewport');
    _horizontalRuler = _element('div', 'tw-editor__horizontal-ruler')
      ..setAttribute('data-testid', 'tw-horizontal-ruler');
    _horizontalRulerTicks = _element('div', 'tw-editor__ruler-ticks');
    _horizontalMarginStart = _element('div',
        'tw-editor__ruler-margin-zone tw-editor__ruler-margin-zone--start');
    _horizontalMarginEnd = _element('div',
        'tw-editor__ruler-margin-zone tw-editor__ruler-margin-zone--end');
    _horizontalRulerTabs = _element('div', 'tw-editor__ruler-tabs');
    _horizontalRuler
      ..appendChild(_horizontalRulerTicks)
      ..appendChild(_horizontalMarginStart)
      ..appendChild(_horizontalMarginEnd)
      ..appendChild(_rulerHandle('margin-left', 'Margem esquerda'))
      ..appendChild(_rulerHandle('margin-right', 'Margem direita'))
      ..appendChild(_rulerHandle('indent-first', 'Recuo da primeira linha'))
      ..appendChild(_rulerHandle('indent-left', 'Recuo esquerdo'))
      ..appendChild(_rulerHandle('indent-right', 'Recuo direito'))
      ..appendChild(_horizontalRulerTabs);
    _horizontalRuler.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event.target == _horizontalRuler) event.preventDefault();
        }).toJS);
    _horizontalRuler.addEventListener(
        'click',
        ((web.Event event) {
          if (event.target == _horizontalRuler) _placeRulerTab(event);
        }).toJS);
    _horizontalRulerViewport.appendChild(_horizontalRuler);
    rulers
      ..appendChild(_rulerTabSelector)
      ..appendChild(_horizontalRulerViewport);
    _updateRulerTabSelector();
    return rulers;
  }

  web.HTMLElement _buildWorkspace() {
    _workspace = _element('main', 'tw-editor__workspace')
      ..setAttribute('data-testid', 'tw-editor-workspace');
    _verticalRuler = _buildVerticalRuler();
    final stack = _element('div', 'tw-editor__page-stack');
    _page = _element('article', 'tw-editor__page')
      ..setAttribute('aria-label', 'Página 1');
    _headerSurface =
        _element('div', 'tw-editor__template tw-editor__template--header')
          ..setAttribute('data-testid', 'tw-page-header');
    documentSurface = _element('div', 'tw-editor__document-host')
      ..setAttribute('data-placeholder', options.placeholder);
    _footerSurface =
        _element('div', 'tw-editor__template tw-editor__template--footer')
          ..setAttribute('data-testid', 'tw-page-footer');
    _page
      ..appendChild(_headerSurface)
      ..appendChild(documentSurface)
      ..appendChild(_footerSurface);
    stack.appendChild(_page);
    _workspace
      // The vertical ruler is an overlay in the workspace gutter, not a flex
      // sibling of the sheet. Reserving a column for it shifts a centred page
      // and is visibly unlike Word/OnlyOffice.
      ..appendChild(stack)
      ..appendChild(_verticalRuler);
    return _workspace;
  }

  web.HTMLElement _buildVerticalRuler() {
    final ruler = _element('aside', 'tw-editor__vertical-ruler')
      ..setAttribute('aria-label', 'Régua vertical')
      ..setAttribute('data-testid', 'tw-vertical-ruler');
    _verticalRulerTicks = _element('div', 'tw-editor__vertical-ruler-ticks');
    _verticalMarginStart = _element('div',
        'tw-editor__vertical-ruler-margin-zone tw-editor__vertical-ruler-margin-zone--start');
    _verticalMarginEnd = _element('div',
        'tw-editor__vertical-ruler-margin-zone tw-editor__vertical-ruler-margin-zone--end');
    ruler
      ..appendChild(_verticalRulerTicks)
      ..appendChild(_verticalMarginStart)
      ..appendChild(_verticalMarginEnd)
      ..appendChild(
          _rulerHandle('margin-top', 'Margem superior', vertical: true))
      ..appendChild(
          _rulerHandle('margin-bottom', 'Margem inferior', vertical: true));
    return ruler;
  }

  web.HTMLElement _rulerHandle(String kind, String label,
      {bool vertical = false}) {
    final handle = _element(
        'div',
        'tw-editor__ruler-handle '
            'tw-editor__ruler-handle--$kind'
            '${vertical ? ' tw-editor__ruler-handle--vertical' : ''}')
      ..setAttribute('data-ruler-handle', kind)
      ..setAttribute('role', 'slider')
      ..setAttribute('tabindex', '0')
      ..setAttribute('aria-label', label)
      ..setAttribute('aria-orientation', vertical ? 'vertical' : 'horizontal')
      ..setAttribute('aria-valuemin', '0');
    handle.addEventListener('pointerdown',
        ((web.Event event) => _beginRulerDrag(kind, handle, event)).toJS);
    handle.addEventListener(
        'pointermove', ((web.Event event) => _moveRulerDrag(event)).toJS);
    handle.addEventListener(
        'pointerup', ((web.Event event) => _endRulerDrag(event)).toJS);
    handle.addEventListener(
        'pointercancel', ((web.Event event) => _cancelRulerDrag(event)).toJS);
    handle.addEventListener(
        'keydown', ((web.Event event) => _nudgeRulerHandle(kind, event)).toJS);
    _rulerHandles[kind] = handle;
    return handle;
  }

  void _rebuildRulerTicks(PageConfig page) {
    void clear(web.HTMLElement element) {
      while (element.firstChild != null) {
        element.removeChild(element.firstChild!);
      }
    }

    clear(_horizontalRulerTicks);
    clear(_verticalRulerTicks);
    // Keep Word's familiar zero at the writing margin rather than at the
    // paper edge. The UI is pt-BR, so centimetres are less surprising than
    // the old inch labels; geometry itself remains points in the document.
    const pointsPerCentimetre = 72 / 2.54;
    final horizontalCount =
        ((page.width - page.margins.left) / pointsPerCentimetre)
            .floor()
            .clamp(0, 100);
    for (var centimetre = 0; centimetre <= horizontalCount; centimetre++) {
      final point = page.margins.left + centimetre * pointsPerCentimetre;
      final label = _element('span', 'tw-editor__ruler-number', '$centimetre');
      label.style.left = '${(point / page.width * 100).clamp(0, 100)}%';
      _horizontalRulerTicks.appendChild(label);
    }
    final verticalCount =
        ((page.height - page.margins.top) / pointsPerCentimetre)
            .floor()
            .clamp(0, 100);
    for (var centimetre = 0; centimetre <= verticalCount; centimetre++) {
      final point = page.margins.top + centimetre * pointsPerCentimetre;
      final label =
          _element('span', 'tw-editor__vertical-ruler-number', '$centimetre');
      label.style.top = '${(point / page.height * 100).clamp(0, 100)}%';
      _verticalRulerTicks.appendChild(label);
    }
  }

  void _syncRulers(EditorState state, PageConfig page) {
    if (_destroyed) return;
    if (!_samePageConfig(_rulerPageConfig, page)) {
      _rulerPageConfig = page;
      _rebuildRulerTicks(page);
    }
    _updateRulerPositions(page, _rulerValues(state, page));
    _renderRulerTabs(state, page);
    _scheduleRulerLayout();
  }

  bool _samePageConfig(PageConfig? previous, PageConfig next) {
    if (previous == null) return false;
    return previous.width == next.width &&
        previous.height == next.height &&
        previous.headerFooterGap == next.headerFooterGap &&
        previous.margins.top == next.margins.top &&
        previous.margins.right == next.margins.right &&
        previous.margins.bottom == next.margins.bottom &&
        previous.margins.left == next.margins.left;
  }

  ({
    double marginLeft,
    double marginRight,
    double marginTop,
    double marginBottom,
    double inlineStart,
    double inlineEnd,
    double firstLine,
  }) _rulerValues(EditorState state, PageConfig page) {
    double direct(String key) {
      final value = _focusBlock(state)?.attrs[key];
      return value is num && value.isFinite ? value.toDouble() : 0;
    }

    return (
      marginLeft: _rulerPreview['margin-left'] ?? page.margins.left,
      marginRight: _rulerPreview['margin-right'] ?? page.margins.right,
      marginTop: _rulerPreview['margin-top'] ?? page.margins.top,
      marginBottom: _rulerPreview['margin-bottom'] ?? page.margins.bottom,
      inlineStart: _rulerPreview['indent-left'] ?? direct('marginInlineStart'),
      inlineEnd: _rulerPreview['indent-right'] ?? direct('marginInlineEnd'),
      firstLine: _rulerPreview['indent-first'] ?? direct('textIndent'),
    );
  }

  void _updateRulerPositions(
    PageConfig page,
    ({
      double marginLeft,
      double marginRight,
      double marginTop,
      double marginBottom,
      double inlineStart,
      double inlineEnd,
      double firstLine,
    }) values,
  ) {
    final pxPerPoint = 96 / 72;
    final contentStart = values.marginLeft;
    final contentEnd = page.width - values.marginRight;
    final indentStart = contentStart + values.inlineStart / pxPerPoint;
    final firstLine = indentStart + values.firstLine / pxPerPoint;
    final indentEnd = contentEnd - values.inlineEnd / pxPerPoint;
    double percent(double value, double total) =>
        (value / total * 100).clamp(0, 100).toDouble();
    void horizontal(String kind, double value) {
      final handle = _rulerHandles[kind];
      if (handle == null) return;
      handle.style.left = '${percent(value, page.width)}%';
      handle.setAttribute('aria-valuemax', page.width.toStringAsFixed(2));
      handle.setAttribute('aria-valuenow', value.toStringAsFixed(2));
    }

    void vertical(String kind, double value) {
      final handle = _rulerHandles[kind];
      if (handle == null) return;
      handle.style.top = '${percent(value, page.height)}%';
      handle.setAttribute('aria-valuemax', page.height.toStringAsFixed(2));
      handle.setAttribute('aria-valuenow', value.toStringAsFixed(2));
    }

    _horizontalMarginStart.style.width =
        '${percent(values.marginLeft, page.width)}%';
    _horizontalMarginEnd.style.left = '${percent(contentEnd, page.width)}%';
    _verticalMarginStart.style.height =
        '${percent(values.marginTop, page.height)}%';
    _verticalMarginEnd.style.top =
        '${percent(page.height - values.marginBottom, page.height)}%';
    horizontal('margin-left', values.marginLeft);
    horizontal('margin-right', contentEnd);
    horizontal('indent-first', firstLine);
    horizontal('indent-left', indentStart);
    horizontal('indent-right', indentEnd);
    vertical('margin-top', values.marginTop);
    vertical('margin-bottom', page.height - values.marginBottom);
  }

  void _renderRulerTabs(EditorState state, PageConfig page) {
    while (_horizontalRulerTabs.firstChild != null) {
      _horizontalRulerTabs.removeChild(_horizontalRulerTabs.firstChild!);
    }
    final block = getBlock(state.state, state.selection.focus.blockId);
    if (block == null) return;
    final stops =
        normalizeTabStops(block.attrs['tabStops']) ?? const <TabStop>[];
    final pxPerPoint = 96 / 72;
    final contentWidth = page.width - page.margins.left - page.margins.right;
    for (final stop in stops) {
      final point = page.margins.left + stop.position / pxPerPoint;
      if (point < page.margins.left - 1 ||
          point > page.margins.left + contentWidth + 1) {
        continue;
      }
      final marker = _document.createElement('button') as web.HTMLButtonElement
        ..className =
            'tw-editor__ruler-tab tw-editor__ruler-tab--${stop.alignment.value}'
        ..type = 'button'
        ..style.left = '${(point / page.width * 100).clamp(0, 100)}%'
        ..setAttribute('aria-label',
            'Tabulação ${stop.alignment.value} em ${stop.position.round()} pixels')
        ..setAttribute('title', 'Clique direito para remover esta tabulação');
      marker.addEventListener('pointerdown',
          ((web.Event event) => _beginRulerTabDrag(stop, marker, event)).toJS);
      marker.addEventListener(
          'contextmenu',
          ((web.Event event) {
            event.preventDefault();
            _removeRulerTab(stop);
          }).toJS);
      _horizontalRulerTabs.appendChild(marker);
    }
  }

  bool get _pageSetupCanEdit =>
      !_destroyed &&
      _mode == TaleweaverEditorMode.editor &&
      getBlock(editorState.state, editorState.selection.focus.blockId) != null;

  bool get _rulerCanEdit =>
      _pageSetupCanEdit && _documentView == TaleweaverDocumentView.paginated;

  void _cycleRulerTabAlignment() {
    const values = [
      TabAlignment.left,
      TabAlignment.center,
      TabAlignment.right,
      TabAlignment.decimal,
    ];
    final index = values.indexOf(_newTabAlignment);
    _newTabAlignment = values[(index + 1) % values.length];
    _updateRulerTabSelector();
  }

  void _updateRulerTabSelector() {
    final label = switch (_newTabAlignment) {
      TabAlignment.left => 'esquerda',
      TabAlignment.center => 'centralizada',
      TabAlignment.right => 'direita',
      TabAlignment.decimal => 'decimal',
      TabAlignment.contentEdge => 'borda do conteúdo',
    };
    _rulerTabSelector
      ..setAttribute('data-tab-alignment', _newTabAlignment.value)
      ..setAttribute('aria-label', 'Tipo de tabulação: $label')
      ..setAttribute('title',
          'Tipo de tabulação: $label. Clique na régua para posicionar.');
  }

  void _placeRulerTab(web.Event event) {
    if (!_rulerCanEdit || event is! web.MouseEvent) return;
    final page = _pageConfigForState(editorState);
    final rect = _horizontalRuler.getBoundingClientRect();
    if (rect.width <= 0) return;
    final point = _clampDouble(
        (_eventClientX(event) - rect.left) / rect.width * page.width,
        0,
        page.width);
    final pxPerPoint = 96 / 72;
    final position = (point - page.margins.left) * pxPerPoint;
    final available =
        (page.width - page.margins.left - page.margins.right) * pxPerPoint;
    if (position <= 0 || position >= available) return;
    final block =
        getBlock(editorState.state, editorState.selection.focus.blockId);
    if (block == null) return;
    final stops = [
      ...(normalizeTabStops(block.attrs['tabStops']) ?? const <TabStop>[]),
    ];
    if (stops.any((stop) => (stop.position - position).abs() < 4)) return;
    stops.add(TabStop(
      position: _round2(position),
      alignment: _newTabAlignment,
      leader: LeaderStyle.none,
    ));
    dispatch(SetTabStopsAction(block.id.value, stops));
  }

  void _removeRulerTab(TabStop target) {
    if (!_rulerCanEdit) return;
    final block =
        getBlock(editorState.state, editorState.selection.focus.blockId);
    if (block == null) return;
    final stops =
        normalizeTabStops(block.attrs['tabStops']) ?? const <TabStop>[];
    dispatch(SetTabStopsAction(
      block.id.value,
      [
        for (final stop in stops)
          if (stop.position != target.position ||
              stop.alignment != target.alignment ||
              stop.leader != target.leader)
            stop,
      ],
    ));
  }

  void _commitRulerTabDrag(TabStop target, double position, PageConfig page) {
    if (!_rulerCanEdit) return;
    final block =
        getBlock(editorState.state, editorState.selection.focus.blockId);
    if (block == null) return;
    final stops =
        normalizeTabStops(block.attrs['tabStops']) ?? const <TabStop>[];
    final available =
        (page.width - page.margins.left - page.margins.right) * 96 / 72;
    bool isTarget(TabStop stop) =>
        stop.position == target.position &&
        stop.alignment == target.alignment &&
        stop.leader == target.leader;
    if (position < 0 || position > available) {
      dispatch(SetTabStopsAction(block.id.value, [
        for (final stop in stops)
          if (!isTarget(stop)) stop
      ]));
      return;
    }
    final rounded = _round2(position);
    if ((rounded - target.position).abs() < .01) return;
    dispatch(SetTabStopsAction(block.id.value, [
      for (final stop in stops)
        if (isTarget(stop))
          TabStop(
            position: rounded,
            alignment: stop.alignment,
            leader: stop.leader,
          )
        else
          stop,
    ]));
  }

  void _beginRulerDrag(String handle, web.HTMLElement origin, web.Event event) {
    if (!_rulerCanEdit || event is! web.PointerEvent || event.button != 0) {
      return;
    }
    event.preventDefault();
    final page = _pageConfigForState(editorState);
    _rulerPreview.clear();
    _rulerDrag = _RulerDrag(
      handle: handle,
      pointerId: event.pointerId,
      origin: origin,
      page: page,
    );
    origin.setPointerCapture(event.pointerId);
    _moveRulerDrag(event);
  }

  void _beginRulerTabDrag(
      TabStop stop, web.HTMLElement origin, web.Event event) {
    if (!_rulerCanEdit || event is! web.PointerEvent || event.button != 0) {
      return;
    }
    event.preventDefault();
    final page = _pageConfigForState(editorState);
    _rulerPreview.clear();
    _rulerDrag = _RulerDrag(
      handle: 'tab',
      pointerId: event.pointerId,
      origin: origin,
      page: page,
      tabStop: stop,
    );
    origin.setPointerCapture(event.pointerId);
    _moveRulerDrag(event);
  }

  void _moveRulerDrag(web.Event event) {
    final drag = _rulerDrag;
    if (drag == null ||
        event is! web.PointerEvent ||
        event.pointerId != drag.pointerId) {
      return;
    }
    event.preventDefault();
    final values = _rulerValues(editorState, drag.page);
    final page = drag.page;
    final pxPerPoint = 96 / 72;
    final minContent = 36.0;
    final maxX = page.width - values.marginRight - minContent;
    final maxY = page.height - values.marginBottom - minContent;
    final x = _horizontalRulerCoordinate(event, page);
    final y = _verticalRulerCoordinate(event, page);
    switch (drag.handle) {
      case 'margin-left':
        _rulerPreview['margin-left'] = _clampDouble(x, 0, maxX);
        break;
      case 'margin-right':
        _rulerPreview['margin-right'] = _clampDouble(
            page.width - x, 0, page.width - values.marginLeft - minContent);
        break;
      case 'margin-top':
        _rulerPreview['margin-top'] = _clampDouble(y, 0, maxY);
        break;
      case 'margin-bottom':
        _rulerPreview['margin-bottom'] = _clampDouble(
            page.height - y, 0, page.height - values.marginTop - minContent);
        break;
      case 'indent-left':
        final max = ((page.width - values.marginLeft - values.marginRight) *
                    pxPerPoint -
                18)
            .clamp(0, double.infinity)
            .toDouble();
        final next = _clampDouble((x - values.marginLeft) * pxPerPoint, 0, max);
        _rulerPreview['indent-left'] = next;
        // The lower marker changes paragraph start while retaining the
        // absolute position of the first line, matching Word's hanging-indent
        // control.
        _rulerPreview['indent-first'] =
            values.inlineStart + values.firstLine - next;
        break;
      case 'indent-first':
        _rulerPreview['indent-first'] =
            (x - values.marginLeft) * pxPerPoint - values.inlineStart;
        break;
      case 'indent-right':
        final max = ((page.width - values.marginLeft - values.marginRight) *
                    pxPerPoint -
                18)
            .clamp(0, double.infinity)
            .toDouble();
        _rulerPreview['indent-right'] = _clampDouble(
            (page.width - values.marginRight - x) * pxPerPoint, 0, max);
        break;
      case 'tab':
        final position = (x - page.margins.left) * pxPerPoint;
        _rulerPreview['tab-position'] = position;
        drag.origin.style.left =
            '${(x / page.width * 100).clamp(0, 100).toStringAsFixed(3)}%';
        break;
    }
    _updateRulerPositions(page, _rulerValues(editorState, page));
  }

  void _endRulerDrag(web.Event event) {
    final drag = _rulerDrag;
    if (drag == null ||
        event is! web.PointerEvent ||
        event.pointerId != drag.pointerId) {
      return;
    }
    _moveRulerDrag(event);
    final values = _rulerValues(editorState, drag.page);
    final tabPosition = _rulerPreview['tab-position'];
    _rulerDrag = null;
    _rulerPreview.clear();
    drag.origin.releasePointerCapture(event.pointerId);
    if (!_rulerCanEdit) {
      _syncRulers(editorState, _pageConfigForState(editorState));
      return;
    }
    switch (drag.handle) {
      case 'margin-left':
      case 'margin-right':
      case 'margin-top':
      case 'margin-bottom':
        dispatch(SetActivePageMarginsAction.physical(
          top: _round2(values.marginTop),
          right: _round2(values.marginRight),
          bottom: _round2(values.marginBottom),
          left: _round2(values.marginLeft),
        ));
        break;
      case 'indent-left':
      case 'indent-first':
      case 'indent-right':
        dispatch(SetParagraphIndentsAction(
          _nullableRulerValue(values.inlineStart),
          _nullableRulerValue(values.inlineEnd),
          _nullableRulerValue(values.firstLine),
        ));
        break;
      case 'tab':
        final stop = drag.tabStop;
        if (stop != null && tabPosition != null) {
          _commitRulerTabDrag(stop, tabPosition, drag.page);
        }
        break;
    }
  }

  void _cancelRulerDrag(web.Event event) {
    final drag = _rulerDrag;
    if (drag == null ||
        event is! web.PointerEvent ||
        event.pointerId != drag.pointerId) {
      return;
    }
    _rulerDrag = null;
    _rulerPreview.clear();
    _syncRulers(editorState, _pageConfigForState(editorState));
  }

  void _nudgeRulerHandle(String handle, web.Event event) {
    if (event is! web.KeyboardEvent || !_rulerCanEdit) return;
    final horizontal = event.key == 'ArrowLeft' || event.key == 'ArrowRight';
    final vertical = event.key == 'ArrowUp' || event.key == 'ArrowDown';
    if (!horizontal && !vertical) return;
    final isVerticalHandle =
        handle == 'margin-top' || handle == 'margin-bottom';
    if (isVerticalHandle != vertical) return;
    event.preventDefault();
    final marginDelta = event.shiftKey ? 12.0 : 3.0;
    final indentDelta = event.shiftKey ? 16.0 : 4.0;
    final page = _pageConfigForState(editorState);
    final values = _rulerValues(editorState, page);
    final direction =
        (event.key == 'ArrowRight' || event.key == 'ArrowDown') ? 1.0 : -1.0;
    switch (handle) {
      case 'margin-left':
        _dispatchRulerMargins(page, values.marginLeft + direction * marginDelta,
            values.marginRight, values.marginTop, values.marginBottom);
        break;
      case 'margin-right':
        _dispatchRulerMargins(
            page,
            values.marginLeft,
            values.marginRight - direction * marginDelta,
            values.marginTop,
            values.marginBottom);
        break;
      case 'margin-top':
        _dispatchRulerMargins(page, values.marginLeft, values.marginRight,
            values.marginTop + direction * marginDelta, values.marginBottom);
        break;
      case 'margin-bottom':
        _dispatchRulerMargins(page, values.marginLeft, values.marginRight,
            values.marginTop, values.marginBottom - direction * marginDelta);
        break;
      case 'indent-left':
        final next = _clampDouble(
            values.inlineStart + direction * indentDelta, 0, double.infinity);
        dispatch(SetParagraphIndentsAction(
          _nullableRulerValue(next),
          _nullableRulerValue(values.inlineEnd),
          _nullableRulerValue(values.inlineStart + values.firstLine - next),
        ));
        break;
      case 'indent-first':
        dispatch(SetParagraphIndentsAction(
          _nullableRulerValue(values.inlineStart),
          _nullableRulerValue(values.inlineEnd),
          _nullableRulerValue(values.firstLine + direction * indentDelta),
        ));
        break;
      case 'indent-right':
        final next = _clampDouble(
            values.inlineEnd - direction * indentDelta, 0, double.infinity);
        dispatch(SetParagraphIndentsAction(
          _nullableRulerValue(values.inlineStart),
          _nullableRulerValue(next),
          _nullableRulerValue(values.firstLine),
        ));
        break;
    }
  }

  void _dispatchRulerMargins(
    PageConfig page,
    double left,
    double right,
    double top,
    double bottom,
  ) {
    const minContent = 36.0;
    dispatch(SetActivePageMarginsAction.physical(
      top: _round2(_clampDouble(top, 0, page.height - bottom - minContent)),
      right: _round2(_clampDouble(right, 0, page.width - left - minContent)),
      bottom: _round2(_clampDouble(bottom, 0, page.height - top - minContent)),
      left: _round2(_clampDouble(left, 0, page.width - right - minContent)),
    ));
  }

  double _horizontalRulerCoordinate(web.PointerEvent event, PageConfig page) {
    final rect = _horizontalRuler.getBoundingClientRect();
    if (rect.width <= 0) return 0;
    return _clampDouble(
        (_eventClientX(event) - rect.left) / rect.width * page.width,
        0,
        page.width);
  }

  double _verticalRulerCoordinate(web.PointerEvent event, PageConfig page) {
    final rect = _verticalRuler.getBoundingClientRect();
    if (rect.height <= 0) return 0;
    return _clampDouble(
        (_eventClientY(event) - rect.top) / rect.height * page.height,
        0,
        page.height);
  }

  double _clampDouble(num value, num lower, num upper) {
    final ceiling = upper < lower ? lower : upper;
    return value.clamp(lower, ceiling).toDouble();
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;

  double? _nullableRulerValue(double value) =>
      value.abs() < .01 ? null : _round2(value);

  void _installRulerObservers() {
    _workspace.addEventListener(
        'scroll', ((web.Event _) => _scheduleRulerLayout()).toJS);
    _rulerResizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver _) {
        if (entries.length > 0) _scheduleRulerLayout();
      }).toJS,
    )
      ..observe(_workspace)
      ..observe(_page);
  }

  void _scheduleRulerLayout() {
    if (_destroyed || _rulerAnimationFrame != null) return;
    _rulerAnimationFrame = web.window.requestAnimationFrame(((double _) {
      _rulerAnimationFrame = null;
      if (_destroyed || !root.isConnected) return;
      final viewport = _horizontalRulerViewport.getBoundingClientRect();
      final fallback = _page.getBoundingClientRect();
      final active = _activePhysicalPagePosition(editorState);
      final pageLeft = active?.left ?? fallback.left;
      final pageTop = active?.top ?? fallback.top;
      final pageWidth = active?.width ?? fallback.width;
      final pageHeight = active?.height ?? fallback.height;
      if (viewport.width > 0 && pageWidth > 0) {
        _horizontalRuler.style
          ..left = '${(pageLeft - viewport.left).toStringAsFixed(2)}px'
          ..width = '${pageWidth.toStringAsFixed(2)}px';
      }
      if (pageHeight > 0) {
        _verticalRuler.style.height = '${pageHeight.toStringAsFixed(2)}px';
        final workspace = _workspace.getBoundingClientRect();
        final scrollTop = _workspace.scrollTop;
        // The ruler is absolutely positioned in the scrolling workspace.
        // Preserve the signed content coordinate so a page partly above the
        // viewport keeps its scale aligned instead of snapping to the top.
        final localTop = pageTop - workspace.top + scrollTop;
        // The page can be horizontally panned under the ruler, but the
        // vertical scale remains in the fixed left workspace gutter just like
        // Word.  An absolutely positioned child needs the scroll offset to
        // achieve that viewport-anchored horizontal position.
        _verticalRuler.style
          ..top = '${localTop.toStringAsFixed(2)}px'
          ..left = '${_workspace.scrollLeft.toStringAsFixed(2)}px';
        final visible = pageTop + pageHeight > workspace.top + 1 &&
            pageTop < workspace.bottom - 1;
        _verticalRuler.style.display = visible ? '' : 'none';
      }
      final config = _rulerPageConfig;
      if (config != null && pageWidth > 0 && pageHeight > 0) {
        const pointsPerCentimetre = 72 / 2.54;
        final horizontalCentimetre =
            pageWidth / (config.width / pointsPerCentimetre);
        final verticalCentimetre =
            pageHeight / (config.height / pointsPerCentimetre);
        if (horizontalCentimetre.isFinite && horizontalCentimetre > 0) {
          final margin = pageWidth * config.margins.left / config.width;
          _horizontalRuler.style.backgroundSize =
              '${(horizontalCentimetre / 4).toStringAsFixed(2)}px 5px, '
              '${horizontalCentimetre.toStringAsFixed(2)}px 9px';
          _horizontalRuler.style.backgroundPosition =
              '${margin.toStringAsFixed(2)}px 17px, '
              '${margin.toStringAsFixed(2)}px 9px';
        }
        if (verticalCentimetre.isFinite && verticalCentimetre > 0) {
          final margin = pageHeight * config.margins.top / config.height;
          _verticalRuler.style.backgroundSize =
              '5px ${(verticalCentimetre / 4).toStringAsFixed(2)}px, '
              '9px ${verticalCentimetre.toStringAsFixed(2)}px';
          _verticalRuler.style.backgroundPosition =
              '14px ${margin.toStringAsFixed(2)}px, '
              '9px ${margin.toStringAsFixed(2)}px';
        }
      }
    }).toJS);
  }
}
