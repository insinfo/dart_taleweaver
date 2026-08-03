/// Embeddable, Word-style editor shell for Taleweaver.
///
/// Applications mount one object into their own element.  The shell owns its
/// DOM, scoped stylesheet, command ribbon and lifecycle; callers keep owning
/// the document state through [DigitalEditorController] and callbacks.  It
/// has no AngularDart dependency, so it can be created from `ngAfterViewInit`
/// just as it can from a plain Dart web entry point.
library taleweaver_word_editor;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

export 'ui/word_editor_assets.dart';
export 'ui/word_editor_icons.dart';

import '../cascade/attr_registry.dart';
import '../cascade/builtin_attrs.dart';
import '../components/component_registry.dart';
import '../editor/editor_action.dart';
import '../editor/editor_state.dart';
import '../state/block.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/block_traversal.dart';
import '../state/document_order.dart';
import '../state/drawing.dart';
import '../state/find_matches.dart';
import '../state/inline_content.dart';
import '../state/history.dart';
import '../state/list_defs.dart';
import '../state/page_config.dart';
import '../state/serialize/quill_delta_codec.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import '../state/table_context.dart';
import '../styles/tab_stops.dart';
import '../url_safety.dart';
import 'digital_editor_host.dart';
import 'digital_editor_host_config.dart';
import 'editor_controller.dart';
import 'ui/word_editor_assets.dart';
import 'ui/chrome/word_editor_status_bar.dart';
import 'ui/chrome/word_editor_title_bar.dart';
import 'ui/ribbon/word_editor_ribbon.dart';
import 'ui/word_editor_icons.dart';
import 'word_pagination.dart';

part 'ui/chrome/word_editor_rulers.dart';
part 'ui/ribbon/word_editor_ribbon_panels.dart';
part 'ui/chrome/word_editor_dialogs.dart';
part 'ui/chrome/word_editor_file_commands.dart';

/// Whether the document is editable or is presented as a reader.
enum TaleweaverEditorMode { editor, viewer }

/// Amount of chrome around the document surface.
enum TaleweaverEditorAppearance { word, compact }

/// Browser-flow document presentation offered by the digital backend.
///
/// [paginated] keeps one authoritative contenteditable DOM tree while a
/// browser-flow pagination controller creates physical page breaks, repeated
/// template projections and page gaps around it. [continuous] removes those
/// decorations and presents the same document as an ordinary web flow.
enum TaleweaverDocumentView { paginated, continuous }

typedef TaleweaverSaveCallback = void Function(EditorState state);
typedef TaleweaverExportCallback = void Function(
    EditorState state, String format);
typedef TaleweaverEditorOpenFileCallback = FutureOr<void> Function(
  TaleweaverEditorFileRequest request,
);
typedef TaleweaverEditorDeltaExportCallback = FutureOr<void> Function(
  TaleweaverEditorExportRequest request,
);
typedef TaleweaverEditorStateCallback = void Function(EditorState state);
typedef TaleweaverEditorModeCallback = void Function(TaleweaverEditorMode mode);
typedef TaleweaverDocumentViewCallback = void Function(
    TaleweaverDocumentView view);
typedef TaleweaverZoomCallback = void Function(double zoom);

/// File selected by the built-in **Arquivo** ribbon commands.
///
/// Taleweaver deliberately keeps DOCX and Quill-Delta codecs as optional
/// adapters: a host can choose its supported converter and then call
/// [TaleweaverEditor.replaceDocument] with the imported editor state. This
/// avoids silently accepting a DOCX and losing unsupported document data.
class TaleweaverEditorFileRequest {
  final TaleweaverEditor editor;
  final web.File file;
  final String format;

  const TaleweaverEditorFileRequest({
    required this.editor,
    required this.file,
    required this.format,
  });
}

/// Snapshot handed to the host when it exports a Quill Delta.
class TaleweaverEditorExportRequest {
  final TaleweaverEditor editor;
  final EditorState state;
  final String format;

  const TaleweaverEditorExportRequest({
    required this.editor,
    required this.state,
    required this.format,
  });
}

/// A heading entry shown in the Word-style style gallery.
///
/// Applications may replace [TaleweaverEditorOptions.headingStyles] to use
/// their own naming convention (for example, "Cláusula" or "Capítulo") while
/// still producing semantic H1–H6 blocks in the document.
class TaleweaverHeadingStyle {
  final String id;
  final String label;
  final String description;
  final int level;

  const TaleweaverHeadingStyle({
    required this.id,
    required this.label,
    required this.level,
    this.description = 'Título',
  })  : assert(id != ''),
        assert(level >= 1 && level <= 6);
}

/// Configuration for [TaleweaverEditor].
///
/// A host application normally needs only:
///
/// ```dart
/// final editor = TaleweaverEditor.mount(host,
///   options: const TaleweaverEditorOptions(appearance: TaleweaverEditorAppearance.word),
/// );
/// ```
class TaleweaverEditorOptions {
  final TaleweaverEditorMode mode;
  final TaleweaverEditorAppearance appearance;
  final TaleweaverDocumentView documentView;
  final String height;
  final String? width;
  final String documentTitle;

  /// BCP-47 language tag applied to the editor root for browser spellcheck and
  /// assistive technology. The built-in chrome currently ships in pt-BR.
  final String locale;
  final String placeholder;
  final List<TaleweaverHeadingStyle> headingStyles;
  final TaleweaverEditorAssets assets;
  final bool showToolbar;
  final bool showRulers;
  final bool showStatusBar;
  final bool showTitleBar;
  final double zoom;
  final PageConfig pageConfig;
  final EditorConfig editorConfig;
  final ComponentRegistry? componentRegistry;
  final AttrRegistry? attrRegistry;
  final SuggestionView suggestionView;
  final DigitalEditorController? controller;
  final EditorState? initialEditorState;
  final String? initialText;

  /// CSS custom properties applied only to this editor root. Use this for
  /// branding such as `--tw-accent`, `--tw-canvas` and `--tw-paper`; no
  /// consumer stylesheet needs to know the shell's internal markup.
  final Map<String, String> themeVariables;

  /// Ordinary styles applied to the host supplied by the application. This
  /// is useful for host sizing in a framework layout and is restored by
  /// [TaleweaverEditor.destroy].
  final Map<String, String> hostStyles;

  /// Fires only when document content/structure changes.
  final TaleweaverEditorStateCallback? onChanged;

  /// Fires for any state transition, including a selection-only movement.
  final TaleweaverEditorStateCallback? onStateChanged;
  final void Function(Selection selection)? onSelectionChanged;
  final TaleweaverSaveCallback? onSave;
  final TaleweaverExportCallback? onExport;
  final TaleweaverEditorOpenFileCallback? onOpenDocx;
  final TaleweaverEditorOpenFileCallback? onOpenDelta;
  final TaleweaverEditorDeltaExportCallback? onExportDelta;
  final void Function(String title)? onTitleChanged;
  final TaleweaverEditorModeCallback? onModeChanged;
  final TaleweaverDocumentViewCallback? onDocumentViewChanged;
  final TaleweaverZoomCallback? onZoomChanged;

