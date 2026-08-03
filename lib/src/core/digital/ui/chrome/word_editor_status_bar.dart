/// Reusable status bar for the embeddable Word editor chrome.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'word_editor_title_bar.dart' show WordEditorChromeButtonBuilder;

/// DOM component for the Word editor status bar.
///
/// It owns only the fixed chrome markup. State calculation and all editor
/// commands remain with the shell that supplies callbacks and a button builder.
final class WordEditorStatusBar {
  WordEditorStatusBar({
    required web.Document document,
    required void Function(double zoom) onZoomChanged,
    required void Function() onZoomOut,
    required void Function() onZoomIn,
    required WordEditorChromeButtonBuilder buttonBuilder,
    String initialState = 'Pronto',
    String initialPage = 'Página 1',
    String initialWords = '0 palavras',
    String initialMode = 'Layout de impressão',
    double initialZoom = 1,
  })  : state = document.createElement('span') as web.HTMLElement,
        page = document.createElement('span') as web.HTMLElement,
        words = document.createElement('span') as web.HTMLElement,
        mode = document.createElement('span') as web.HTMLElement,
        zoomInput = document.createElement('input') as web.HTMLInputElement,
        zoomLabel = document.createElement('span') as web.HTMLElement,
        element = document.createElement('footer') as web.HTMLElement {
    final zoomPercent = (initialZoom * 100).round();
    element
      ..className = 'tw-editor__status'
      ..setAttribute('data-testid', 'tw-status');

    final left = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__status-left';
    state
      ..textContent = initialState
      ..setAttribute('data-testid', 'tw-save-state');
    page.textContent = initialPage;
    words.textContent = initialWords;
    mode
      ..textContent = initialMode
      ..setAttribute('data-testid', 'tw-status-mode');
    left
      ..appendChild(state)
      ..appendChild(page)
      ..appendChild(words)
      ..appendChild(mode);

    final zoom = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__zoom'
      ..appendChild(
        document.createElement('span') as web.HTMLElement..textContent = 'Zoom',
      );
    zoomInput
      ..type = 'range'
      ..min = '50'
      ..max = '200'
      ..step = '5'
      ..value = zoomPercent.toString()
      ..setAttribute('aria-label', 'Zoom');
    zoomInput.addEventListener(
      'input',
      ((web.Event _) {
        final value = double.tryParse(zoomInput.value);
        if (value != null) onZoomChanged(value / 100);
      }).toJS,
    );
    zoomLabel
      ..className = 'tw-editor__zoom-percent'
      ..textContent = '$zoomPercent%';
    zoom
      ..appendChild(zoomInput)
      ..appendChild(zoomLabel);

    final right = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__status-right'
      ..appendChild(
          buttonBuilder('zoom-out', 'Reduzir zoom', onZoomOut, wide: true))
      ..appendChild(zoom)
      ..appendChild(
          buttonBuilder('zoom-in', 'Aumentar zoom', onZoomIn, wide: true));
    element
      ..appendChild(left)
      ..appendChild(right);
  }

  /// Root `<footer>` element (`.tw-editor__status`).
  final web.HTMLElement element;

  /// Mutable save/operation state label.
  final web.HTMLElement state;

  /// Mutable page-position label.
  final web.HTMLElement page;

  /// Mutable word-count label.
  final web.HTMLElement words;

  /// Mutable document-view mode label.
  final web.HTMLElement mode;

  /// Range input that selects the zoom percentage.
  final web.HTMLInputElement zoomInput;

  /// Mutable textual zoom percentage label.
  final web.HTMLElement zoomLabel;
}
