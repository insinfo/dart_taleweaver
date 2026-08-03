/// Reusable navigation and panel host for the embeddable Word ribbon.
library;

import 'dart:collection';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Immutable description of a ribbon tab.
///
/// When [contextual] is true, the tab receives the existing contextual classes.
/// [contextClass] is the suffix used by that modifier; when omitted, [id] is
/// used so a `table` tab remains `tw-editor__tab--contextual-table`.
final class WordEditorRibbonTab {
  const WordEditorRibbonTab(
    this.id,
    this.label, {
    this.contextual = false,
    this.contextClass,
  })  : assert(id != ''),
        assert(label != ''),
        assert(contextClass == null || contextClass != '');

  /// Stable identifier shared with the matching ribbon panel.
  final String id;

  /// Visible, accessible tab name.
  final String label;

  /// Whether the tab appears only in a contextual editing state.
  final bool contextual;

  /// Optional suffix for the contextual modifier class.
  final String? contextClass;
}

/// The two sibling DOM elements that make up the Word ribbon chrome.
///
/// The existing shell deliberately places the tab list and ribbon panels as
/// sibling elements, rather than adding another layout wrapper.
final class WordEditorRibbonMarkup {
  const WordEditorRibbonMarkup({
    required this.tabs,
    required this.ribbon,
  });

  /// `<nav class="tw-editor__tabs">` tab list.
  final web.HTMLElement tabs;

  /// `<div class="tw-editor__ribbon">` panel container.
  final web.HTMLElement ribbon;
}

/// DOM-only Word ribbon controller.
///
/// Panels are created by the editor shell, so this class has no dependency on
/// document commands, icons, or presentation rules. It only mounts the known
/// panel elements and keeps their selected state in sync with the tab buttons.
final class WordEditorRibbon {
  WordEditorRibbon({
    required web.Document document,
    required Iterable<WordEditorRibbonTab> tabs,
    required Map<String, web.HTMLElement> panels,
    required String initialTab,
    required void Function(String id) onTabActivated,
  })  : _document = document,
        _tabs = List<WordEditorRibbonTab>.unmodifiable(tabs),
        _panels = UnmodifiableMapView<String, web.HTMLElement>(
          Map<String, web.HTMLElement>.of(panels),
        ),
        _activeTab = initialTab,
        _onTabActivated = onTabActivated {
    final byId = <String, WordEditorRibbonTab>{};
    for (final tab in _tabs) {
      if (byId.containsKey(tab.id)) {
        throw ArgumentError.value(
            tab.id, 'tabs', 'IDs de aba devem ser únicos.');
      }
      if (!_panels.containsKey(tab.id)) {
        throw ArgumentError.value(
          tab.id,
          'panels',
          'Toda aba deve possuir um painel com o mesmo ID.',
        );
      }
      byId[tab.id] = tab;
    }
    if (!byId.containsKey(initialTab)) {
      throw ArgumentError.value(
        initialTab,
        'initialTab',
        'A aba inicial precisa estar na lista de abas.',
      );
    }
    _tabsById = UnmodifiableMapView<String, WordEditorRibbonTab>(byId);
  }

  final web.Document _document;
  final List<WordEditorRibbonTab> _tabs;
  final Map<String, web.HTMLElement> _panels;
  final void Function(String id) _onTabActivated;
  final Map<String, web.HTMLButtonElement> _buttons = {};
  late final Map<String, WordEditorRibbonTab> _tabsById;

  WordEditorRibbonMarkup? _markup;
  String _activeTab;

  /// Identifier of the currently selected tab.
  String get activeTab => _activeTab;

  /// Whether [id] identifies a tab managed by this ribbon.
  bool containsTab(String id) => _tabsById.containsKey(id);

  /// Returns the prebuilt panel associated with [id], if present.
  web.HTMLElement? panelFor(String id) => _panels[id];

  /// Builds the sibling tab navigation and panel container once.
  ///
  /// Calling this method again returns the original DOM elements and does not
  /// register duplicate event listeners or move panels between containers.
  WordEditorRibbonMarkup build() {
    final existing = _markup;
    if (existing != null) return existing;

    final tabs = _document.createElement('nav') as web.HTMLElement
      ..className = 'tw-editor__tabs'
      ..setAttribute('role', 'tablist')
      ..setAttribute('aria-label', 'Faixas de opções')
      ..setAttribute('data-testid', 'tw-ribbon-tabs');
    for (final tab in _tabs) {
      final button = _document.createElement('button') as web.HTMLButtonElement
        ..className = _tabClassName(tab)
        ..type = 'button'
        ..textContent = tab.label
        ..setAttribute('role', 'tab')
        ..setAttribute('data-testid', 'tw-ribbon-tab-${tab.id}')
        ..setAttribute('aria-selected', '${tab.id == _activeTab}');
      button.addEventListener(
        'click',
        ((web.Event _) => activate(tab.id)).toJS,
      );
      _buttons[tab.id] = button;
      tabs.appendChild(button);
    }

    final ribbon = _document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__ribbon'
      ..setAttribute('data-testid', 'tw-ribbon');
    for (final tab in _tabs) {
      final panel = _panels[tab.id]!;
      panel.classList.toggle(
        'tw-editor__ribbon-panel--active',
        tab.id == _activeTab,
      );
      ribbon.appendChild(panel);
    }

    final markup = WordEditorRibbonMarkup(tabs: tabs, ribbon: ribbon);
    _markup = markup;
    return markup;
  }

  /// Selects [id], synchronizes the tab/panel DOM, then notifies the shell.
  ///
  /// Unknown IDs and a request for the already-active tab are harmless no-ops,
  /// matching the editor's existing ribbon interaction behaviour.
  void activate(String id) {
    if (!containsTab(id) || id == _activeTab) return;
    _activeTab = id;
    for (final entry in _panels.entries) {
      entry.value.classList.toggle(
        'tw-editor__ribbon-panel--active',
        entry.key == id,
      );
    }
    for (final entry in _buttons.entries) {
      entry.value.setAttribute('aria-selected', '${entry.key == id}');
    }
    _onTabActivated(id);
  }

  String _tabClassName(WordEditorRibbonTab tab) {
    final classes = <String>[
      'tw-editor__tab',
      if (tab.id == 'file') 'tw-editor__tab--file',
      if (tab.contextual) 'tw-editor__tab--contextual',
      if (tab.contextual)
        'tw-editor__tab--contextual-${tab.contextClass ?? tab.id}',
    ];
    return classes.join(' ');
  }
}