  const TaleweaverEditorOptions({
    this.mode = TaleweaverEditorMode.editor,
    this.appearance = TaleweaverEditorAppearance.word,
    this.documentView = TaleweaverDocumentView.paginated,
    this.height = '720px',
    this.width,
    this.documentTitle = 'Documento sem título',
    this.locale = 'pt-BR',
    this.placeholder = 'Comece a escrever',
    this.assets = const TaleweaverEditorAssets(),
    this.headingStyles = const [
      TaleweaverHeadingStyle(
        id: 'heading-1',
        label: 'Título 1',
        description: 'Título principal',
        level: 1,
      ),
      TaleweaverHeadingStyle(
        id: 'heading-2',
        label: 'Título 2',
        description: 'Subseção',
        level: 2,
      ),
      TaleweaverHeadingStyle(
        id: 'heading-3',
        label: 'Título 3',
        description: 'Subseção menor',
        level: 3,
      ),
    ],
    this.showToolbar = true,
    this.showRulers = true,
    this.showStatusBar = true,
    this.showTitleBar = false,
    this.zoom = 1,
    this.pageConfig = const PageConfig(),
    this.editorConfig = const EditorConfig(),
    this.componentRegistry,
    this.attrRegistry,
    this.suggestionView = SuggestionView.suggesting,
    this.controller,
    this.initialEditorState,
    this.initialText,
    this.themeVariables = const {},
    this.hostStyles = const {},
    this.onChanged,
    this.onStateChanged,
    this.onSelectionChanged,
    this.onSave,
    this.onExport,
    this.onOpenDocx,
    this.onOpenDelta,
    this.onExportDelta,
    this.onTitleChanged,
    this.onModeChanged,
    this.onDocumentViewChanged,
    this.onZoomChanged,
  });
}

/// Complete embeddable Taleweaver editor with optional Word-like chrome.
class TaleweaverEditor {
  final web.HTMLElement host;
  final TaleweaverEditorOptions options;

  /// Always create chrome in the host's owning document so iframe and
  /// framework-owned document roots embed correctly.
  web.Document get _document => host.ownerDocument ?? web.document;

  late final web.HTMLElement root;
  late final web.HTMLElement documentSurface;
  late final web.HTMLElement _workspace;
  late final web.HTMLElement _page;
  late final web.HTMLElement _verticalRuler;
  late final web.HTMLElement _verticalRulerTicks;
  late final web.HTMLElement _horizontalRulerViewport;
  late final web.HTMLElement _horizontalRuler;
  late final web.HTMLElement _horizontalRulerTicks;
  late final web.HTMLElement _horizontalRulerTabs;
  late final web.HTMLElement _horizontalMarginStart;
  late final web.HTMLElement _horizontalMarginEnd;
  late final web.HTMLElement _verticalMarginStart;
  late final web.HTMLElement _verticalMarginEnd;
  late final web.HTMLButtonElement _rulerTabSelector;
  late final web.HTMLElement _headerSurface;
  late final web.HTMLElement _footerSurface;
  late final web.HTMLElement _statusState;
  late final web.HTMLElement _statusPage;
  late final web.HTMLElement _statusWords;
  late final web.HTMLElement _statusMode;
  late final web.HTMLInputElement _titleInput;
  late final web.HTMLInputElement _zoomInput;
  late final web.HTMLElement _zoomLabel;
  late final DigitalEditorHost _documentHost;
  late final DigitalEditorController _controller;
  late final PageConfig _effectivePageConfig;
  late final WordPaginationController _pagination;
  late final TaleweaverEditorAssetLease _assetLease;
  DigitalEditorHost? _headerHost;
  DigitalEditorHost? _footerHost;
  BlockId? _headerBodyId;
  BlockId? _footerBodyId;
  web.HTMLElement? _dialog;
  final Map<String, ({String value, String priority})> _hostStylesBefore = {};

  final Map<String, web.HTMLButtonElement> _commands = {};
  final Map<String, web.HTMLElement> _rulerHandles = {};
  final Map<String, double> _rulerPreview = {};
  web.HTMLSelectElement? _fontFamily;
  web.HTMLSelectElement? _fontSize;
  WordEditorRibbon? _ribbonChrome;
  WordEditorRibbonMarkup? _ribbonMarkup;
  String _activeTab = 'home';
  TaleweaverEditorMode _mode;
  TaleweaverDocumentView _documentView;
  double _zoom;
  int _physicalPageCount = 1;
  int? _rulerAnimationFrame;
  int? _templateOverlayAnimationFrame;
  EditorState? _templateOverlayState;
  web.ResizeObserver? _rulerResizeObserver;
  _RulerDrag? _rulerDrag;
  TabAlignment _newTabAlignment = TabAlignment.left;
  PageConfig? _rulerPageConfig;
  bool _wasInImageContext = false;
  bool _wasInDrawingContext = false;
  // The browser moves focus to native ribbon controls (especially <select>)
  // before their change event is delivered. Keep the last document selection
  // so a formatting command always targets the text the user had selected,
  // rather than a transient focus inside the Ribbon.
  Selection? _lastRibbonSelection;
  bool _destroyed = false;
  bool _dirty = false;

  TaleweaverEditor._(this.host, this.options)
      : _mode = options.mode,
        _documentView = options.documentView,
        _zoom = options.zoom.clamp(.5, 2.0).toDouble() {
    if (options.controller != null && options.initialEditorState != null) {
      throw ArgumentError(
          'controller e initialEditorState não podem ser usados juntos.');
    }
    if (options.controller != null && options.initialText != null) {
      throw ArgumentError(
          'controller e initialText não podem ser usados juntos.');
    }
    if (options.initialText != null && options.initialEditorState != null) {
      throw ArgumentError(
          'initialText e initialEditorState não podem ser usados juntos.');
    }
    _effectivePageConfig = options.controller?.config.pageConfig ??
        options.editorConfig.pageConfig ??
        options.pageConfig;
    _mount();
  }

  factory TaleweaverEditor.mount(
    web.HTMLElement host, {
    TaleweaverEditorOptions options = const TaleweaverEditorOptions(),
  }) =>
      TaleweaverEditor._(host, options);

  /// The core controller remains public for controlled integrations.
  DigitalEditorController get controller => _controller;
  EditorState get editorState => _documentHost.editorState;
  bool get isDestroyed => _destroyed;
  TaleweaverEditorMode get mode => _mode;
  TaleweaverDocumentView get documentView => _documentView;
  double get zoom => _zoom;
  String get documentTitle => _titleInput.value;

  EditorState dispatch(EditorAction action) {
    _assertAlive();
    return _documentHost.dispatch(action);
  }

  /// Replaces the complete editor snapshot after a host-side import.
  ///
  /// This is the controlled path used by the **Abrir DOCX** and **Abrir
  /// Delta** callbacks. The replacement is propagated to every mounted
  /// surface through the controller rather than mutating the browser DOM.
  EditorState replaceDocument(EditorState state) {
    _assertAlive();
    _dirty = false;
    return _controller.replaceState(state);
  }

  void focus() {
    _assertAlive();
    _documentHost.focus();
  }

  void setMode(TaleweaverEditorMode mode) {
    _assertAlive();
    if (_mode == mode) return;
    _mode = mode;
    root.classList
        .toggle('tw-editor--viewer', mode == TaleweaverEditorMode.viewer);
    if (mode == TaleweaverEditorMode.viewer) _closeDialog();
    _documentHost.setReadOnly(mode == TaleweaverEditorMode.viewer);
    _headerHost?.setReadOnly(mode == TaleweaverEditorMode.viewer);
    _footerHost?.setReadOnly(mode == TaleweaverEditorMode.viewer);
    _syncChrome(editorState);
    options.onModeChanged?.call(mode);
  }

