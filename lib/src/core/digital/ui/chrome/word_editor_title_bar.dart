/// Reusable title bar for the embeddable Word editor chrome.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Creates a command button owned and styled by the editor orchestrator.
///
/// The chrome deliberately does not know how commands are represented. This
/// keeps icon choice, keyboard-selection preservation and command registration
/// in the orchestrator while this component only owns title-bar structure.
typedef WordEditorChromeButtonBuilder = web.HTMLButtonElement Function(
  String id,
  String label,
  void Function() action, {
  bool wide,
});

/// DOM component for the Word editor title bar.
///
/// The public element references allow the shell to update its presentation
/// without querying through the whole editor root. The component intentionally
/// accepts a button builder rather than embedding icon data or styling.
final class WordEditorTitleBar {
  WordEditorTitleBar({
    required web.Document document,
    required String initialTitle,
    required void Function(String title) onTitleChanged,
    required void Function() onUndo,
    required void Function() onRedo,
    required WordEditorChromeButtonBuilder buttonBuilder,
    String initialSaveState = 'Salvo',
    String initialMode = 'Edição',
  })  : titleInput = document.createElement('input') as web.HTMLInputElement,
        saveState = document.createElement('span') as web.HTMLElement,
        mode = document.createElement('span') as web.HTMLElement,
        element = document.createElement('header') as web.HTMLElement {
    element.className = 'tw-editor__titlebar';

    final brand = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__brand'
      ..appendChild(
        document.createElement('span') as web.HTMLElement
          ..className = 'tw-editor__brand-mark'
          ..textContent = 'T',
      )
      ..appendChild(
        document.createElement('span') as web.HTMLElement
          ..textContent = 'Taleweaver',
      );
    final quick = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__quick'
      ..appendChild(buttonBuilder('undo', 'Desfazer', onUndo))
      ..appendChild(buttonBuilder('redo', 'Refazer', onRedo));
    final identity = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__identity';

    titleInput
      ..className = 'tw-editor__document-title'
      ..value = initialTitle
      ..setAttribute('aria-label', 'Nome do documento');
    titleInput.addEventListener(
      'change',
      ((web.Event _) => onTitleChanged(titleInput.value)).toJS,
    );

    final saveDot = document.createElement('span') as web.HTMLElement
      ..className = 'tw-editor__save-dot';
    saveState
      ..className = 'tw-editor__save-state'
      ..appendChild(saveDot)
      ..appendChild(
        document.createElement('span') as web.HTMLElement
          ..textContent = initialSaveState,
      );
    identity
      ..appendChild(titleInput)
      ..appendChild(saveState);

    mode
      ..className = 'tw-editor__mode'
      ..textContent = initialMode;
    element
      ..appendChild(brand)
      ..appendChild(quick)
      ..appendChild(identity)
      ..appendChild(mode);
  }

  /// Root `<header>` element (`.tw-editor__titlebar`).
  final web.HTMLElement element;

  /// Editable document name input.
  final web.HTMLInputElement titleInput;

  /// Save-state wrapper containing the dot and its mutable label.
  final web.HTMLElement saveState;

  /// Current editing-mode label in the title bar.
  final web.HTMLElement mode;
}
