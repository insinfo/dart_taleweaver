/// Browser-flow pagination used by the embeddable Word shell.
///
/// The document retains one authoritative contenteditable tree.  This class
/// inserts only an inert float chain before that tree, so the browser can
/// fragment text at line boundaries without cloning model blocks or breaking
/// the DOM-selection bridge.  The technique is adapted to Taleweaver's keyed
/// renderer from the paginated editor in the local DOCX reference project.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
import '../editor/editor_state.dart';
import '../state/block_id.dart';
import '../state/suggestions.dart';
import 'render_to_dom.dart';

/// Physical page values expressed in browser CSS pixels.
///
/// [TaleweaverEditor] owns conversion from its public point-based
/// [PageConfig]. Keeping this value browser-only avoids leaking web units into
/// the serializable document model.
class WordPaginationMetrics {
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;
  final double headerFooterGap;
  final double pageGap;

  const WordPaginationMetrics({
    required this.pageWidth,
    required this.pageHeight,
    required this.marginTop,
    required this.marginRight,
    required this.marginBottom,
    required this.marginLeft,
    required this.headerFooterGap,
    this.pageGap = 28,
  });

  double get contentHeight =>
      math.max(1, pageHeight - marginTop - marginBottom).toDouble();

  /// The controller uses this rather than identity so a new page setup can
  /// update the existing browser-flow projection without remounting the
  /// editable host.
  bool sameGeometryAs(WordPaginationMetrics other) =>
      pageWidth == other.pageWidth &&
      pageHeight == other.pageHeight &&
      marginTop == other.marginTop &&
      marginRight == other.marginRight &&
      marginBottom == other.marginBottom &&
      marginLeft == other.marginLeft &&
      headerFooterGap == other.headerFooterGap &&
      pageGap == other.pageGap;
}

/// Immutable physical-page inputs for one explicit document section.
///
/// The model owns the section and template bodies; this profile is only a
/// browser projection assembled by [TaleweaverEditor].  Keeping the section
/// identity and template IDs here means physical pages never need to ask
/// which section is currently selected in order to decide their geometry or
/// repeated chrome.
class WordPaginationSectionProfile {
  /// The direct main-tree `section` block ID rendered as `data-block-id`.
  final BlockId sectionId;

  /// Paper and margin geometry expressed in unzoomed browser CSS pixels.
  final WordPaginationMetrics metrics;

  /// The header/footer template owned (or inherited) by this section.
  final BlockId? headerBodyId;
  final BlockId? footerBodyId;

  const WordPaginationSectionProfile({
    required this.sectionId,
    required this.metrics,
    this.headerBodyId,
    this.footerBodyId,
  });

  bool samePresentationAs(WordPaginationSectionProfile other) =>
      sectionId == other.sectionId &&
      metrics.sameGeometryAs(other.metrics) &&
      headerBodyId == other.headerBodyId &&
      footerBodyId == other.footerBodyId;
}

/// The paper rectangle currently containing a keyed document element.
///
/// Coordinates are visual browser pixels because they are intended for
/// chrome (rulers and status UI), not document serialization.  The page
/// number is one-based, exactly like Word's status bar and PAGE field.
class WordPaginationPagePosition {
  final int pageNumber;
  final double left;
  final double top;
  final double width;
  final double height;