  void setDocumentView(TaleweaverDocumentView view) {
    _assertAlive();
    if (_documentView == view) return;
    _documentView = view;
    root.classList.toggle(
        'tw-editor--continuous', view == TaleweaverDocumentView.continuous);
    root.classList.toggle(
        'tw-editor--physical-pages', view == TaleweaverDocumentView.paginated);
    _pagination.setEnabled(view == TaleweaverDocumentView.paginated);
    _syncSectionPaginationChrome(editorState);
    _scheduleSectionTemplateOverlay(editorState);
    _syncChrome(editorState);
    options.onDocumentViewChanged?.call(view);
  }

  void setZoom(double value) {
    _assertAlive();
    final previous = _zoom;
    _zoom = value.clamp(.5, 2.0).toDouble();
    _page.style.setProperty('zoom', _zoom.toStringAsFixed(2));
    // CSS zoom changes DOMRect measurements but not the CSS-pixel values
    // used to construct browser-flow page decorations. Keep the paginator in
    // its layout coordinate system so zoom is purely visual.
    _pagination.setVisualScale(_zoom);
    _zoomInput.value = (_zoom * 100).round().toString();
    _zoomLabel.textContent = '${(_zoom * 100).round()}%';
    _scheduleRulerLayout();
    _scheduleSectionTemplateOverlay(editorState);
    if (previous != _zoom) options.onZoomChanged?.call(_zoom);
  }

  /// Updates the document label owned by the title bar.
  void setDocumentTitle(String title, {bool notify = true}) {
    _assertAlive();
    _titleInput.value = title;
    if (notify) options.onTitleChanged?.call(title);
  }

  void setRulersVisible(bool visible) {
    _assertAlive();
    root.classList.toggle('tw-editor--no-rulers', !visible);
    if (visible) _scheduleRulerLayout();
  }

  void setStatusBarVisible(bool visible) {
    _assertAlive();
    root.classList.toggle('tw-editor--no-status', !visible);
  }

  void _toggleSectionOrientation() {
    if (_mode != TaleweaverEditorMode.editor) return;
    if (_activeSectionForState(editorState) == null) {
      _statusState.textContent =
          'Insira uma quebra de seção antes de mudar a orientação.';
      return;
    }
    dispatch(const ToggleSectionLandscapeAction());
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    final frame = _rulerAnimationFrame;
    if (frame != null) web.window.cancelAnimationFrame(frame);
    _rulerAnimationFrame = null;
    final templateFrame = _templateOverlayAnimationFrame;
    if (templateFrame != null) web.window.cancelAnimationFrame(templateFrame);
    _templateOverlayAnimationFrame = null;
    _rulerResizeObserver?.disconnect();
    _rulerResizeObserver = null;
    _pagination.destroy();
    _headerHost?.destroy();
    _footerHost?.destroy();
    _documentHost.destroy();
    _closeDialog();
    root.remove();
    _assetLease.release();
    _restoreHostStyles();
  }

  void _mount() {
    for (final entry in options.hostStyles.entries) {
      _hostStylesBefore[entry.key] = (
        value: host.style.getPropertyValue(entry.key),
        priority: host.style.getPropertyPriority(entry.key),
      );
      host.style.setProperty(entry.key, entry.value);
    }
    root = _element('section', 'tw-editor')
      ..setAttribute('data-taleweaver-editor-root', '')
      ..setAttribute('data-testid', 'tw-editor')
      ..setAttribute('role', 'application')
      ..setAttribute('aria-label', 'Editor Taleweaver')
      ..setAttribute('lang', options.locale);
    root.style.height = options.height;
    if (options.width != null) root.style.width = options.width!;
    root.style.setProperty('--tw-icon-font', options.assets.iconFontFamily);
    for (final entry in options.themeVariables.entries) {
      if (entry.key.startsWith('--')) {
        root.style.setProperty(entry.key, entry.value);
      }
    }
    root.classList
      ..toggle('tw-editor--compact',
          options.appearance == TaleweaverEditorAppearance.compact)
      ..toggle('tw-editor--viewer', _mode == TaleweaverEditorMode.viewer)
      ..toggle('tw-editor--continuous',
          _documentView == TaleweaverDocumentView.continuous)
      ..toggle('tw-editor--physical-pages',
          _documentView == TaleweaverDocumentView.paginated)
      ..toggle('tw-editor--no-toolbar', !options.showToolbar)
      ..toggle('tw-editor--no-rulers', !options.showRulers)
      ..toggle('tw-editor--no-status', !options.showStatusBar)
      ..toggle('tw-editor--no-titlebar', !options.showTitleBar);
    _setPageMetrics();
    _assetLease = acquireTaleweaverEditorAssets(_document, options.assets);

    final shell = _element('div', 'tw-editor__shell');
    shell
      ..appendChild(_buildTitleBar())
      ..appendChild(_buildTabs())
      ..appendChild(_buildRibbon())
      ..appendChild(_buildRulers())
      ..appendChild(_buildWorkspace())
      ..appendChild(_buildStatusBar());
    root.appendChild(shell);
    host.appendChild(root);

    _controller = options.controller ??
        DigitalEditorController(
          initial: options.initialEditorState,
          config: _effectiveEditorConfig(),
        );
    final text = options.initialText;
    if (options.controller == null && text != null && text.isNotEmpty) {
      _controller.dispatch(PasteTextAction(text));
    }
    _documentHost = DigitalEditorHost.mount(
      documentSurface,
      config: DigitalEditorHostConfig(
        componentRegistry: options.componentRegistry,
        attrRegistry: options.attrRegistry,
        editorConfig: _effectiveEditorConfig(),
        readOnly: _mode == TaleweaverEditorMode.viewer,
        suggestionView: options.suggestionView,
        surfaceClassName: 'tw-editor__document',
        ariaLabel: 'Conteúdo do documento',
        surfaceAttributes: {
          'data-testid': 'tw-editor-surface',
          'data-placeholder': options.placeholder,
        },
        onChange: _handleDocumentChange,
        onStateChange: _handleStateChange,
        onSelectionChange: _handleSelectionChange,
      ),
      controller: _controller,
    );
    _installObjectSelectionHandler();
    _syncTemplateSurfaces(editorState);
    _pagination = WordPaginationController(
      surface: _documentHost.surface,
      document: _document,
      components: options.componentRegistry ??
          _controller.config.componentRegistry ??
          createDefaultComponentRegistry(),
      attrs: options.attrRegistry ?? createDefaultAttrRegistry(),
      suggestionView: options.suggestionView,
      metrics: _paginationMetrics(),
      renderRoot: () => _documentHost.renderRoot,
      sectionProfiles: _paginationSectionProfiles,
      headerBodyId: () => _headerBodyId,
      footerBodyId: () => _footerBodyId,
      onPageCountChanged: _handlePhysicalPageCount,
    )..mount(
        editorState,
        enabled: _documentView == TaleweaverDocumentView.paginated,
      );
    _installRulerObservers();
    _syncRulers(editorState, _pageConfigForState(editorState));
    setZoom(_zoom);
    _syncSectionPaginationChrome(editorState);
    _scheduleSectionTemplateOverlay(editorState);
    _syncChrome(editorState);
  }

  EditorConfig _effectiveEditorConfig() {
    // A supplied controller is the source of truth for reducer behaviour.
    // The shell mirrors its page setup so rulers, paper and section actions
    // never disagree with the document being controlled by the host app.
    final source = options.controller?.config ?? options.editorConfig;
    return EditorConfig(
      containerWidth: source.containerWidth,
      now: source.now,
      suggestingAuthor: source.suggestingAuthor,
      componentRegistry: options.componentRegistry ?? source.componentRegistry,
      pageConfig: _effectivePageConfig,
    );
  }

  void _setPageMetrics([PageConfig? pageConfig]) {
    final page = pageConfig ?? _effectivePageConfig;
    double px(double points) => points * 96 / 72;
    root.style
      ..setProperty('--tw-page-width', '${px(page.width).toStringAsFixed(2)}px')
      ..setProperty(
          '--tw-page-height', '${px(page.height).toStringAsFixed(2)}px')
      ..setProperty(
          '--tw-margin-top', '${px(page.margins.top).toStringAsFixed(2)}px')
      ..setProperty(
          '--tw-margin-right', '${px(page.margins.right).toStringAsFixed(2)}px')
      ..setProperty('--tw-margin-bottom',
          '${px(page.margins.bottom).toStringAsFixed(2)}px')
      ..setProperty(
          '--tw-margin-left', '${px(page.margins.left).toStringAsFixed(2)}px');
  }

  WordPaginationMetrics _paginationMetrics([PageConfig? pageConfig]) {
    final page = pageConfig ?? _effectivePageConfig;
    double px(double points) => points * 96 / 72;
    return WordPaginationMetrics(
      pageWidth: px(page.width),
      pageHeight: px(page.height),
      marginTop: px(page.margins.top),
      marginRight: px(page.margins.right),
      marginBottom: px(page.margins.bottom),
      marginLeft: px(page.margins.left),
      headerFooterGap: px(page.headerFooterGap),
    );
  }

  /// Resolves the paper currently represented by the Word shell.
  ///
  /// Page setup is intentionally document data: a root setup supplies the
  /// defaults and an enclosing section can override size and margins. This
  /// lets the ribbon and rulers reflect an undoable `SetActivePageMarginsAction`
  /// rather than a local CSS-only illusion.
  PageConfig _pageConfigForState(EditorState state) =>
      _pageConfigForSection(state, _activeSectionForState(state));

  /// Root-only setup is the stable fallback for a document without explicit
  /// sections. It must not follow the active caret: section pagers receive
  /// their own profile instead.
  PageConfig _rootPageConfigForState(EditorState state) =>
      _pageConfigForSection(state, null);

  PageConfig _pageConfigForSection(EditorState state, Block? section) {
    final root = getBlock(state.state, state.state.rootId);
    var width = _effectivePageConfig.width;
    var height = _effectivePageConfig.height;
    var margins = _effectivePageConfig.margins;

    void applyPageAttrs(Block? owner, {bool allowSize = true}) {
      if (owner == null) return;
      if (allowSize) {
        final inline = owner.attrs['pageInlineSize'];
        final block = owner.attrs['pageBlockSize'];
        if (inline is num && inline.isFinite && inline > 0) {
          width = inline.toDouble();
        }
        if (block is num && block.isFinite && block > 0) {
          height = block.toDouble();
        }
      }
      final resolvedMargins = _pageMarginsFromAttrs(owner.attrs['pageMargins'],
          fallback: margins, pageWidth: width, pageHeight: height);
      margins = resolvedMargins;
    }

    // Root is inherited by each explicit section. Explicit section values are
    // applied afterwards, matching the reducer's active-section target.
    applyPageAttrs(root);
    if (section != null && section.id != root?.id) applyPageAttrs(section);
    return PageConfig(
      width: width,
      height: height,
      margins: margins,
      headerFooterGap: _effectivePageConfig.headerFooterGap,
    );
  }

  /// Builds immutable browser profiles for every direct explicit section.
  ///
  /// Deliberately returns an empty list for a mixed root tree: the legacy
  /// single-page projection remains safer until the document is represented
  /// entirely by section wrappers. Section breaks created by the editor do
  /// exactly that, so normal multi-section documents take this path.
  List<WordPaginationSectionProfile> _paginationSectionProfiles(
    EditorState state,
  ) {
    final root = getBlock(state.state, state.state.rootId);
    if (root == null || root.firstChildId == null) {
      return const <WordPaginationSectionProfile>[];
    }
    final profiles = <WordPaginationSectionProfile>[];
    var id = root.firstChildId;
    var guard = 0;
    final max = blockCount(state.state) + 1;
    while (id != null) {
      if (++guard > max) return const <WordPaginationSectionProfile>[];
      final section = getBlock(state.state, id);
      if (section == null || section.type != 'section') {
        return const <WordPaginationSectionProfile>[];
      }
      final page = _pageConfigForSection(state, section);
      BlockId? templateId(String attr) {
        final local = section.attrs[attr];
        if (local is String && local.isNotEmpty) return BlockId(local);
        final inherited = root.attrs[attr];
        if (inherited is String && inherited.isNotEmpty) {
          return BlockId(inherited);
        }
        return null;
      }

      profiles.add(WordPaginationSectionProfile(
        sectionId: section.id,
        metrics: _paginationMetrics(page),
        headerBodyId: templateId('headerBlockId'),
        footerBodyId: templateId('footerBlockId'),
      ));
      id = section.nextSiblingId;
    }
    return profiles;
  }

  /// Keeps the outer Word shell in sync with the paginator's independent
  /// section pages. The page chrome itself stays owned by the paginator; this
  /// method only changes the host layout so a landscape section can coexist
  /// with a portrait section without the active caret changing prior pages.
  void _syncSectionPaginationChrome(EditorState state) {
    final sectioned = _documentView == TaleweaverDocumentView.paginated &&
        _paginationSectionProfiles(state).isNotEmpty;
    root.classList.toggle('tw-editor--sectioned-pages', sectioned);

    // In a sectioned document every physical page owns its inert template
    // snapshot, including page one. The legacy editable template portal is
    // therefore hidden while editing ordinary body text; it becomes available
    // only after the ribbon has moved the model selection into a template.
    // This prevents a template from the currently selected section being
    // painted over the first page of a different section.
    final selection = resolveBlock(state.state, state.selection.focus.blockId);
    final editingTemplate = selection?.kind == ResolvedBlockKind.template;
    root.classList.toggle(
      'tw-editor--sectioned-template-editing',
      sectioned && editingTemplate,
    );
    _page.setAttribute(
      'aria-label',
      sectioned ? 'Páginas por seção do documento' : 'Página 1',
    );
  }