  const WordPaginationPagePosition({
    required this.pageNumber,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Generated browser-only pagination state associated with one keyed section
/// element. It never owns or clones the section's model children.
class _SectionPager {
  final web.HTMLElement section;
  final WordPaginationSectionProfile profile;
  final web.HTMLElement decoration;
  final int pageStart;
  int pageCount;

  _SectionPager({
    required this.section,
    required this.profile,
    required this.decoration,
    required this.pageStart,
    this.pageCount = 1,
  });
}

/// A browser-only spacer placed immediately before a block whose model style
/// says `breakBefore: page`.  The spacer never becomes part of the document
/// model and is removed before every keyed reconciliation.
class _ManualPageBreakDecoration {
  final web.HTMLElement marker;
  final web.HTMLElement target;
  final _SectionPager? pager;

  const _ManualPageBreakDecoration({
    required this.marker,
    required this.target,
    required this.pager,
  });
}

/// Owns the inert browser decorations that make a single editable DOM surface
/// look and behave as a sequence of physical pages.
///
/// It intentionally does not know about the ribbon or a framework.  The Word
/// shell supplies template IDs and receives only the converged page count.
class WordPaginationController {
  final web.HTMLElement surface;
  final web.Document document;
  final ComponentRegistry components;
  final AttrRegistry attrs;
  final SuggestionView suggestionView;
  WordPaginationMetrics _metrics;
  final web.Element? Function() renderRoot;

  /// Returns presentation profiles for direct explicit sections. The callback
  /// must be independent of the current selection: a page keeps the section
  /// that created it even when the caret moves elsewhere.
  final List<WordPaginationSectionProfile> Function(EditorState state)?
      sectionProfiles;

  // Legacy/root template providers remain the fallback for a document with no
  // explicit section wrapper.
  final BlockId? Function() headerBodyId;
  final BlockId? Function() footerBodyId;
  final void Function(int pageCount)? onPageCountChanged;

  web.HTMLElement? _decoration;
  final List<_SectionPager> _sectionPagers = <_SectionPager>[];
  final List<_ManualPageBreakDecoration> _manualPageBreakDecorations =
      <_ManualPageBreakDecoration>[];
  List<WordPaginationSectionProfile> _lastSectionProfiles =
      const <WordPaginationSectionProfile>[];
  final List<web.HTMLElement> _sectionBreakDecorations = <web.HTMLElement>[];
  web.ResizeObserver? _resizeObserver;
  EditorState? _state;
  Timer? _timer;
  int? _animationFrame;
  int _pageCount = 1;
  int _sectionPageFloor = 1;
  // `getBoundingClientRect` reports visual pixels. The Word shell applies
  // CSS `zoom` to its page, while all pagination decoration styles remain in
  // unzoomed layout CSS pixels. Keep that conversion explicitly at the
  // measurement boundary so zoom can never manufacture or remove a page.
  double _visualScale = 1;
  int? _lastRevision;
  BlockId? _lastHeaderBodyId;
  BlockId? _lastFooterBodyId;
  bool _enabled = true;
  bool _destroyed = false;
  bool _measuring = false;

  WordPaginationController({
    required this.surface,
    required this.document,
    required this.components,
    required this.attrs,
    required this.suggestionView,
    required WordPaginationMetrics metrics,
    required this.renderRoot,
    this.sectionProfiles,
    required this.headerBodyId,
    required this.footerBodyId,
    this.onPageCountChanged,
  }) : _metrics = metrics;

  WordPaginationMetrics get metrics => _metrics;

  /// The visual scale currently applied by the embedding shell.
  ///
  /// This affects only DOM-rectangle measurements. Page floats, headers,
  /// gaps, and minimum height continue to use their ordinary CSS-pixel values
  /// so the browser's normal `zoom` rendering remains the sole visual scale.
  double get visualScale => _visualScale;

  /// Number of materialized physical pages. It is one-based for UI only;
  /// model page indices remain zero-based elsewhere in the engine.
  int get pageCount => _pageCount;

  /// Finds the generated physical page containing [element].
  ///
  /// The keyed element remains in the single authoritative editing tree; page
  /// headers are inert float decorations.  Comparing their visual positions
  /// gives the shell a stable page number without moving, cloning or wrapping
  /// the editable element.
  WordPaginationPagePosition? pagePositionForElement(web.Element? element) {
    if (!_enabled || element == null || !element.isConnected) return null;
    final elementRect = element.getBoundingClientRect();
    return pagePositionForVisualY(elementRect.top);
  }

  /// Resolves a visual y-coordinate (normally a caret rectangle) to a
  /// physical page. This is more precise than an element rectangle when a
  /// single long paragraph spans several pages.
  WordPaginationPagePosition? pagePositionForVisualY(double visualY) {
    if (!_enabled || !visualY.isFinite) return null;
    web.HTMLElement? selectedHeader;
    var selectedPage = 1;
    final headers = surface.querySelectorAll('.tw-editor__page-header');
    for (var index = 0; index < headers.length; index++) {
      final candidate = headers.item(index);
      if (candidate is! web.HTMLElement) continue;
      final rect = candidate.getBoundingClientRect();
      if (!rect.top.isFinite || rect.top > visualY + _visualOffset(.5)) {
        continue;
      }
      final page =
          int.tryParse(candidate.getAttribute('data-page-number') ?? '');
      if (page == null || page < selectedPage) continue;
      selectedHeader = candidate;
      selectedPage = page;
    }
    final header = selectedHeader;
    if (header == null) return null;
    final rect = header.getBoundingClientRect();
    final metrics = _metricsForHeader(header);
    final scale = metrics.pageWidth > 0 ? rect.width / metrics.pageWidth : 1.0;
    final safeScale = scale.isFinite && scale > 0 ? scale : _visualScale;
    return WordPaginationPagePosition(
      pageNumber: selectedPage,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: metrics.pageHeight * safeScale,
    );
  }

  bool get enabled => _enabled;

  /// Updates the scale used to normalize [web.DOMRect] offsets.
  ///
  /// Invalid values deliberately fall back to one instead of allowing a
  /// malformed host zoom value to produce `NaN` page counts. A scale update
  /// only asks for a fresh measurement; it never rebuilds decorations with
  /// scaled style values.
  void setVisualScale(double value) {
    if (_destroyed) return;
    final normalized =
        value.isFinite && value > 0 ? value.clamp(.01, 100).toDouble() : 1.0;
    if (_visualScale == normalized) return;
    _visualScale = normalized;
    if (_enabled) _schedule();
  }

  /// Reflows the current physical-page projection after a page-size,
  /// orientation or margin change.  The authoritative DOM stays mounted, so
  /// selection and composition are not disturbed.
  void updateMetrics(WordPaginationMetrics value) {
    if (_destroyed || _metrics.sameGeometryAs(value)) return;
    _metrics = value;
    // Explicit sections own their own immutable geometry. The shell still
    // updates its active-page ruler metrics as the selection moves, but that
    // must not rebuild every section's physical pages using the active one.
    if (_sectionPagers.isNotEmpty || _lastSectionProfiles.isNotEmpty) return;
    if (!_enabled) return;
    _prepareSurface();
    _rebuildDecoration();
    _schedule();
  }

  /// Starts projection after the contenteditable host has mounted its first
  /// keyed render tree.
  void mount(EditorState state, {bool enabled = true}) {
    if (_destroyed) return;
    _enabled = enabled;
    _state = state;
    _lastRevision = state.state.doc.revision;
    _refreshSectionProfiles(state);
    if (_lastSectionProfiles.isEmpty) _refreshTemplateBodyIds();
    if (!_enabled) return;
    _installResizeObserver();
    _prepareSurface();
    _rebuildDecoration();
    _schedule();
  }

  /// Called after the authoritative DOM reconciles an editor state.
  ///
  /// Selection-only states deliberately retain the existing decorations,
  /// avoiding a layout shift while the user moves the caret.
  void update(EditorState state) {
    if (_destroyed) return;
    _state = state;
    final revision = state.state.doc.revision;
    final documentChanged = revision != _lastRevision;
    _lastRevision = revision;
    if (!_enabled) return;
    _prepareSurface();
    final profilesChanged = _refreshSectionProfiles(state);
    // A section profile is derived from document structure/attributes, never
    // from selection. Consequently moving a caret between sections does not
    // recreate old pages with a different header or paper size.
    final templateBodiesChanged =
        _lastSectionProfiles.isEmpty ? _refreshTemplateBodyIds() : false;
    final presentationChanged =
        documentChanged || profilesChanged || templateBodiesChanged;
    if (!presentationChanged) {
      // Selection changes are frequent while typing and while the caret moves.
      // They do not change the browser-flow geometry, so avoid scheduling a
      // forced layout/measurement frame for every selection-only transaction.
      return;
    }
    _rebuildDecoration();
    _schedule();
  }

  bool _refreshTemplateBodyIds() {
    final header = headerBodyId();
    final footer = footerBodyId();
    final changed = header != _lastHeaderBodyId || footer != _lastFooterBodyId;
    _lastHeaderBodyId = header;
    _lastFooterBodyId = footer;
    return changed;
  }

  /// Activates physical page decorations for `paginated` and removes them for
  /// the continuous web layout. The document nodes themselves are never moved
  /// or regenerated by this operation.
  void setEnabled(bool value) {
    if (_destroyed || _enabled == value) return;
    _enabled = value;
    if (!value) {
      _cancelPending();
      _removeDecoration();
      _clearManualPageBreakDecorations();
      _clearSectionPagers();
      _clearSectionBreakDecorations();
      _restoreRootDisplay();
      surface.removeAttribute('data-tw-pages');
      surface.removeAttribute('data-page-count');
      return;
    }
    _installResizeObserver();
    _prepareSurface();
    _rebuildDecoration();
    _schedule();
  }

  /// Cancels browser work and removes only generated decorations.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _cancelPending();
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _removeDecoration();
    _clearManualPageBreakDecorations();
    _clearSectionPagers();
    _clearSectionBreakDecorations();
    _restoreRootDisplay();
    surface.removeAttribute('data-tw-pages');
    surface.removeAttribute('data-page-count');
  }

  void _prepareSurface() {
    final root = renderRoot();
    if (root == null) return;
    // The generated document container is normally a block.  Turning just
    // that wrapper into `contents` leaves all keyed leaf blocks in the same
    // formatting context as the float chain while retaining their DOM
    // identity for selection and reconciliation.
    if (root is web.HTMLElement) {
      root.style.setProperty('display', 'contents');
    }
    surface
      ..setAttribute('data-tw-pages', 'true')
      ..setAttribute('data-page-count', '$_pageCount');
  }

  void _restoreRootDisplay() {
    final root = renderRoot();
    if (root is web.HTMLElement) root.style.removeProperty('display');
  }

  void _schedule() {
    if (_destroyed || !_enabled || _timer != null) return;
    _timer = Timer(const Duration(milliseconds: 16), () {
      _timer = null;
      if (_destroyed || !_enabled) return;
      _animationFrame = web.window.requestAnimationFrame(((double _) {
        _animationFrame = null;
        _measure();
      }).toJS);
    });
  }

  void _installResizeObserver() {
    if (_resizeObserver != null) return;
    _resizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver _) {
        if (entries.length > 0) _schedule();
      }).toJS,
    )..observe(surface);
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    final frame = _animationFrame;
    if (frame != null) web.window.cancelAnimationFrame(frame);
    _animationFrame = null;
  }

  void _measure() {
    if (_destroyed || !_enabled || _measuring || !surface.isConnected) return;
    final decoration = _decoration;
    final root = renderRoot();
    if (root == null) return;
    _measuring = true;
    try {
      _prepareSurface();
      if (_sectionPagers.isNotEmpty) {
        _measureSectionPagers();
        return;
      }
      if (decoration == null) return;
      final sectionBreaks = _layoutSectionBreakDecorations(root, decoration);
      final manualBreaks = _layoutManualPageBreakDecorations(
        decoration,
        pager: null,
      );
      _sectionPageFloor = math.max(sectionBreaks.floor, manualBreaks.floor);
      final missingPages =
          sectionBreaks.missingPages + manualBreaks.missingPages;
      if (missingPages > 0) {
        // The fixed float chain initially has only as many pages as ordinary
        // body overflow requires. A short following section therefore may not
        // yet have a physical next-page header to target. Materialise only
        // those missing targets, then measure again on the fresh chain.
        final next = math
            .max(_pageCount + missingPages, _sectionPageFloor)
            .clamp(1, 10000)
            .toInt();
        if (next != _pageCount) {
          _pageCount = next;
          _rebuildDecoration();
          onPageCountChanged?.call(_pageCount);
          _schedule();
          return;
        }
      }
      final lastBreaker =
          decoration.lastElementChild?.querySelector('[data-tw-page-breaker]');
      final content = _lastVisibleDescendant(root);
      if (lastBreaker == null || content == null) return;
      final contentRect = content.getBoundingClientRect();
      final breakerRect = lastBreaker.getBoundingClientRect();
      if (contentRect.height <= 0 || breakerRect.height < 0) return;

      // Positive means the content reached below the final sentinel and needs
      // pages; sufficiently negative means whole page strides are unused.
      final visualDifference = contentRect.bottom - breakerRect.bottom;
      if (!visualDifference.isFinite) return;
      final difference = _layoutOffset(visualDifference);
      var next = _pageCount;
      if (difference > .5) {
        next += (difference / metrics.contentHeight).ceil();
      } else if (difference < -(metrics.pageHeight - 10)) {
        final reduction =
            (difference / (metrics.pageHeight + metrics.pageGap)).truncate();
        next = math.max(1, _pageCount + reduction);
      }
      next = math.max(next, _sectionPageFloor).clamp(1, 10000).toInt();
      if (next != _pageCount) {
        _pageCount = next;
        _rebuildDecoration();
        onPageCountChanged?.call(_pageCount);
        // The new float chain has nominal geometry; measure it in a fresh
        // frame before deciding whether another page is needed.
        _schedule();
      } else {
        _setMinimumHeight();
      }
    } finally {
      _measuring = false;
    }
  }

  web.Element? _lastVisibleDescendant(web.Element root) {
    web.Element? current = root;
    while (current != null && current.lastElementChild != null) {
      current = current.lastElementChild;
    }
    return current;
  }

  void _setMinimumHeight() {
    final height = metrics.pageHeight +
        (_pageCount - 1) * (metrics.pageHeight + metrics.pageGap);
    surface.style.minHeight = '${height.toStringAsFixed(2)}px';
  }

  void _rebuildDecoration() {
    if (_destroyed || !_enabled) return;
    final state = _state;
    final root = renderRoot();
    if (state == null || root == null) return;
    _prepareSurface();

    // Each explicit section receives an independent float chain. This keeps
    // portrait/landscape paper, page counts, and template snapshots attached
    // to the section that owns them rather than to the user's current caret.
    if (_rebuildSectionPagers(state, root)) return;

    _clearManualPageBreakDecorations();
    _clearSectionPagers();
    final old = _decoration;
    if (old != null) old.remove();

    final decoration = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__pagination'
      ..setAttribute('data-tw-pagination-decoration', '')
      ..setAttribute('data-page-count', '$_pageCount')
      ..setAttribute('contenteditable', 'false')
      ..setAttribute('aria-hidden', 'true');
    decoration.style
      ..height = '0'
      ..pointerEvents = 'none';

    // One wrapper creates the first header; every following wrapper emits the
    // previous footer, the canvas gap and next header. The final wrapper is a
    // sentinel that contributes the last footer and lets measurement detect
    // overflow without putting a model-bound page break in the document.
    for (var index = 0; index <= _pageCount; index++) {
      decoration.appendChild(_buildBreak(state, index));
    }
    surface.insertBefore(decoration, root);
    _decoration = decoration;
    _rebuildSectionBreakDecorations(root);
    _rebuildManualPageBreakDecorations(root);
    _setMinimumHeight();
  }

  bool _refreshSectionProfiles(EditorState state) {
    final next = List<WordPaginationSectionProfile>.from(
      sectionProfiles?.call(state) ?? const <WordPaginationSectionProfile>[],
    );
    final changed = next.length != _lastSectionProfiles.length ||
        next.asMap().entries.any((entry) {
          return !_lastSectionProfiles[entry.key]
              .samePresentationAs(entry.value);
        });
    _lastSectionProfiles =
        List<WordPaginationSectionProfile>.unmodifiable(next);
    return changed;
  }

  /// Builds independent inert float chains directly inside the original keyed
  /// section elements. A section's model children stay where the reconciler
  /// placed them; only the generated decoration is inserted before them.
  bool _rebuildSectionPagers(EditorState state, web.Element root) {
    final profiles = _lastSectionProfiles;
    if (profiles.isEmpty) return false;
    final sections = _directSectionChildren(root);
    if (sections.length != profiles.length || sections.isEmpty) return false;

    final profilesById = <String, WordPaginationSectionProfile>{};
    for (final profile in profiles) {
      if (!_isUsableSectionProfile(profile) ||
          profilesById.putIfAbsent(profile.sectionId.value, () => profile) !=
              profile) {
        return false;
      }
    }
    final orderedProfiles = <WordPaginationSectionProfile>[];
    for (final section in sections) {
      final id = section.getAttribute('data-block-id');
      final profile = id == null ? null : profilesById[id];
      if (profile == null) return false;
      orderedProfiles.add(profile);
    }

    // Carry page counts through a content rebuild. The first fresh layout may
    // still adjust them, but preserving the prior topology avoids displaying a
    // transient "one page per section" document and keeps PAGE/NUMPAGES
    // snapshots coherent until the next animation-frame measurement.
    final previousCounts = <String, int>{
      for (final pager in _sectionPagers)
        pager.profile.sectionId.value: pager.pageCount,
    };

    _removeDecoration();
    _clearManualPageBreakDecorations();
    _clearSectionBreakDecorations();
    _clearSectionPagers();

    final pageCounts = <int>[];
    for (final profile in orderedProfiles) {
      pageCounts.add(
        (previousCounts[profile.sectionId.value] ?? 1).clamp(1, 10000),
      );
    }
    final total =
        math.max(1, pageCounts.fold<int>(0, (sum, count) => sum + count));
    final previousTotal = _pageCount;
    _pageCount = total;
    _prepareSurface();
    _enableSectionSurface(orderedProfiles);

    var pageStart = 1;
    for (var index = 0; index < sections.length; index++) {
      final section = sections[index];
      final profile = orderedProfiles[index];
      final count = pageCounts[index];
      _applySectionPresentation(section, profile, count);
      final decoration = _buildSectionDecoration(
        state,
        profile,
        pageStart: pageStart,
        pageCount: count,
        documentPageCount: total,
      );
      section.insertBefore(decoration, section.firstChild);
      _sectionPagers.add(_SectionPager(
        section: section,
        profile: profile,
        decoration: decoration,
        pageStart: pageStart,
        pageCount: count,
      ));
      pageStart += count;
    }

    surface
      ..setAttribute('data-page-count', '$total')
      ..setAttribute('data-tw-section-pages', 'true');
    _rebuildManualPageBreakDecorations(root);
    if (previousTotal != total) onPageCountChanged?.call(total);
    return true;
  }

  bool _isUsableSectionProfile(WordPaginationSectionProfile profile) {
    final metrics = profile.metrics;
    return metrics.pageWidth.isFinite &&
        metrics.pageHeight.isFinite &&
        metrics.pageWidth > 0 &&
        metrics.pageHeight > 0 &&
        metrics.marginLeft >= 0 &&
        metrics.marginRight >= 0 &&
        metrics.marginTop >= 0 &&
        metrics.marginBottom >= 0 &&
        metrics.marginLeft + metrics.marginRight < metrics.pageWidth &&
        metrics.marginTop + metrics.marginBottom < metrics.pageHeight;
  }

  void _enableSectionSurface(List<WordPaginationSectionProfile> profiles) {
    var widest = 1.0;
    for (final profile in profiles) {
      widest = math.max(widest, profile.metrics.pageWidth).toDouble();
    }
    surface.style
      ..setProperty('--tw-section-stack-width', _px(widest))
      ..removeProperty('min-height');
  }

  void _applySectionPresentation(
    web.HTMLElement section,
    WordPaginationSectionProfile profile,
    int pageCount,
  ) {
    final metrics = profile.metrics;
    section.classList.add('tw-editor__paged-section');
    section.style
      ..setProperty('--tw-section-page-width', _px(metrics.pageWidth))
      ..setProperty('--tw-section-page-height', _px(metrics.pageHeight))
      ..setProperty('--tw-section-margin-top', _px(metrics.marginTop))
      ..setProperty('--tw-section-margin-right', _px(metrics.marginRight))
      ..setProperty('--tw-section-margin-bottom', _px(metrics.marginBottom))
      ..setProperty('--tw-section-margin-left', _px(metrics.marginLeft))
      ..setProperty('--tw-section-min-height',
          _px(_sectionMinimumHeight(metrics, pageCount)));
    section
      ..setAttribute('data-tw-section-page-width', _px(metrics.pageWidth))
      ..setAttribute('data-tw-section-page-height', _px(metrics.pageHeight))
      ..setAttribute('data-tw-section-page-count', '$pageCount');
  }

  void _clearSectionPagers() {
    for (final pager in _sectionPagers) {
      pager.decoration.remove();
      _clearSectionPresentation(pager.section);
    }
    _sectionPagers.clear();
    surface
      ..removeAttribute('data-tw-section-pages')
      ..style.removeProperty('--tw-section-stack-width');
  }

  void _clearSectionPresentation(web.HTMLElement section) {
    section.classList.remove('tw-editor__paged-section');
    for (final property in const [
      '--tw-section-page-width',
      '--tw-section-page-height',
      '--tw-section-margin-top',
      '--tw-section-margin-right',
      '--tw-section-margin-bottom',
      '--tw-section-margin-left',
      '--tw-section-min-height',
    ]) {
      section.style.removeProperty(property);
    }
    section
      ..removeAttribute('data-tw-section-page-width')
      ..removeAttribute('data-tw-section-page-height')
      ..removeAttribute('data-tw-section-page-count');
  }

  void _measureSectionPagers() {
    final state = _state;
    if (state == null || _sectionPagers.isEmpty) return;
    for (final pager in _sectionPagers) {
      final manualBreaks = _layoutManualPageBreakDecorations(
        pager.decoration,
        pager: pager,
      );
      final localManualFloor =
          math.max(1, manualBreaks.floor - pager.pageStart + 1).toInt();
      if (manualBreaks.missingPages > 0 || localManualFloor > pager.pageCount) {
        pager.pageCount = math
            .max(
              pager.pageCount + manualBreaks.missingPages,
              localManualFloor,
            )
            .clamp(1, 10000)
            .toInt();
        final root = renderRoot();
        if (root != null) _rebuildSectionPagers(state, root);
        _schedule();
        return;
      }
      final lastBreaker = pager.decoration.lastElementChild
          ?.querySelector('[data-tw-page-breaker]');
      final content = _lastVisibleDescendant(pager.section);
      if (lastBreaker == null ||
          content == null ||
          content == pager.decoration ||
          pager.decoration.contains(content)) {
        _setSectionMinimumHeight(pager);
        continue;
      }
      final contentRect = content.getBoundingClientRect();
      final breakerRect = lastBreaker.getBoundingClientRect();
      if (contentRect.height <= 0 || breakerRect.height < 0) {
        _setSectionMinimumHeight(pager);
        continue;
      }
      final visualDifference = contentRect.bottom - breakerRect.bottom;
      if (!visualDifference.isFinite) continue;
      final difference = _layoutOffset(visualDifference);
      var next = pager.pageCount;
      final metrics = pager.profile.metrics;
      if (difference > .5) {
        next += (difference / metrics.contentHeight).ceil();
      } else if (difference < -(metrics.pageHeight - 10)) {
        final reduction =
            (difference / (metrics.pageHeight + metrics.pageGap)).truncate();
        next = math.max(1, pager.pageCount + reduction);
      }
      next = next.clamp(1, 10000).toInt();
      if (next != pager.pageCount) {
        pager.pageCount = next;
        final root = renderRoot();
        if (root != null) _rebuildSectionPagers(state, root);
        _schedule();
        return;
      }
      _setSectionMinimumHeight(pager);
    }
  }

  void _setSectionMinimumHeight(_SectionPager pager) {
    final height =
        _sectionMinimumHeight(pager.profile.metrics, pager.pageCount);
    pager.section.style.setProperty('--tw-section-min-height', _px(height));
    pager.section
        .setAttribute('data-tw-section-page-count', '${pager.pageCount}');
  }

  double _sectionMinimumHeight(WordPaginationMetrics metrics, int pageCount) =>
      metrics.pageHeight +
      (pageCount - 1) * (metrics.pageHeight + metrics.pageGap);

  web.HTMLElement _buildSectionDecoration(
    EditorState state,
    WordPaginationSectionProfile profile, {
    required int pageStart,
    required int pageCount,
    required int documentPageCount,
  }) {
    final decoration = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__pagination tw-editor__section-pagination'
      ..setAttribute('data-tw-pagination-decoration', '')
      ..setAttribute('data-tw-section-pagination-decoration', '')
      ..setAttribute('data-tw-section-id', profile.sectionId.value)
      ..setAttribute('data-page-count', '$documentPageCount')
      ..setAttribute('contenteditable', 'false')
      ..setAttribute('aria-hidden', 'true');
    decoration.style
      ..height = '0'
      ..pointerEvents = 'none';
    for (var index = 0; index <= pageCount; index++) {
      decoration.appendChild(_buildSectionBreak(
        state,
        profile,
        pageStart: pageStart,
        localIndex: index,
        sectionPageCount: pageCount,
        documentPageCount: documentPageCount,
      ));
    }
    return decoration;
  }

  web.HTMLElement _buildSectionBreak(
    EditorState state,
    WordPaginationSectionProfile profile, {
    required int pageStart,
    required int localIndex,
    required int sectionPageCount,
    required int documentPageCount,
  }) {
    final metrics = profile.metrics;
    final wrapper = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-break'
      ..setAttribute('data-page-index', '${pageStart + localIndex - 1}')
      ..setAttribute('data-section-page-index', '$localIndex')
      ..setAttribute('data-tw-section-id', profile.sectionId.value);
    final spacer = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-spacer'
      ..setAttribute('data-page-number', '${pageStart + localIndex}');
    spacer.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = '0'
      ..height = '0'
      ..marginTop = localIndex == 0 ? '0' : _px(metrics.contentHeight);

    final breaker = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-breaker'
      ..setAttribute('data-tw-page-breaker', '')
      ..setAttribute('data-page-index', '${pageStart + localIndex - 1}')
      ..setAttribute('data-section-page-index', '$localIndex')
      ..setAttribute('data-tw-section-id', profile.sectionId.value);
    breaker.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = _px(metrics.pageWidth)
      ..marginLeft = _px(-metrics.marginLeft)
      ..zIndex = '2';

    if (localIndex > 0) {
      breaker.appendChild(_buildProfileFooter(
        state,
        profile,
        pageNumber: pageStart + localIndex - 1,
        documentPageCount: documentPageCount,
      ));
      breaker.appendChild(_buildProfileGap(metrics));
    }
    if (localIndex < sectionPageCount) {
      // Unlike the legacy root pager, explicit sections also render an inert
      // snapshot on their first page. The editable overlay is separate and
      // may follow the caret, but this physical page never does.
      breaker.appendChild(_buildProfileHeader(
        state,
        profile,
        pageNumber: pageStart + localIndex,
        documentPageCount: documentPageCount,
      ));
    }
    wrapper
      ..appendChild(spacer)
      ..appendChild(breaker);
    return wrapper;
  }

  web.HTMLElement _buildProfileHeader(
    EditorState state,
    WordPaginationSectionProfile profile, {
    required int pageNumber,
    required int documentPageCount,
  }) {
    final metrics = profile.metrics;
    final header = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-header'
      ..setAttribute('data-page-number', '$pageNumber')
      ..setAttribute('data-tw-section-id', profile.sectionId.value);
    header.style
      ..position = 'relative'
      ..minHeight = _px(metrics.marginTop)
      ..paddingTop = _px(math.min(metrics.headerFooterGap, metrics.marginTop))
      ..paddingRight = _px(metrics.marginRight)
      ..paddingLeft = _px(metrics.marginLeft)
      ..boxSizing = 'border-box'
      ..backgroundColor = '#fff';
    final id = profile.headerBodyId;
    if (id != null) {
      header.appendChild(_templateSnapshot(
        state,
        id,
        pageNumber,
        pageCount: documentPageCount,
      ));
    }
    return header;
  }

  web.HTMLElement _buildProfileFooter(
    EditorState state,
    WordPaginationSectionProfile profile, {
    required int pageNumber,
    required int documentPageCount,
  }) {
    final metrics = profile.metrics;
    final footer = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-footer'
      ..setAttribute('data-page-number', '$pageNumber')
      ..setAttribute('data-tw-section-id', profile.sectionId.value);
    footer.style
      ..position = 'relative'
      ..minHeight = _px(metrics.marginBottom)
      ..paddingRight = _px(metrics.marginRight)
      ..paddingBottom =
          _px(math.min(metrics.headerFooterGap, metrics.marginBottom))
      ..paddingLeft = _px(metrics.marginLeft)
      ..boxSizing = 'border-box'
      ..display = 'flex'
      ..flexDirection = 'column'
      ..justifyContent = 'flex-end'
      ..backgroundColor = '#fff';
    final id = profile.footerBodyId;
    if (id != null) {
      footer.appendChild(_templateSnapshot(
        state,
        id,
        pageNumber,
        pageCount: documentPageCount,
      ));
    }
    return footer;
  }

  web.HTMLElement _buildProfileGap(WordPaginationMetrics metrics) =>
      document.createElement('div') as web.HTMLElement
        ..className = 'tw-editor__pagination-gap'
        ..style.height = _px(metrics.pageGap);

  /// Inserts a non-model boundary before every explicit section after the
  /// first. The main reconciler removes these inert siblings while patching its
  /// keyed tree; [update] then rebuilds them after that reconcile, so no model
  /// node is cloned, reparented or used as a fake page break.
  void _rebuildSectionBreakDecorations(web.Element root) {
    _clearSectionBreakDecorations();
    final sections = _directSectionChildren(root);
    _sectionPageFloor = math.max(1, sections.length).toInt();
    if (sections.length < 2) return;

    for (var index = 1; index < sections.length; index++) {
      final marker = document.createElement('div') as web.HTMLElement
        ..className = 'tw-editor__section-page-break'
        ..setAttribute('data-tw-section-break-decoration', '')
        ..setAttribute('data-tw-section-index', '$index')
        ..setAttribute('contenteditable', 'false')
        ..setAttribute('aria-hidden', 'true');
      marker.style
        ..display = 'block'
        ..height = '0px'
        ..margin = '0'
        ..padding = '0'
        ..border = '0'
        ..pointerEvents = 'none'
        ..userSelect = 'none';
      root.insertBefore(marker, sections[index]);
      _sectionBreakDecorations.add(marker);
    }
  }

  void _clearSectionBreakDecorations() {
    for (final marker in _sectionBreakDecorations) {
      marker.remove();
    }
    _sectionBreakDecorations.clear();
    _sectionPageFloor = 1;
  }

  /// Rebuilds manual-break spacers after the keyed renderer has reconciled
  /// the authoritative tree. Only normal block containers are eligible: a
  /// `<div>` inserted inside a table row/cell would create invalid table DOM,
  /// so nested table content retains its regular CSS break semantics instead.
  void _rebuildManualPageBreakDecorations(web.Element root) {
    _clearManualPageBreakDecorations();
    final targets = root.querySelectorAll('[data-tw-manual-page-break]');
    for (var index = 0; index < targets.length; index++) {
      final target = targets.item(index);
      if (target is! web.HTMLElement || _isGeneratedPaginationNode(target)) {
        continue;
      }
      final parent = target.parentElement;
      if (parent == null || _hasTableAncestor(target, root)) continue;
      final pager = _pagerForElement(target, root);
      // In the independent-section projection every marker must belong to a
      // section. A mixed/legacy tree uses the root decoration instead.
      if (_sectionPagers.isNotEmpty && pager == null) continue;
      final marker = document.createElement('div') as web.HTMLElement
        ..className = 'tw-editor__manual-page-break'
        ..setAttribute('data-tw-manual-page-break-decoration', '')
        ..setAttribute('contenteditable', 'false')
        ..setAttribute('aria-hidden', 'true');
      marker.style
        ..display = 'block'
        ..height = '0px'
        ..margin = '0'
        ..padding = '0'
        ..border = '0'
        ..pointerEvents = 'none'
        ..userSelect = 'none';
      parent.insertBefore(marker, target);
      _manualPageBreakDecorations.add(_ManualPageBreakDecoration(
        marker: marker,
        target: target,
        pager: pager,
      ));
    }
  }

  void _clearManualPageBreakDecorations() {
    for (final entry in _manualPageBreakDecorations) {
      entry.marker.remove();
    }
    _manualPageBreakDecorations.clear();
  }

  ({int floor, int missingPages}) _layoutManualPageBreakDecorations(
    web.HTMLElement pagination, {
    required _SectionPager? pager,
  }) {
    final relevant = <_ManualPageBreakDecoration>[
      for (final entry in _manualPageBreakDecorations)
        if (identical(entry.pager, pager) &&
            entry.target.isConnected &&
            entry.marker.isConnected)
          entry,
    ];
    if (relevant.isEmpty) return (floor: 1, missingPages: 0);

    for (final entry in relevant) {
      entry.marker
        ..style.height = '0px'
        ..removeAttribute('data-tw-target-page');
    }

    var floor = 1;
    var missingPages = 0;
    for (final entry in relevant) {
      final targetTop = entry.target.getBoundingClientRect().top;
      final header = _nextPageHeaderAfter(pagination, targetTop);
      if (header == null) {
        missingPages++;
        continue;
      }
      final headerRect = header.getBoundingClientRect();
      final offset =
          math.max(0, _layoutOffset(headerRect.bottom - targetTop)).toDouble();
      if (offset.isFinite) entry.marker.style.height = _px(offset);
      final page = int.tryParse(header.getAttribute('data-page-number') ?? '');
      if (page != null && page > 0) {
        entry.marker.setAttribute('data-tw-target-page', '$page');
        floor = math.max(floor, page).toInt();
      }
    }
    return (floor: floor, missingPages: missingPages);
  }

  _SectionPager? _pagerForElement(web.Element element, web.Element root) {
    web.Element? current = element;
    while (current != null && !identical(current, root)) {
      if (current is web.HTMLElement &&
          current.hasAttribute('data-tw-section')) {
        for (final pager in _sectionPagers) {
          if (identical(pager.section, current)) return pager;
        }
        return null;
      }
      current = current.parentElement;
    }
    return null;
  }

  bool _hasTableAncestor(web.Element element, web.Element root) {
    web.Element? current = element.parentElement;
    while (current != null && !identical(current, root)) {
      switch (current.localName) {
        case 'table':
        case 'tbody':
        case 'thead':
        case 'tfoot':
        case 'tr':
        case 'td':
        case 'th':
          return true;
      }
      current = current.parentElement;
    }
    return false;
  }

  bool _isGeneratedPaginationNode(web.Element element) {
    web.Element? current = element;
    while (current != null && !identical(current, surface)) {
      if (current.hasAttribute('data-tw-pagination-decoration')) return true;
      current = current.parentElement;
    }
    return false;
  }

  List<web.HTMLElement> _directSectionChildren(web.Element root) {
    final result = <web.HTMLElement>[];
    final children = root.children;
    for (var index = 0; index < children.length; index++) {
      final child = children.item(index);
      if (child is web.HTMLElement && child.hasAttribute('data-tw-section')) {
        result.add(child);
      }
    }
    return result;
  }

  /// Resolves each inert boundary to the next generated page header.
  ///
  /// The marker consumes only the unused part of the current physical page;
  /// it never wraps/moves document blocks. A following section remains the
  /// original keyed element, and browser selection offsets therefore continue
  /// to point at the same model text before and after pagination.
  ({int floor, int missingPages}) _layoutSectionBreakDecorations(
    web.Element root,
    web.HTMLElement pagination,
  ) {
    final sections = _directSectionChildren(root);
    final baselineFloor = math.max(1, sections.length).toInt();
    final markers = _sectionBreakDecorations;
    if (sections.length < 2 || markers.length != sections.length - 1) {
      return (floor: baselineFloor, missingPages: 0);
    }

    // Reset first: otherwise a stable marker would be measured at its already
    // shifted position and acquire another page on every animation frame.
    for (final marker in markers) {
      marker
        ..style.height = '0px'
        ..removeAttribute('data-tw-target-page');
    }

    var floor = baselineFloor;
    var missingPages = 0;
    for (var index = 1; index < sections.length; index++) {
      final section = sections[index];
      final marker = markers[index - 1];
      final sectionTop = section.getBoundingClientRect().top;
      final target = _nextPageHeaderAfter(pagination, sectionTop);
      if (target == null) {
        missingPages++;
        continue;
      }

      final headerTop = target.getBoundingClientRect().top;
      final headerBottom = target.getBoundingClientRect().bottom;
      final visualOffset = headerBottom - sectionTop;
      if (!visualOffset.isFinite) continue;
      final offset = math.max(0, _layoutOffset(visualOffset)).toDouble();
      marker.style.height = _px(offset);
      final page = int.tryParse(target.getAttribute('data-page-number') ?? '');
      if (page != null && page > 0) {
        marker.setAttribute('data-tw-target-page', '$page');
        floor = math.max(floor, page).toInt();
      }

      // A page header must have positive geometry. This guard keeps a
      // host-mutated/hidden surface from accumulating arbitrary blank space.
      if (headerBottom <= headerTop) marker.style.height = '0px';
    }
    return (floor: floor, missingPages: missingPages);
  }

  web.HTMLElement? _nextPageHeaderAfter(
    web.HTMLElement pagination,
    double top,
  ) {
    final headers = pagination.querySelectorAll('.tw-editor__page-header');
    for (var index = 0; index < headers.length; index++) {
      final node = headers.item(index);
      if (node is! web.HTMLElement) continue;
      if (node.getBoundingClientRect().top > top + _visualOffset(.5)) {
        return node;
      }
    }
    return null;
  }

  WordPaginationMetrics _metricsForHeader(web.HTMLElement header) {
    final sectionId = header.getAttribute('data-tw-section-id');
    if (sectionId != null) {
      for (final pager in _sectionPagers) {
        if (pager.profile.sectionId.value == sectionId) {
          return pager.profile.metrics;
        }
      }
    }
    return _metrics;
  }

  web.HTMLElement _buildBreak(EditorState state, int index) {
    final wrapper = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-break'
      ..setAttribute('data-page-index', '$index');
    final spacer = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-spacer'
      ..setAttribute('data-page-number', '${math.max(1, index)}');
    spacer.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = '0'
      ..height = '0'
      ..marginTop = index == 0 ? '0' : _px(metrics.contentHeight);

    final breaker = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-breaker'
      ..setAttribute('data-tw-page-breaker', '')
      ..setAttribute('data-page-index', '$index');
    breaker.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = _px(metrics.pageWidth)
      ..marginLeft = _px(-metrics.marginLeft)
      ..zIndex = '2';

    if (index > 0) {
      breaker.appendChild(_buildFooter(state, index));
      breaker.appendChild(_buildGap());
    }
    if (index < _pageCount) {
      breaker.appendChild(_buildHeader(state, index + 1));
    }
    wrapper
      ..appendChild(spacer)
      ..appendChild(breaker);
    return wrapper;
  }

  web.HTMLElement _buildHeader(EditorState state, int pageNumber) {
    final header = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-header'
      ..setAttribute('data-page-number', '$pageNumber');
    header.style
      ..position = 'relative'
      ..minHeight = _px(metrics.marginTop)
      ..paddingTop = _px(math.min(metrics.headerFooterGap, metrics.marginTop))
      ..paddingRight = _px(metrics.marginRight)
      ..paddingLeft = _px(metrics.marginLeft)
      ..boxSizing = 'border-box'
      ..backgroundColor = '#fff';
    // Page one is represented by the editable canonical template surface in
    // the shell. Later pages are inert projections of that same model body.
    if (pageNumber > 1) {
      final id = headerBodyId();
      if (id != null)
        header.appendChild(_templateSnapshot(state, id, pageNumber));
    }
    return header;
  }

  web.HTMLElement _buildFooter(EditorState state, int pageNumber) {
    final footer = document.createElement('div') as web.HTMLElement
      ..className = 'tw-editor__page-footer'
      ..setAttribute('data-page-number', '$pageNumber');
    footer.style
      ..position = 'relative'
      ..minHeight = _px(metrics.marginBottom)
      ..paddingRight = _px(metrics.marginRight)
      ..paddingBottom =
          _px(math.min(metrics.headerFooterGap, metrics.marginBottom))
      ..paddingLeft = _px(metrics.marginLeft)
      ..boxSizing = 'border-box'
      ..display = 'flex'
      ..flexDirection = 'column'
      ..justifyContent = 'flex-end'
      ..backgroundColor = '#fff';
    if (pageNumber > 1) {
      final id = footerBodyId();
      if (id != null)
        footer.appendChild(_templateSnapshot(state, id, pageNumber));
    }
    return footer;
  }

  web.HTMLElement _buildGap() =>
      document.createElement('div') as web.HTMLElement
        ..className = 'tw-editor__pagination-gap'
        ..style.height = _px(metrics.pageGap);

  web.Element _templateSnapshot(
    EditorState state,
    BlockId bodyId,
    int pageNumber, {
    int? pageCount,
  }) {
    final snapshot = renderTemplateBodyToDom(
      state.state,
      bodyId,
      components,
      attrs,
      document,
      suggestionView: suggestionView,
      pageNumber: pageNumber,
      pageCount: pageCount ?? _pageCount,
    );
    _makeSnapshotInert(snapshot);
    return snapshot;
  }

  /// The copy is only a page decoration, never an authoritative selection
  /// target. Removing model IDs prevents it from being indexed by
  /// [BrowserSelectionBridge] on the main editable host.
  void _makeSnapshotInert(web.Element root) {
    void clear(web.Element element) {
      element
        ..removeAttribute('data-block-id')
        ..removeAttribute('data-inline-embed')
        ..setAttribute('contenteditable', 'false');
      final descendants = element.querySelectorAll('*');
      for (var index = 0; index < descendants.length; index++) {
        final child = descendants.item(index);
        if (child is web.Element) {
          child
            ..removeAttribute('data-block-id')
            ..removeAttribute('data-inline-embed')
            ..setAttribute('contenteditable', 'false');
        }
      }
    }

    clear(root);
  }

  void _removeDecoration() {
    _decoration?.remove();
    _decoration = null;
    surface.style.removeProperty('min-height');
  }

  /// Converts an offset read from a visual DOM rectangle back to the CSS
  /// layout coordinate system used by [WordPaginationMetrics].
  double _layoutOffset(double visualOffset) => visualOffset / _visualScale;

  /// Converts a layout-space comparison tolerance to visual DOM pixels.
  double _visualOffset(double layoutOffset) => layoutOffset * _visualScale;

  String _px(double value) => '${value.toStringAsFixed(2)}px';
}