  PageMargins _pageMarginsFromAttrs(
    dynamic value, {
    required PageMargins fallback,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (value is! Map) return fallback;
    double? read(String key) {
      final candidate = value[key];
      if (candidate is! num || !candidate.isFinite || candidate < 0) {
        return null;
      }
      return candidate.toDouble();
    }

    final top = read('blockStart');
    final bottom = read('blockEnd');
    final left = read('inlineStart');
    final right = read('inlineEnd');
    if (top == null || bottom == null || left == null || right == null) {
      return fallback;
    }
    // A malformed imported document must never collapse the live editing
    // surface even though the reducer rejects such values for local actions.
    if (left + right >= pageWidth || top + bottom >= pageHeight) {
      return fallback;
    }
    return PageMargins(top: top, right: right, bottom: bottom, left: left);
  }

  /// Returns the section owning the focus, or null when root owns the page
  /// setup. Template selection is mapped back to its owning main-tree section
  /// so header/footer editing still sees the same paper dimensions.
  Block? _activeSectionForState(EditorState state) {
    final resolved = resolveBlock(state.state, state.selection.focus.blockId);
    if (resolved == null) return null;
    if (resolved.kind == ResolvedBlockKind.main) {
      for (final block in ancestorChain(state.state, resolved.block)) {
        if (block.type == 'section') return block;
      }
      return null;
    }
    if (resolved.kind != ResolvedBlockKind.template) return null;
    var templateRoot = resolved.block;
    while (templateRoot.parentId != null) {
      final parent = getTemplateContent(state.state, templateRoot.parentId!);
      if (parent == null) break;
      templateRoot = parent;
    }
    final templateId = templateRoot.id.value;
    for (final block in iterateBlocksInDocumentOrder(state.state)) {
      if (block.type != 'section' && block.id != state.state.rootId) continue;
      if (block.attrs['headerBlockId'] == templateId ||
          block.attrs['footerBlockId'] == templateId) {
        return block.type == 'section' ? block : null;
      }
    }
    return null;
  }

  /// Opens the same persistent page-margin operation exposed by the ruler.
  /// Values are presented in centimetres because that is Word's familiar
  /// page-setup UI in pt-BR locales; the model remains points and JSON-safe.
  void _adjustFontSize(int delta) {
    final attrs = _activeAttrs();
    final current = attrs['fontSize'];
    final size = (current is num ? current.toDouble() : 12) + delta;
    dispatch(SetFontSizeAction(size.clamp(6, 96).toDouble()));
  }

  /// Requests the browser clipboard command only after the controlled surface
  /// restored the saved model selection. The digital host remains the single
  /// implementation of copy serialization and cut deletion.
  void _copySelection() {
    if (_destroyed) return;
    _documentHost.focus();
    if (!_document.execCommand('copy')) {
      _statusState.textContent = 'Use Ctrl+C para copiar a seleção.';
    }
  }

  void _cutSelection() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    _documentHost.focus();
    if (!_document.execCommand('cut')) {
      _statusState.textContent = 'Use Ctrl+X para recortar a seleção.';
    }
  }

  void _activateTab(String tab) {
    final ribbon = _ribbonChrome;
    if (ribbon == null || !ribbon.containsTab(tab)) return;
    ribbon.activate(tab);
  }

  void _handleDocumentChange(EditorState state) {
    if (_destroyed) return;
    _dirty = true;
    options.onChanged?.call(state);
  }

  void _handleStateChange(EditorState state) {
    if (_destroyed) return;
    _lastRibbonSelection = state.selection;
    final page = _pageConfigForState(state);
    _setPageMetrics(page);
    // The active page drives only the ruler/canonical editing overlay. The
    // physical paginator receives all explicit-section profiles separately,
    // so changing selection must never impose this page's geometry on the
    // remaining sections.
    _pagination
        .updateMetrics(_paginationMetrics(_rootPageConfigForState(state)));
    _syncTemplateSurfaces(state);
    _pagination.update(state);
    _syncSectionPaginationChrome(state);
    _scheduleSectionTemplateOverlay(state);
    _syncRulers(state, page);
    _syncChrome(state);
    options.onStateChanged?.call(state);
  }

  void _handleSelectionChange(Selection selection) {
    if (_destroyed) return;
    _lastRibbonSelection = selection;
    options.onSelectionChanged?.call(selection);
  }

  /// Restores the model selection remembered before focus moved into Ribbon
  /// controls. This is intentionally model-only: [DigitalEditorHost] mirrors
  /// it back into the document after the following action/reconciliation.
  void _restoreRibbonSelection() {
    final selection = _lastRibbonSelection;
    if (selection == null ||
        selectionsEqual(selection, editorState.selection)) {
      return;
    }
    dispatch(SetSelectionAction(selection));
  }

  void _handlePhysicalPageCount(int pageCount) {
    if (_destroyed) return;
    _physicalPageCount = pageCount;
    // The first physical page owns the canonical editable template surfaces.
    // Keep PAGE/NUMPAGES in those surfaces in lockstep with the inert clones
    // projected by the paginator for later pages.
    _headerHost?.setTemplatePageValues(1, pageCount);
    _footerHost?.setTemplatePageValues(1, pageCount);
    _scheduleSectionTemplateOverlay(editorState);
    _syncPhysicalPageStatus(editorState);
  }

  void _syncChrome(EditorState state) {
    _setSaveState(_dirty ? 'Alterado' : 'Salvo');
    _statusWords.textContent = '${_wordCount(state)} palavras';
    _syncPhysicalPageStatus(state);
    _statusMode.textContent = _documentView == TaleweaverDocumentView.paginated
        ? 'Layout de impressão'
        : 'Layout web';
    root.querySelector('.tw-editor__mode')?.textContent =
        _mode == TaleweaverEditorMode.viewer ? 'Somente leitura' : 'Edição';
    _titleInput.disabled = _mode == TaleweaverEditorMode.viewer;
    _titleInput.setAttribute('aria-readonly',
        _mode == TaleweaverEditorMode.viewer ? 'true' : 'false');

    final attrs = _activeAttrs(state);
    _setPressed('bold', attrs['bold'] == true);
    _setPressed('italic', attrs['italic'] == true);
    _setPressed('underline', attrs['underline'] == true);
    _setPressed('strikethrough', attrs['strikethrough'] == true);
    final block = _focusBlock(state);
    _setPressed(
        'bullets', block?.type == 'list-item' && _listIsUnordered(block));
    _setPressed(
        'numbering', block?.type == 'list-item' && !_listIsUnordered(block));
    _setPressed(
        'align-left',
        block?.attrs['textAlign'] == 'left' ||
            block?.attrs['textAlign'] == null);
    _setPressed('align-center', block?.attrs['textAlign'] == 'center');
    _setPressed('align-right', block?.attrs['textAlign'] == 'right');
    _setPressed('align-justify', block?.attrs['textAlign'] == 'justify');
    _syncStyleGallery(block);
    _setPressed(
        'view-paginated', _documentView == TaleweaverDocumentView.paginated);
    _setPressed(
        'view-continuous', _documentView == TaleweaverDocumentView.continuous);
    _setPressed('viewer', _mode == TaleweaverEditorMode.viewer);
    _setPressed('editor', _mode == TaleweaverEditorMode.editor);
    _setPressed('rulers', !root.classList.contains('tw-editor--no-rulers'));
    final tableContext = _tableContext(state);
    final image = _activeImageBlock(state);
    final drawing = _activeDrawingBlock(state);
    root.classList.toggle('tw-editor--in-table', tableContext != null);
    root.classList.toggle('tw-editor--in-image', image != null);
    root.classList.toggle('tw-editor--in-drawing', drawing != null);
    _syncImageSelection(image);
    _syncDrawingSelection(drawing);
    if (tableContext == null && _activeTab == 'table') _activateTab('home');
    if (image == null && _activeTab == 'image') _activateTab('home');
    if (drawing == null && _activeTab == 'drawing') _activateTab('home');
    if (image != null && !_wasInImageContext) _activateTab('image');
    if (drawing != null && !_wasInDrawingContext) _activateTab('drawing');
    _wasInImageContext = image != null;
    _wasInDrawingContext = drawing != null;

    _commands['undo']?.disabled = !state.history.canUndo;
    _commands['redo']?.disabled = !state.history.canRedo;
    final inactive = _mode == TaleweaverEditorMode.viewer;
    for (final entry in _commands.entries) {
      if (entry.key == 'undo' || entry.key == 'redo') continue;
      if ({
        'editor',
        'viewer',
        'view-paginated',
        'view-continuous',
        'rulers',
        'copy',
        'zoom-in',
        'zoom-out'
      }.contains(entry.key)) {
        entry.value.disabled = false;
      } else {
        entry.value.disabled = inactive;
      }
    }
    // An externally supplied controller owns the reducer configuration. The
    // page setup shown by the shell remains useful for viewing, but rotation
    // must not present itself as executable when that controller deliberately
    // has no PageConfig (the core action is then a documented no-op).
    _commands['orientation']?.disabled = inactive ||
        (options.controller != null && _controller.config.pageConfig == null);
    const tableCommands = {
      'table-row-above',
      'table-row-below',
      'table-column-left',
      'table-column-right',
      'table-split-cell',
      'table-delete-row',
      'table-delete-column',
      'table-delete',
      'table-header-row',
    };
    for (final command in tableCommands) {
      _commands[command]?.disabled = inactive || tableContext == null;
    }
    _commands['table-split-cell']?.disabled = inactive ||
        tableContext == null ||
        !_canSplitActiveTableCell(state, tableContext);
    final table = tableContext == null
        ? null
        : getBlock(state.state, tableContext.tableId);
    final headerRows = table?.attrs['headerRowCount'];
    _setPressed('table-header-row', headerRows is num && headerRows > 0);

    const imageCommands = {
      'image-align-left',
      'image-align-right',
      'image-wrap-inline',
      'image-size',
      'image-alt',
    };
    for (final command in imageCommands) {
      _commands[command]?.disabled = inactive || image == null;
    }
    final wrap = image?.attrs['wrap'];
    _setPressed('image-align-left', wrap == 'left');
    _setPressed('image-align-right', wrap == 'right');
    _setPressed('image-wrap-inline', wrap == null || wrap == 'break');
    _syncFontControls(attrs);
  }

  /// Synchronizes native selects in both directions. A selected run may use a
  /// custom font or size not present in the starter list; Word shows that
  /// actual value, so retain it as a generated option instead of leaving the
  /// select blank or stale from the previous caret location.
  void _syncFontControls(Map<String, dynamic> attrs) {
    final family = attrs['fontFamily'];
    final familyValue =
        family is String && family.trim().isNotEmpty ? family : 'Calibri';
    _setSelectValue(_fontFamily, familyValue);

    final size = attrs['fontSize'];
    final sizeValue = size is num && size.isFinite && size > 0
        ? size.toStringAsFixed(size == size.roundToDouble() ? 0 : 1)
        : '12';
    _setSelectValue(_fontSize, sizeValue);
  }

  void _setSelectValue(web.HTMLSelectElement? select, String value) {
    if (select == null) return;
    var found = false;
    for (var index = 0; index < select.options.length; index++) {
      final option = select.options.item(index);
      if (option is web.HTMLOptionElement && option.value == value) {
        found = true;
        break;
      }
    }
    if (!found) {
      select.appendChild(_document.createElement('option')
        ..setAttribute('value', value)
        ..textContent = value);
    }
    select.value = value;
  }

  /// Updates the status bar from the actual keyed block under the selection,
  /// rather than assuming that every caret belongs to page one. The paginator
  /// supplies the physical header geometry without reparenting that block.
  void _syncPhysicalPageStatus(EditorState state) {
    if (_documentView != TaleweaverDocumentView.paginated) {
      _statusPage.textContent = 'Fluxo contínuo';
      return;
    }
    final page = _activePhysicalPagePosition(state)?.pageNumber ?? 1;
    _statusPage.textContent = 'Página $page de $_physicalPageCount';
  }

  WordPaginationPagePosition? _activePhysicalPagePosition(EditorState state) {
    // A leaf block can span several pages. Prefer the collapsed focus-range
    // rectangle supplied by the browser, then fall back to the keyed block
    // itself for image/table selections and non-rendered template cursors.
    final caretTop = _selectionCaretTop();
    if (caretTop != null) {
      final fromCaret = _pagination.pagePositionForVisualY(caretTop);
      if (fromCaret != null) return fromCaret;
    }
    final element = _rulerReferenceElement(state);
    return _pagination.pagePositionForElement(element);
  }

  double? _selectionCaretTop() {
    final selection = _documentHost.selectionBridge.window.getSelection();
    final focusNode = selection?.focusNode;
    if (focusNode == null || !_documentHost.surface.contains(focusNode)) {
      return null;
    }
    try {
      final range = _document.createRange()
        ..setStart(focusNode, selection!.focusOffset)
        ..collapse(true);
      final rect = range.getBoundingClientRect();
      return rect.top.isFinite && rect.height >= 0 ? rect.top : null;
    } catch (_) {
      // A browser may reject a stale synthetic selection during DOM
      // reconciliation. The keyed-block fallback remains safe in that frame.
      return null;
    }
  }

  /// The main editing host has one element per model block. A template block
  /// is mounted in a separate host, so use its owning section as the ruler
  /// anchor in that case. This keeps the ruler on the selected section's
  /// paper even while a header/footer is being edited.
  web.HTMLElement? _rulerReferenceElement(EditorState state) {
    final direct = _documentHost.blockElement(state.selection.focus.blockId);
    if (direct != null) return direct;
    final section = _activeSectionForState(state);
    if (section != null) return _documentHost.blockElement(section.id);
    return _page;
  }

  /// Word's paragraph controls describe the first paragraph in a selected
  /// range, not whichever endpoint happened to keep focus after a command.
  /// Object selections and template selections retain their explicit focus
  /// edge because they are not comparable in the main document order.
  Position _selectionContextPosition([EditorState? state]) {
    final current = state ?? editorState;
    final selection = current.selection;
    if (isCollapsed(selection)) return selection.focus;
    final anchor = resolveBlock(current.state, selection.anchor.blockId);
    final focus = resolveBlock(current.state, selection.focus.blockId);
    if (anchor?.kind == ResolvedBlockKind.main &&
        focus?.kind == ResolvedBlockKind.main) {
      return spanStart(current.state, selection);
    }
    if (selection.anchor.blockId == selection.focus.blockId &&
        selection.focus.offset < selection.anchor.offset) {
      return selection.focus;
    }
    return selection.anchor;
  }

  Block? _focusBlock([EditorState? state]) {
    final current = state ?? editorState;
    return resolveBlock(
            current.state, _selectionContextPosition(current).blockId)
        ?.block;
  }

  void _syncStyleGallery(Block? block) {
    final rawLevel = block?.type == 'heading' ? block?.attrs['level'] : null;
    final activeLevel = rawLevel is num &&
            rawLevel.isFinite &&
            rawLevel.truncateToDouble() == rawLevel &&
            rawLevel >= 1 &&
            rawLevel <= 6
        ? rawLevel.toInt()
        : 0;
    final buttons = root.querySelectorAll('[data-tw-style-level]');
    for (var index = 0; index < buttons.length; index++) {
      final button = buttons.item(index);
      if (button is! web.HTMLButtonElement) continue;
      final level =
          int.tryParse(button.getAttribute('data-tw-style-level') ?? '');
      final pressed = level != null && level == activeLevel;
      button.setAttribute('aria-pressed', '$pressed');
    }
  }

  TableContext? _tableContext(EditorState state) {
    final focus = state.selection.focus.blockId;
    // Template and footnote content live outside the main document tree; the
    // table commands intentionally operate only on main-document tables.
    if (getBlock(state.state, focus) == null) return null;
    return resolveTableContext(state.state, focus);
  }

  Block? _activeImageBlock([EditorState? state]) {
    final current = state ?? editorState;
    final image = getBlock(current.state, current.selection.focus.blockId);
    return image?.type == 'image' ? image : null;
  }

  Block? _activeDrawingBlock([EditorState? state]) {
    final current = state ?? editorState;
    final drawing = getBlock(current.state, current.selection.focus.blockId);
    return drawing?.type == 'text-box' || drawing?.type == 'shape'
        ? drawing
        : null;
  }

  void _updateActiveDrawing({
    String? text,
    double? width,
    double? height,
    DrawingAlignment? alignment,
    String? fill,
    String? outline,
    double? outlineWidth,
  }) {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final drawing = _activeDrawingBlock();
    if (drawing == null) return;
    dispatch(UpdateDrawingAction(
      drawing.id.value,
      text: text,
      width: width,
      height: height,
      alignment: alignment,
      fill: fill,
      outline: outline,
      outlineWidth: outlineWidth,
    ));
  }

  bool _canSplitActiveTableCell(EditorState state, TableContext context) {
    final attrs = getBlock(state.state, context.cellId)?.attrs;
    if (attrs == null) return false;
    bool spans(dynamic value) =>
        value is num &&
        value.isFinite &&
        value.truncateToDouble() == value &&
        value > 1;
    return spans(attrs['rowSpan']) || spans(attrs['colSpan']);
  }

  void _syncImageSelection(Block? image) {
    final previous =
        _documentHost.surface.querySelectorAll('[data-tw-image-selected]');
    for (var index = 0; index < previous.length; index++) {
      final selected = previous.item(index);
      if (selected != null) {
        (selected as web.Element).removeAttribute('data-tw-image-selected');
      }
    }
    if (image == null) return;
    _documentHost
        .blockElement(image.id)
        ?.setAttribute('data-tw-image-selected', '');
  }

  void _syncDrawingSelection(Block? drawing) {
    final previous =
        _documentHost.surface.querySelectorAll('[data-tw-drawing-selected]');
    for (var index = 0; index < previous.length; index++) {
      final selected = previous.item(index);
      if (selected != null) {
        (selected as web.Element).removeAttribute('data-tw-drawing-selected');
      }
    }
    if (drawing == null) return;
    _documentHost
        .blockElement(drawing.id)
        ?.setAttribute('data-tw-drawing-selected', '');
  }

  void _installObjectSelectionHandler() {
    _documentHost.surface.addEventListener(
        'click',
        ((web.Event event) {
          if (_destroyed) return;
          final target = event.target;
          if (target is! web.HTMLElement) return;
          final rawId = target.getAttribute('data-block-id');
          if (rawId == null || rawId.isEmpty) return;
          final object = getBlock(editorState.state, BlockId(rawId));
          if (object?.type != 'image' &&
              object?.type != 'text-box' &&
              object?.type != 'shape') {
            return;
          }
          final position = Position(blockId: object!.id, offset: 0);
          dispatch(
              SetSelectionAction(Selection(anchor: position, focus: position)));
        }).toJS);
  }

  void _setActiveImageWrap(String wrap) {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final image = _activeImageBlock();
    if (image == null) return;
    dispatch(SetImageWrapAction(image.id.value, wrap));
  }

  void _toggleTableHeaderRow() {
    if (_destroyed || _mode == TaleweaverEditorMode.viewer) return;
    final context = _tableContext(editorState);
    if (context == null) return;
    final table = getBlock(editorState.state, context.tableId);
    final rawCount = table?.attrs['headerRowCount'];
    final current = rawCount is num && rawCount.isFinite && rawCount > 0
        ? rawCount.toInt()
        : 0;
    dispatch(
        SetTableHeaderRowsAction(context.tableId.value, current == 0 ? 1 : 0));
  }

  void _syncTemplateSurfaces(EditorState state) {
    // Empty/new documents have a root without an explicit section. For a
    // multi-section document, the active page owns the canonical template
    // surfaces rather than whichever section happens to be first in the tree.
    final section = _activeSectionForState(state) ??
        getBlock(state.state, state.state.rootId);
    final header = section?.attrs['headerBlockId'];
    final footer = section?.attrs['footerBlockId'];
    _syncTemplateSurface(
      region: 'header',
      container: _headerSurface,
      currentId: header is String ? BlockId(header) : null,
    );
    _syncTemplateSurface(
      region: 'footer',
      container: _footerSurface,
      currentId: footer is String ? BlockId(footer) : null,
    );
  }

  void _syncTemplateSurface({
    required String region,
    required web.HTMLElement container,
    required BlockId? currentId,
  }) {
    final previousId = region == 'header' ? _headerBodyId : _footerBodyId;
    if (previousId == currentId) return;
    if (region == 'header') {
      _headerHost?.destroy();
      _headerHost = null;
      _headerBodyId = currentId;
    } else {
      _footerHost?.destroy();
      _footerHost = null;
      _footerBodyId = currentId;
    }
    container.classList
        .toggle('tw-editor__template--visible', currentId != null);
    if (currentId == null || _destroyed) return;

    final template = DigitalEditorHost.mount(
      container,
      controller: _controller,
      config: DigitalEditorHostConfig(
        componentRegistry: options.componentRegistry,
        attrRegistry: options.attrRegistry,
        editorConfig: _effectiveEditorConfig(),
        readOnly: _mode == TaleweaverEditorMode.viewer,
        suggestionView: options.suggestionView,
        templateBodyId: currentId,
        templatePageNumber: 1,
        templatePageCount: _physicalPageCount,
        surfaceClassName: 'tw-editor__template-surface',
        ariaLabel:
            region == 'header' ? 'Cabeçalho da página' : 'Rodapé da página',
        surfaceAttributes: {
          'data-testid': 'tw-${region}-surface',
          'data-template-region': region,
        },
      ),
    );
    if (region == 'header') {
      _headerHost = template;
    } else {
      _footerHost = template;
    }
  }

  /// The normal single-page shell can keep editable templates at fixed
  /// coordinates. In an independent-section document, however, the active
  /// section may be several physical pages below the shell's origin. This
  /// schedules the canonical header/footer host over the matching inert page
  /// snapshot, so editing happens where Word users expect it to happen.
  void _scheduleSectionTemplateOverlay(EditorState state) {
    _templateOverlayState = state;
    if (_destroyed || _templateOverlayAnimationFrame != null) return;
    _templateOverlayAnimationFrame = web.window.requestAnimationFrame(
      ((double _) {
        _templateOverlayAnimationFrame = null;
        final latest = _templateOverlayState;
        if (latest != null && !_destroyed) {
          _layoutSectionTemplateOverlay(latest);
        }
      }).toJS,
    );
  }

  void _layoutSectionTemplateOverlay(EditorState state) {
    _clearSectionTemplateOverlay();
    if (_documentView != TaleweaverDocumentView.paginated ||
        !root.classList.contains('tw-editor--sectioned-pages')) {
      return;
    }
    final resolved = resolveBlock(state.state, state.selection.focus.blockId);
    if (resolved?.kind != ResolvedBlockKind.template) return;
    final section = _activeSectionForState(state);
    if (section == null || section.type != 'section') return;
    final templateId = _templateBodyId(resolved!.block, state);
    if (templateId == null) return;
    String? region;
    if (section.attrs['headerBlockId'] == templateId.value) {
      region = 'header';
    } else if (section.attrs['footerBlockId'] == templateId.value) {
      region = 'footer';
    }
    if (region == null) return;

    final sectionElement = _documentHost.blockElement(section.id);
    if (sectionElement == null) return;
    final pageNumber = _activePhysicalPagePosition(state)?.pageNumber;
    final snapshot = pageNumber == null
        ? sectionElement.querySelector('.tw-editor__page-$region')
        : sectionElement.querySelector(
            '.tw-editor__page-$region[data-page-number="$pageNumber"]',
          );
    if (snapshot is! web.HTMLElement) return;
    final container = region == 'header' ? _headerSurface : _footerSurface;
    final page = _pageConfigForSection(state, section);
    final metrics = _paginationMetrics(page);
    final snapshotRect = snapshot.getBoundingClientRect();
    final shellPageRect = _page.getBoundingClientRect();
    if (snapshotRect.width <= 0 || shellPageRect.width <= 0 || _zoom <= 0) {
      return;
    }
    final scale =
        metrics.pageWidth > 0 ? snapshotRect.width / metrics.pageWidth : _zoom;
    if (!scale.isFinite || scale <= 0) return;
    final contentLeft = snapshotRect.left + metrics.marginLeft * scale;
    final contentWidth = (snapshotRect.width -
            (metrics.marginLeft + metrics.marginRight) * scale)
        .clamp(1, double.infinity)
        .toDouble();
    final inlineLeft = (contentLeft - shellPageRect.left) / _zoom;
    final inlineTop = (snapshotRect.top - shellPageRect.top) / _zoom;
    container.classList.add('tw-editor__template--section-overlay');
    container.style
      ..left = '${inlineLeft.toStringAsFixed(2)}px'
      ..right = 'auto'
      ..width = '${(contentWidth / _zoom).toStringAsFixed(2)}px'
      ..bottom = 'auto'
      ..backgroundColor = '#fff';
    if (region == 'header') {
      final top = inlineTop +
          (metrics.headerFooterGap.clamp(0, metrics.marginTop) * scale / _zoom);
      container.style
        ..top = '${top.toStringAsFixed(2)}px'
        ..height = 'auto'
        ..minHeight = '1.3em'
        ..paddingBottom = '0'
        ..display = 'block'
        ..flexDirection = 'initial'
        ..justifyContent = 'initial';
    } else {
      final footerHeight = snapshotRect.height / _zoom;
      final bottomPadding =
          metrics.headerFooterGap.clamp(0, metrics.marginBottom);
      container.style
        ..top = '${inlineTop.toStringAsFixed(2)}px'
        ..height = '${footerHeight.toStringAsFixed(2)}px'
        ..minHeight = '0'
        ..paddingBottom = '${bottomPadding.toStringAsFixed(2)}px'
        ..display = 'flex'
        ..flexDirection = 'column'
        ..justifyContent = 'flex-end';
    }
    snapshot.setAttribute('data-tw-canonical-template', region);
  }

  BlockId? _templateBodyId(Block block, EditorState state) {
    var root = block;
    while (root.parentId != null) {
      final parent = getTemplateContent(state.state, root.parentId!);
      if (parent == null) break;
      root = parent;
    }
    return root.type == 'template-body' ? root.id : null;
  }

  void _clearSectionTemplateOverlay() {
    final snapshots = root.querySelectorAll('[data-tw-canonical-template]');
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots.item(index);
      if (snapshot is web.Element) {
        snapshot.removeAttribute('data-tw-canonical-template');
      }
    }
    const properties = [
      'left',
      'right',
      'top',
      'bottom',
      'width',
      'height',
      'min-height',
      'padding-bottom',
      'background-color',
      'display',
      'flex-direction',
      'justify-content',
    ];
    for (final container in [_headerSurface, _footerSurface]) {
      container.classList.remove('tw-editor__template--section-overlay');
      for (final property in properties) {
        container.style.removeProperty(property);
      }
    }
  }

  Map<String, dynamic> _activeAttrs([EditorState? state]) {
    final current = state ?? editorState;
    // For a non-collapsed range, inspect its document-order start rather than
    // the focus edge. Formatting actions commonly leave focus immediately
    // after the formatted run, which otherwise made the ribbon look inactive.
    final position = _selectionContextPosition(current);
    final focused = resolveBlock(current.state, position.blockId)?.block;
    final content = focused?.inlineContent;
    if (content == null || content.items.isEmpty) return const {};
    final contentLength = inlineContentLength(content);
    final offset = position.offset.clamp(0, contentLength).toInt();
    final index = offset >= contentLength
        ? content.items.length - 1
        : findItemAtOffset(content, offset).itemIndex;
    if (index < 0 || index >= content.items.length) return const {};
    return Map<String, dynamic>.of(content.items[index].attrs);
  }

  bool _listIsUnordered(Block? block) {
    if (block == null) return true;
    final listId = block.attrs['listId'];
    if (listId is! String) return true;
    final def = getListDefsForState(editorState.state)[listId];
    return def == null ||
        def.levels.isEmpty ||
        def.levels.first.style == 'disc';
  }

  void _setPressed(String command, bool value) {
    final button = _commands[command];
    if (button == null) return;
    button.setAttribute('aria-pressed', '$value');
  }

  void _setSaveState(String state) {
    final save = root.querySelector('.tw-editor__save-state span:last-child');
    save?.textContent = state;
    _statusState.textContent = state;
  }

  int _wordCount(EditorState state) {
    var count = 0;
    for (final block in iterateLeafBlocksInDocumentOrder(state.state)) {
      final content = block.inlineContent;
      if (content == null) continue;
      for (final item in content.items) {
        if (item is TextItem)
          count += RegExp(r'\S+').allMatches(item.text).length;
      }
    }
    return count;
  }

  web.HTMLElement _element(String tag, [String? className, String? text]) {
    final element = _document.createElement(tag) as web.HTMLElement;
    if (className != null && className.isNotEmpty)
      element.className = className;
    if (text != null) element.textContent = text;
    return element;
  }

  void _restoreHostStyles() {
    for (final entry in _hostStylesBefore.entries) {
      final before = entry.value;
      if (before.value.isEmpty && before.priority.isEmpty) {
        host.style.removeProperty(entry.key);
      } else {
        host.style.setProperty(entry.key, before.value, before.priority);
      }
    }
    _hostStylesBefore.clear();
  }

  void _assertAlive() {
    if (_destroyed) throw StateError('TaleweaverEditor já foi destruído.');
  }
}

/// Alias for integrations that use the conventional widget naming.
typedef TaleweaverEditorWidget = TaleweaverEditor;
