library;

import 'dart:convert';

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../cascade/cascade_pass.dart';
import '../components/component_registry.dart';
import '../render/render.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../state/block_id.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import '../styles/column_config.dart';
import '../styles/style.dart';
import '../url_safety.dart';
import 'computed_style_to_css.dart';

/// Render one styled-tree node to browser DOM.
///
/// Inline text is deliberately wrapped instead of being emitted as a bare
/// [web.Text] whenever it has visual semantics.  This keeps browser formatting,
/// copy/paste, and selection traversal in agreement with the cascaded run.
web.Node? renderNodeToDom(RenderNode node, web.Document document,
    {bool stampBlockIds = false}) {
  if (node is TextBox) return _textBoxToDom(node, document);
  if (node is ElementBox) {
    return _elementBoxToDom(node, document, stampBlockIds);
  }
  return null;
}

web.Node? _elementBoxToDom(
  ElementBox box,
  web.Document document,
  bool stampBlockIds,
) {
  final metadata = box.metadata;
  final display = _displayOf(box);
  if (display == 'none') return null;
  final columnLayout = _columnLayoutOf(metadata, display);
  final rendersSectionLayout = metadata?.blockType == 'section';

  // Sections are transparent in the model/print render tree, but need a real
  // browser formatting context.  Besides owning a distinct CSS-column set,
  // this gives every SectionBreakAction a stable page-break boundary without
  // injecting an artificial model block.  The element stays keyed, so the
  // regular reconciler preserves its descendant paragraph nodes and the live
  // browser selection.
  if (display == 'contents' && !rendersSectionLayout) {
    final fragment = document.createDocumentFragment();
    _appendChildren(
      fragment,
      box.children,
      document,
      _childStamp(stampBlockIds, display, metadata?.embedType != null),
    );
    return fragment;
  }

  // A tab is a document atom (one model offset), not a literal U+0009 text
  // node.  A browser does not expose a word-processor tab-stop primitive, so
  // it receives a stable inline box here and a small post-layout pass below
  // resolves that box to its destination stop.  Keeping it an atom preserves
  // the existing selection-bridge and reconciliation contracts.
  if (metadata?.embedType == _tabEmbedType) {
    return _tabBoxToDom(box, document, stampBlockIds);
  }

  final tag = rendersSectionLayout
      ? 'section'
      : metadata?.headingLevel != null
          ? 'h${metadata!.headingLevel}'
          : metadata?.horizontalLine == true
              ? 'hr'
              : metadata?.image != null
                  ? 'img'
                  : display == 'list-item'
                      ? 'li'
                      : display == 'table'
                          ? 'table'
                          : display == 'table-row'
                              ? 'tr'
                              : display == 'table-cell'
                                  ? 'td'
                                  : display == 'inline' ||
                                          display == 'inline-block'
                                      ? 'span'
                                      : 'div';
  final element = document.createElement(tag);

  _applyStyle(element, box);
  if (rendersSectionLayout) {
    _applySectionLayout(element, columnLayout);
  } else if (columnLayout != null) {
    _applyColumnLayout(element, columnLayout);
  }
  if (display == 'inline-block') _appendStyle(element, 'display: inline-block');
  if (display == 'list-item') {
    // Native markers and browser list indentation are intentionally suppressed:
    // the engine owns both the marker and the reserved gutter.
    _appendStyle(element, 'list-style: none; position: relative');
  }

  _stampBlockId(element, box, stampBlockIds, display);
  _stampManualPageBreak(element, box, display);
  _stampInlineEmbed(element, box, stampBlockIds);
  _stampTabContext(element, box, display);
  final drawing = metadata?.drawing;
  if (drawing != null) _applyDrawingPresentation(element, drawing);
  final rowSpan = metadata?.rowSpan;
  if (rowSpan != null && rowSpan > 1) {
    element.setAttribute('rowspan', '$rowSpan');
  }
  final colSpan = metadata?.colSpan;
  if (colSpan != null && colSpan > 1) {
    element.setAttribute('colspan', '$colSpan');
  }
  if (metadata?.embedType != null) {
    // All inline embeds represent exactly one document offset.  Keeping them
    // non-editable prevents the browser from placing text inside an atom.
    element.setAttribute('contenteditable', 'false');
  }

  if (metadata?.image != null) {
    final image = metadata!.image!;
    element.setAttribute('src', isSafeImageUrl(image.src) ? image.src : '');
    // width/height="0" hides an otherwise valid intrinsic image. Imported
    // images without explicit dimensions should remain visible.
    if (image.width.isFinite && image.width > 0) {
      element.setAttribute('width', '${image.width}');
    }
    if (image.height.isFinite && image.height > 0) {
      element.setAttribute('height', '${image.height}');
    }
    element.setAttribute('alt', image.alt ?? '');
    return element;
  }
  if (metadata?.horizontalLine == true) return element;

  _appendChildren(
    element,
    box.children,
    document,
    _childStamp(stampBlockIds, display, metadata?.embedType != null),
  );
  if (!rendersSectionLayout && columnLayout != null) {
    _spanDirectSectionsAcrossParentColumns(element);
  }
  _fillEmptyLineHost(element, box, display, document);
  if (display == 'list-item') {
    _renderListMarker(element, box.computedStyle?.markerText, document);
  }
  return element;
}

/// Adds browser-only visual semantics for text boxes and drawing shapes.
///
/// Geometry and colors arrive through [DrawingProperties], which already
/// accepts only finite dimensions and safe color tokens. We therefore append
/// presentation declarations without allowing a serialized drawing attribute
/// to escape into an arbitrary CSS declaration.
void _applyDrawingPresentation(
  web.Element element,
  DrawingMetadata drawing,
) {
  final properties = drawing.properties;
  element
    ..setAttribute('data-tw-drawing', drawing.kind)
    ..setAttribute('data-tw-drawing-align', properties.alignment.value)
    ..setAttribute('data-tw-drawing-fill', properties.fill)
    ..setAttribute('data-tw-drawing-outline', properties.outline)
    ..setAttribute(
        'data-tw-drawing-outline-width', '${properties.outlineWidth}')
    ..setAttribute(
        'aria-label', drawing.acceptsText ? 'Forma editável' : 'Linha');
  _appendStyle(element, 'position: relative; overflow: hidden');
  if (drawing.kind == 'ellipse') {
    _appendStyle(element, 'border-radius: 50%');
  } else if (drawing.kind == 'line') {
    final thickness = properties.outlineWidth <= 0
        ? 0.0
        : properties.outlineWidth < 1
            ? 1.0
            : properties.outlineWidth;
    final half = thickness / 2;
    _appendStyle(
      element,
      'padding: 0; border: 0; background: linear-gradient('
      'to bottom, transparent calc(50% - ${_cssPixels(half)}), '
      '${properties.outline} calc(50% - ${_cssPixels(half)}), '
      '${properties.outline} calc(50% + ${_cssPixels(half)}), '
      'transparent calc(50% + ${_cssPixels(half)}))',
    );
    element.setAttribute('contenteditable', 'false');
  }
}

const String _tabEmbedType = 'tab';

/// Creates the browser-side representation of a model tab atom.
///
/// The actual inline advance is deliberately initialized to zero.  Once the
/// parent paragraph is mounted, [layoutTabStopsInDom] can read its real
/// content edge and resolve the advance without inserting text nodes or
/// wrapper children that would distort model offsets.
web.HTMLElement _tabBoxToDom(
  ElementBox box,
  web.Document document,
  bool stampBlockIds,
) {
  final tab = document.createElement('span') as web.HTMLElement;
  _applyStyle(tab, box);
  _appendStyle(
    tab,
    'display: inline-block; inline-size: 0px; block-size: 1em; '
    'vertical-align: baseline; overflow: hidden; white-space: nowrap',
  );
  _stampInlineEmbed(tab, box, stampBlockIds);
  tab
    ..setAttribute('data-tw-tab', '')
    ..setAttribute('data-tw-tab-layout', 'pending')
    ..setAttribute('data-tw-tab-leader', 'none')
    ..setAttribute('contenteditable', 'false')
    ..setAttribute('aria-label', 'Tabulação');
  return tab;
}

/// Marks a leaf line that contains a tab atom with the stop list needed by the
/// browser-flow layout pass.  The JSON is presentation data derived from the
/// cascaded style; it is never treated as document state or written back to
/// the model.
void _stampTabContext(web.Element element, ElementBox box, String display) {
  if (!_isBlockLevelDisplay(display) || !_hasDirectTabEmbed(box)) return;
  final style = box.computedStyle;
  if (style == null) return;
  final encodedStops = <Map<String, dynamic>>[
    for (final stop in style.tabStops)
      if (stop.position.isFinite)
        {
          'position': stop.position,
          'alignment': stop.alignment.value,
          'leader': stop.leader.value,
        },
  ];
  final defaultStop = style.defaultTabStop.isFinite && style.defaultTabStop > 0
      ? style.defaultTabStop
      : 48.0;
  element
    ..setAttribute('data-tw-tab-context', '')
    ..setAttribute('data-tw-tab-stops', jsonEncode(encodedStops))
    ..setAttribute('data-tw-default-tab-stop', '$defaultStop')
    ..setAttribute('data-tw-tab-stop-count', '${encodedStops.length}');
}

bool _hasDirectTabEmbed(ElementBox box) {
  for (final child in box.children) {
    if (child is ElementBox && child.metadata?.embedType == _tabEmbedType) {
      return true;
    }
  }
  return false;
}

String _displayOf(RenderNode node) =>
    node.computedStyle?.display.value ?? 'block';

/// A browser-flowed projection of the model's per-section column attributes.
///
/// The print backend owns true page fragmentation.  The digital backend has no
/// page geometry, but CSS multi-column layout is a faithful, editable visual
/// projection for a section (or the implicit document section) with two or
/// more columns.
class _ColumnLayout {
  final int count;
  final double gap;
  final ColumnRule? rule;

  const _ColumnLayout({
    required this.count,
    required this.gap,
    required this.rule,
  });
}

_ColumnLayout? _columnLayoutOf(LayoutBoxMetadata? metadata, String display) {
  if (metadata == null ||
      (metadata.blockType != 'section' &&
          display != 'block' &&
          display != 'flow-root')) {
    return null;
  }

  final rawCount = metadata.columnCount;
  if (rawCount is! num || !rawCount.isFinite) return null;
  final count = rawCount.toInt();
  // CSS column-count is an integer.  Treat malformed values as absent rather
  // than coercing the document into a surprise layout.
  if (count < 2 || rawCount != count) return null;

  final rawGap = metadata.columnGap;
  final gap = rawGap is num && rawGap.isFinite && rawGap >= 0
      ? rawGap.toDouble()
      : defaultColumnGap;
  final rawRule = metadata.columnRule;
  final rule = rawRule is ColumnRule ? rawRule : null;
  return _ColumnLayout(count: count, gap: gap, rule: rule);
}

void _applyColumnLayout(web.Element element, _ColumnLayout layout) {
  // A section component is normally `display: contents`; overriding it here
  // is deliberate because CSS columns require a principal box.  The override
  // is appended after the cascaded style so it wins without changing the core
  // render tree used by non-browser backends.
  final declarations = <String>[
    'display: block',
    'column-count: ${layout.count}',
    'column-gap: ${_cssPixels(layout.gap)}',
  ];
  final rule = layout.rule;
  if (rule != null &&
      rule.width.isFinite &&
      rule.width > 0 &&
      rule.style != BorderStyle.none &&
      rule.color.trim().isNotEmpty) {
    declarations.add(
      'column-rule: ${_cssPixels(rule.width)} ${rule.style.value} '
      '${rule.color.trim()}',
    );
  }
  _appendStyle(element, declarations.join('; '));
  element.setAttribute('data-tw-column-count', '${layout.count}');
}

/// Makes an explicit model section a browser-flow boundary.
///
/// A `section` is normally `display: contents` in the shared render tree,
/// which is right for non-browser backends but makes both CSS fragmentation
/// and independent columns impossible.  The digital projection gives it a
/// principal block box instead.  When an outer document owns columns, its
/// renderer adds `column-span: all` only to direct section children. Keeping
/// that property off ordinary sections is important for the Word float
/// paginator: a spanner creates a browser block-formatting context that cannot
/// flow through the generated page floats.
///
/// `break-before` / its legacy alias are meaningful in print and native
/// fragmented contexts.  The Word shell's float paginator also reads the
/// data marker to materialize the same boundary in its screen-only pages.
void _applySectionLayout(web.Element element, _ColumnLayout? columns) {
  final declarations = <String>[
    'display: block',
    'break-before: page',
    'page-break-before: always',
  ];
  if (columns != null) {
    declarations.addAll([
      'column-count: ${columns.count}',
      'column-gap: ${_cssPixels(columns.gap)}',
    ]);
    final rule = columns.rule;
    if (rule != null &&
        rule.width.isFinite &&
        rule.width > 0 &&
        rule.style != BorderStyle.none &&
        rule.color.trim().isNotEmpty) {
      declarations.add(
        'column-rule: ${_cssPixels(rule.width)} ${rule.style.value} '
        '${rule.color.trim()}',
      );
    }
    element.setAttribute('data-tw-column-count', '${columns.count}');
  }
  _appendStyle(element, declarations.join('; '));
  element
    ..setAttribute('data-tw-section', '')
    ..setAttribute('data-tw-section-break', 'page');
}

/// Keeps explicit sections independent when the document root has inherited
/// CSS columns. This is deliberately applied by the *parent* renderer, rather
/// than on every section, so the normal paginated Word surface remains a plain
/// block flow around the float chain.
void _spanDirectSectionsAcrossParentColumns(web.Element parent) {
  final children = parent.children;
  for (var index = 0; index < children.length; index++) {
    final child = children.item(index);
    if (child is! web.Element || !child.hasAttribute('data-tw-section')) {
      continue;
    }
    _appendStyle(child, 'column-span: all');
    child.setAttribute('data-tw-section-spans-parent-columns', '');
  }
}

String _cssPixels(double value) {
  final normalized = value == 0 ? 0.0 : value;
  final integral = normalized.truncateToDouble() == normalized;
  return '${integral ? normalized.toInt() : normalized}px';
}

bool _isBlockLevelDisplay(String display) =>
    display != 'inline' && display != 'inline-block';

bool _childStamp(bool stampBlockIds, String display, bool isInlineEmbed) =>
    stampBlockIds && _isBlockLevelDisplay(display) && !isInlineEmbed;

void _stampBlockId(
  web.Element element,
  ElementBox box,
  bool stampBlockIds,
  String display,
) {
  if (!stampBlockIds ||
      box.metadata?.embedType != null ||
      !_isBlockLevelDisplay(display)) {
    return;
  }
  element.setAttribute('data-block-id', box.key);
}

/// Marks the authored block that begins after a manual page break.
///
/// The model deliberately uses a block attribute instead of an artificial DOM
/// node, so the marker gives physical-page projections a stable, keyed anchor
/// without changing editing offsets. Explicit sections have their own marker
/// and are intentionally excluded.
void _stampManualPageBreak(
  web.Element element,
  ElementBox box,
  String display,
) {
  if (!_isBlockLevelDisplay(display) ||
      box.metadata?.blockType == 'section' ||
      box.computedStyle?.breakBefore != BreakBefore.page) {
    return;
  }
  element.setAttribute('data-tw-manual-page-break', '');
}

void _stampInlineEmbed(
  web.Element element,
  ElementBox box,
  bool stampBlockIds,
) {
  if (stampBlockIds && box.metadata?.embedType != null) {
    element.setAttribute('data-inline-embed', '');
  }
}

void _applyStyle(web.Element element, RenderNode node) {
  final computed = node.computedStyle;
  if (computed == null) return;
  _appendStyle(element, computedStyleToInlineStyle(computed));
}

void _appendStyle(web.Element element, String css) {
  if (css.isEmpty) return;
  final existing = element.getAttribute('style');
  element.setAttribute(
    'style',
    existing == null || existing.isEmpty ? css : '$existing; $css',
  );
}

/// Resolves model tab atoms into browser-flowed inline advances.
///
/// The renderer can create the tab atom while the document is detached, but
/// only a mounted browser node knows a paragraph's actual content edge and
/// line position.  This pass therefore runs after a digital reconciler mounts
/// or updates its root.  It mutates only presentation attributes/styles on the
/// existing tab spans: no text nodes, model blocks, or keys are added/removed.
/// That keeps tab positions as a single model offset for the DOM selection
/// bridge and lets ordinary keyed reconciliation retain the paragraph DOM.
///
/// Horizontal LTR paragraphs use a read-only DOM [web.Range] look-ahead for
/// center, right and decimal stops.  The range spans only the inline segment
/// between this tab atom and the next one, so no wrappers, text nodes or model
/// offsets are introduced.  A stop is applied only when that segment stays on
/// one browser line and can fit at the requested destination; otherwise the
/// tab records an explicit browser-flow fallback.  Vertical and RTL layout
/// remain explicit four-ch fallbacks because their inline geometry is not the
/// left-to-right coordinate system used by this projection.
void layoutTabStopsInDom(web.Element root, {web.Window? window}) {
  final ownerWindow = window ?? root.ownerDocument?.defaultView ?? web.window;
  final groups = <web.HTMLElement, List<web.HTMLElement>>{};
  final unowned = <web.HTMLElement>[];

  for (final tab in _elementsMatching(root, '[data-tw-tab]')) {
    final context = _nearestTabContext(tab);
    if (context == null || !root.contains(context)) {
      unowned.add(tab);
      continue;
    }
    (groups[context] ??= <web.HTMLElement>[]).add(tab);
  }

  for (final entry in groups.entries) {
    _layoutTabsInContext(entry.key, entry.value, ownerWindow);
  }
  for (final tab in unowned) {
    _applyFallbackTabLayout(tab, reason: 'no-context');
  }
}

List<web.HTMLElement> _elementsMatching(web.Element root, String selector) {
  final result = <web.HTMLElement>[];
  if (root.hasAttribute('data-tw-tab')) {
    result.add(root as web.HTMLElement);
  }
  final matches = root.querySelectorAll(selector);
  for (var index = 0; index < matches.length; index++) {
    final match = matches.item(index);
    if (match != null) result.add(match as web.HTMLElement);
  }
  return result;
}

web.HTMLElement? _nearestTabContext(web.Element element) {
  web.Node? current = element.parentNode;
  while (current != null) {
    if (current.nodeType == web.Node.ELEMENT_NODE) {
      final candidate = current as web.HTMLElement;
      if (candidate.hasAttribute('data-tw-tab-context')) return candidate;
    }
    current = current.parentNode;
  }
  return null;
}

class _DomTabStop {
  final double position;
  final String alignment;
  final String leader;

  const _DomTabStop({
    required this.position,
    required this.alignment,
    required this.leader,
  });
}

class _TabDestination {
  final double position;
  final _DomTabStop? stop;

  const _TabDestination({required this.position, required this.stop});
}

/// The contiguous inline model content after a tab and before the next tab.
///
/// The DOM range is only inspected; it is never extracted, surrounded or
/// inserted into.  This is important because each `data-tw-tab` element is one
/// model offset and browser selection mapping relies on that identity.
class _TabLookaheadSegment {
  final web.Range range;
  final List<web.Text> textNodes;
  final bool hasHardBreak;

  const _TabLookaheadSegment({
    required this.range,
    required this.textNodes,
    required this.hasHardBreak,
  });
}

class _TabLineGeometry {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const _TabLineGeometry({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  double get width => right - left;
}

class _TabAlignmentAnchor {
  final double x;
  final String layout;

  const _TabAlignmentAnchor({required this.x, required this.layout});
}

void _layoutTabsInContext(
  web.HTMLElement context,
  List<web.HTMLElement> tabs,
  web.Window window,
) {
  if (!context.isConnected) return;
  final css = window.getComputedStyle(context);
  final writingMode = css.getPropertyValue('writing-mode').trim().toLowerCase();
  final direction = css.getPropertyValue('direction').trim().toLowerCase();
  if (writingMode.startsWith('vertical') || direction == 'rtl') {
    for (final tab in tabs) {
      _applyFallbackTabLayout(tab,
          reason: writingMode.startsWith('vertical') ? 'vertical' : 'rtl');
    }
    return;
  }

  final bounds = context.getBoundingClientRect();
  final contentStart = bounds.left +
      _cssPixelValue(css.getPropertyValue('border-left-width')) +
      _cssPixelValue(css.getPropertyValue('padding-left'));
  final contentEnd = bounds.right -
      _cssPixelValue(css.getPropertyValue('border-right-width')) -
      _cssPixelValue(css.getPropertyValue('padding-right'));
  final contentSize = contentEnd - contentStart;
  if (!contentSize.isFinite || contentSize <= 0) {
    for (final tab in tabs) {
      _applyFallbackTabLayout(tab, reason: 'zero-width');
    }
    return;
  }

  final stops = _decodeTabStops(context.getAttribute('data-tw-tab-stops'));
  final defaultStop = _positiveFinite(double.tryParse(
          context.getAttribute('data-tw-default-tab-stop') ?? '')) ??
      48.0;

  // Start every pass from the zero-advance atom.  Applying each resolved width
  // in DOM order forces the browser to expose the next tab's current line
  // position, so multiple tabs on one line remain browser-flowed rather than
  // relying on stale pre-layout rectangles.
  for (final tab in tabs) {
    _resetTabLayout(tab);
  }
  for (final tab in tabs) {
    final tabBounds = tab.getBoundingClientRect();
    final pen =
        (tabBounds.left - contentStart).clamp(0.0, contentSize).toDouble();
    final defaultDestination = _nextTabDestination(
      pen: pen,
      stops: stops,
      defaultStop: defaultStop,
      contentEdge: contentSize,
    );
    final alignment = defaultDestination.stop?.alignment ?? 'left';
    if (!_requiresFollowingSegment(alignment)) {
      _applyLeftAlignedTabLayout(
        tab,
        destination: defaultDestination,
        pen: pen,
        contentSize: contentSize,
        layout: alignment == 'content-edge' ? 'content-edge' : 'left',
      );
      continue;
    }

    final segment = _followingTabSegment(context, tab);
    final geometry = segment == null || segment.hasHardBreak
        ? null
        : _measureSingleLineSegment(segment);
    if (geometry == null || !_sharesLineWithTab(geometry, tabBounds)) {
      _applyLeftAlignedTabLayout(
        tab,
        destination: defaultDestination,
        pen: pen,
        contentSize: contentSize,
        layout: 'fallback-no-single-line-segment',
      );
      continue;
    }

    // The preceding guard proves the segment is present and contains no hard
    // break. Keep a non-null local because the browser interop calls below are
    // intentionally synchronous and do not mutate this DOM subtree.
    final measuredSegment = segment!;
    final anchor = _alignmentAnchor(alignment, measuredSegment, geometry);
    if (anchor == null) {
      _applyLeftAlignedTabLayout(
        tab,
        destination: defaultDestination,
        pen: pen,
        contentSize: contentSize,
        layout: 'fallback-no-alignment-anchor',
      );
      continue;
    }

    final resolved = _feasibleAlignedDestination(
      destination: defaultDestination,
      pen: pen,
      contentStart: contentStart,
      contentEnd: contentEnd,
      tabBounds: tabBounds,
      segment: geometry,
      anchor: anchor,
    );
    if (resolved == null) {
      _applyLeftAlignedTabLayout(
        tab,
        destination: defaultDestination,
        pen: pen,
        contentSize: contentSize,
        layout: 'fallback-no-feasible-stop',
      );
      continue;
    }

    final targetX = contentStart + resolved.position;
    final advance = targetX - anchor.x;
    _applyResolvedTabLayout(
      tab,
      advance: advance,
      position: resolved.position,
      alignment: alignment,
      leader: resolved.stop!.leader,
      layout: anchor.layout,
    );

    // Width changes can trigger a browser line wrap.  Confirm the resulting
    // line instead of retaining a false alignment label.  The fallback keeps
    // ordinary tab flow intact and remains explicit in the DOM for hosts.
    final finalGeometry = _measureSingleLineSegment(measuredSegment);
    final finalAnchor = finalGeometry == null
        ? null
        : _alignmentAnchor(alignment, measuredSegment, finalGeometry);
    if (finalGeometry == null ||
        finalAnchor == null ||
        !_sharesLineWithTab(finalGeometry, tab.getBoundingClientRect()) ||
        (finalAnchor.x - targetX).abs() > 1.5) {
      _applyLeftAlignedTabLayout(
        tab,
        destination: resolved,
        pen: pen,
        contentSize: contentSize,
        layout: 'fallback-reflow',
      );
    }
  }
}

bool _requiresFollowingSegment(String alignment) =>
    alignment == 'center' || alignment == 'right' || alignment == 'decimal';

_TabDestination _nextTabDestination({
  required double pen,
  required List<_DomTabStop> stops,
  required double defaultStop,
  required double contentEdge,
}) {
  _DomTabStop? best;
  var bestPosition = double.infinity;
  for (final stop in stops) {
    final effective =
        stop.alignment == 'content-edge' ? contentEdge : stop.position;
    if (effective > pen + .01 && effective < bestPosition) {
      best = stop;
      bestPosition = effective;
    }
  }
  if (best != null) {
    return _TabDestination(position: bestPosition, stop: best);
  }
  final grid = defaultStop > 0 ? defaultStop : 48.0;
  return _TabDestination(
    position: (pen / grid).floor() * grid + grid,
    stop: null,
  );
}

void _applyLeftAlignedTabLayout(
  web.HTMLElement tab, {
  required _TabDestination destination,
  required double pen,
  required double contentSize,
  required String layout,
}) {
  final rawAdvance = destination.position - pen;
  final advance = rawAdvance.clamp(0.0, contentSize - pen).toDouble();
  _applyResolvedTabLayout(
    tab,
    advance: advance,
    position: destination.position,
    alignment: destination.stop?.alignment ?? 'left',
    leader: destination.stop?.leader ?? 'none',
    layout: layout,
  );
}

_TabLookaheadSegment? _followingTabSegment(
  web.HTMLElement context,
  web.HTMLElement tab,
) {
  // Tab atoms are direct inline children of their stamped paragraph.  Do not
  // guess across wrappers we did not create: in that unusual host-mutated DOM
  // case the caller takes a declared fallback instead of risking selection
  // boundaries or measuring unrelated content.
  if (tab.parentNode != context) return null;
  final document = context.ownerDocument;
  if (document == null) return null;

  web.HTMLElement? nextTab;
  web.Node? current = tab.nextSibling;
  while (current != null) {
    if (current.nodeType == web.Node.ELEMENT_NODE) {
      final element = current as web.HTMLElement;
      if (element.hasAttribute('data-tw-tab')) {
        nextTab = element;
        break;
      }
    }
    current = current.nextSibling;
  }

  final range = document.createRange()..setStartAfter(tab);
  if (nextTab != null) {
    range.setEndBefore(nextTab);
  } else {
    range.setEnd(context, context.childNodes.length);
  }

  final textNodes = <web.Text>[];
  var hasHardBreak = false;
  current = tab.nextSibling;
  while (current != null && current != nextTab) {
    _collectSegmentTextNodes(current, textNodes);
    hasHardBreak = hasHardBreak || _containsHardBreak(current);
    current = current.nextSibling;
  }
  return _TabLookaheadSegment(
    range: range,
    textNodes: textNodes,
    hasHardBreak: hasHardBreak,
  );
}

void _collectSegmentTextNodes(web.Node node, List<web.Text> output) {
  if (node.nodeType == web.Node.TEXT_NODE) {
    output.add(node as web.Text);
    return;
  }
  for (var index = 0; index < node.childNodes.length; index++) {
    final child = node.childNodes.item(index);
    if (child != null) _collectSegmentTextNodes(child, output);
  }
}

bool _containsHardBreak(web.Node node) {
  if (node.nodeType == web.Node.ELEMENT_NODE) {
    final element = node as web.Element;
    if (element.localName == 'br') return true;
  }
  for (var index = 0; index < node.childNodes.length; index++) {
    final child = node.childNodes.item(index);
    if (child != null && _containsHardBreak(child)) return true;
  }
  return false;
}

_TabLineGeometry? _measureSingleLineSegment(_TabLookaheadSegment segment) {
  final rects = segment.range.getClientRects();
  _TabLineGeometry? result;
  for (var index = 0; index < rects.length; index++) {
    final rect = rects.item(index);
    if (rect == null ||
        !rect.left.isFinite ||
        !rect.right.isFinite ||
        !rect.top.isFinite ||
        !rect.bottom.isFinite ||
        rect.width <= .01 ||
        rect.height <= .01) {
      continue;
    }
    if (result == null) {
      result = _TabLineGeometry(
        left: rect.left,
        right: rect.right,
        top: rect.top,
        bottom: rect.bottom,
      );
      continue;
    }
    if (!_sharesLine(result, rect.top, rect.bottom)) return null;
    result = _TabLineGeometry(
      left: rect.left < result.left ? rect.left : result.left,
      right: rect.right > result.right ? rect.right : result.right,
      top: rect.top < result.top ? rect.top : result.top,
      bottom: rect.bottom > result.bottom ? rect.bottom : result.bottom,
    );
  }
  return result;
}

bool _sharesLine(_TabLineGeometry line, double top, double bottom) =>
    top < line.bottom - .5 && line.top < bottom - .5;

bool _sharesLineWithTab(_TabLineGeometry line, web.DOMRect tabBounds) =>
    line.top < tabBounds.bottom - .5 && tabBounds.top < line.bottom - .5;

_TabAlignmentAnchor? _alignmentAnchor(
  String alignment,
  _TabLookaheadSegment segment,
  _TabLineGeometry geometry,
) {
  switch (alignment) {
    case 'center':
      return _TabAlignmentAnchor(
        x: geometry.left + geometry.width / 2,
        layout: 'center',
      );
    case 'right':
      return _TabAlignmentAnchor(x: geometry.right, layout: 'right');
    case 'decimal':
      final decimal = _decimalAnchor(segment, geometry);
      // Word's conventional behavior for a decimal stop without a separator
      // is to align the number's right edge.  That is still a real alignment,
      // not a left-stop browser fallback.
      return decimal ??
          _TabAlignmentAnchor(x: geometry.right, layout: 'decimal-right');
  }
  return null;
}

_TabAlignmentAnchor? _decimalAnchor(
  _TabLookaheadSegment segment,
  _TabLineGeometry geometry,
) {
  var combined = '';
  final starts = <int>[];
  for (final node in segment.textNodes) {
    starts.add(combined.length);
    combined += node.data;
  }
  if (combined.isEmpty) return null;

  var decimalOffset = -1;
  for (var index = combined.length - 1; index >= 0; index--) {
    final unit = combined.codeUnitAt(index);
    if ((unit == 0x2e || unit == 0x2c) &&
        index + 1 < combined.length &&
        _isAsciiDigit(combined.codeUnitAt(index + 1))) {
      decimalOffset = index;
      break;
    }
  }
  if (decimalOffset < 0) return null;

  for (var index = 0; index < segment.textNodes.length; index++) {
    final start = starts[index];
    final text = segment.textNodes[index].data;
    if (decimalOffset < start || decimalOffset >= start + text.length) {
      continue;
    }
    final document = segment.textNodes[index].ownerDocument;
    if (document == null) return null;
    final range = document.createRange()
      ..setStart(segment.textNodes[index], decimalOffset - start)
      ..setEnd(segment.textNodes[index], decimalOffset - start + 1);
    final rect = range.getBoundingClientRect();
    if (!rect.left.isFinite ||
        !rect.right.isFinite ||
        rect.width <= .01 ||
        !_sharesLine(geometry, rect.top, rect.bottom)) {
      return null;
    }
    return _TabAlignmentAnchor(
      x: rect.left + rect.width / 2,
      layout: 'decimal',
    );
  }
  return null;
}

bool _isAsciiDigit(int unit) => unit >= 0x30 && unit <= 0x39;

_TabDestination? _feasibleAlignedDestination({
  required _TabDestination destination,
  required double pen,
  required double contentStart,
  required double contentEnd,
  required web.DOMRect tabBounds,
  required _TabLineGeometry segment,
  required _TabAlignmentAnchor anchor,
}) {
  final stop = destination.stop;
  final position = destination.position;
  // Explicit center/right/decimal stops are selected by position before
  // browser layout.  Do not silently skip to a later stop of another type:
  // that would change the document's Word semantics.  A non-positive advance
  // or an overflowing following run is a genuine browser-flow limitation and
  // is reported by the caller as an explicit fallback instead.
  if (stop == null ||
      position <= pen + .01 ||
      position > contentEnd - contentStart + .01) {
    return null;
  }
  final targetX = contentStart + position;
  final advance = targetX - anchor.x;
  if (!advance.isFinite || advance < -.25) return null;
  final shiftedLeft = segment.left + advance;
  final shiftedRight = segment.right + advance;
  if (shiftedLeft < tabBounds.right - .25 || shiftedRight > contentEnd + .25) {
    return null;
  }
  return destination;
}

List<_DomTabStop> _decodeTabStops(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final result = <_DomTabStop>[];
    for (final candidate in decoded) {
      if (candidate is! Map) continue;
      final rawPosition = candidate['position'];
      final position = rawPosition is num
          ? rawPosition.toDouble()
          : double.tryParse('$rawPosition');
      final alignment = candidate['alignment'];
      final leader = candidate['leader'];
      if (position == null || !position.isFinite || position < 0) continue;
      if (alignment is! String || leader is! String) continue;
      result.add(_DomTabStop(
        position: position,
        alignment: alignment,
        leader: leader,
      ));
    }
    result.sort((a, b) => a.position.compareTo(b.position));
    return result;
  } catch (_) {
    // Presentation metadata is allowed to be absent/corrupt in a host-mutated
    // DOM.  The default-grid tab remains a useful editable fallback.
    return const [];
  }
}

double? _positiveFinite(double? value) =>
    value != null && value.isFinite && value > 0 ? value : null;

double _cssPixelValue(String raw) {
  final parsed = double.tryParse(raw.trim().replaceFirst(RegExp(r'px$'), ''));
  return parsed != null && parsed.isFinite ? parsed : 0.0;
}

void _resetTabLayout(web.HTMLElement tab) {
  tab.style
    ..setProperty('inline-size', '0px')
    ..removeProperty('background-image')
    ..removeProperty('background-size')
    ..removeProperty('background-position')
    ..removeProperty('background-repeat');
  tab
    ..setAttribute('data-tw-tab-layout', 'pending')
    ..setAttribute('data-tw-tab-leader', 'none')
    ..removeAttribute('data-tw-tab-position')
    ..removeAttribute('data-tw-tab-advance')
    ..removeAttribute('data-tw-tab-alignment');
}

void _applyFallbackTabLayout(web.HTMLElement tab, {required String reason}) {
  _resetTabLayout(tab);
  tab.style.setProperty('inline-size', '4ch');
  tab
    ..setAttribute('data-tw-tab-layout', 'fallback-$reason')
    ..setAttribute('data-tw-tab-advance', '4ch');
}

void _applyResolvedTabLayout(
  web.HTMLElement tab, {
  required double advance,
  required double position,
  required String alignment,
  required String leader,
  required String layout,
}) {
  final normalizedAdvance = advance.isFinite && advance > 0 ? advance : 0.0;
  tab.style
      .setProperty('inline-size', '${normalizedAdvance.toStringAsFixed(3)}px');
  tab
    ..setAttribute('data-tw-tab-layout', layout)
    ..setAttribute('data-tw-tab-alignment', alignment)
    ..setAttribute('data-tw-tab-leader', leader)
    ..setAttribute('data-tw-tab-position', position.toStringAsFixed(3))
    ..setAttribute('data-tw-tab-advance', normalizedAdvance.toStringAsFixed(3));
  _applyTabLeader(tab, leader);
}

void _applyTabLeader(web.HTMLElement tab, String leader) {
  final style = tab.style;
  switch (leader) {
    case 'dot':
      style
        ..setProperty(
          'background-image',
          'radial-gradient(circle, currentColor 0.75px, transparent 0.9px)',
        )
        ..setProperty('background-size', '4px 2px')
        ..setProperty('background-position', 'left calc(100% - 0.18em)')
        ..setProperty('background-repeat', 'repeat-x');
      return;
    case 'dash':
      style
        ..setProperty(
          'background-image',
          'repeating-linear-gradient(to right, currentColor 0px, '
              'currentColor 4px, transparent 4px, transparent 7px)',
        )
        ..setProperty('background-size', 'auto 1px')
        ..setProperty('background-position', 'left calc(100% - 0.18em)')
        ..setProperty('background-repeat', 'repeat-x');
      return;
    case 'line':
      style
        ..setProperty(
          'background-image',
          'linear-gradient(to right, currentColor, currentColor)',
        )
        ..setProperty('background-size', '100% 1px')
        ..setProperty('background-position', 'left calc(100% - 0.18em)')
        ..setProperty('background-repeat', 'no-repeat');
      return;
    default:
      return;
  }
}

const _lineHostDisplays = <String>{
  'block',
  'flow-root',
  'list-item',
  'table-cell',
};

/// Inserts a marked `<br>` for an otherwise empty editable line.  Empty styled
/// run wrappers do not create a browser line box, so they are replaced with the
/// filler; the selection bridge treats this marker as zero model offsets.
void _fillEmptyLineHost(
  web.Element element,
  ElementBox box,
  String display,
  web.Document document,
) {
  if (!_lineHostDisplays.contains(display)) return;
  if (_hasNestedBlockChild(box) ||
      element.querySelector('[data-block-id]') != null ||
      (element.textContent ?? '').isNotEmpty ||
      element.querySelector('img, [data-inline-embed]') != null) {
    return;
  }

  while (element.firstChild != null) {
    element.removeChild(element.firstChild!);
  }
  final filler = document.createElement('br');
  filler.setAttribute('data-tw-empty-line', '');
  element.appendChild(filler);
}

bool _hasNestedBlockChild(ElementBox box) {
  for (final child in box.children) {
    if (child is ElementBox &&
        child.metadata?.embedType == null &&
        _isBlockLevelDisplay(_displayOf(child))) {
      return true;
    }
  }
  return false;
}

class _ListDomMetadata {
  final int level;
  final String listId;
  final bool ordered;

  const _ListDomMetadata({
    required this.level,
    required this.listId,
    required this.ordered,
  });
}

class _OpenList {
  final web.Element element;
  final String listId;
  final bool ordered;
  web.Element? lastItem;

  _OpenList({
    required this.element,
    required this.listId,
    required this.ordered,
  });
}

_ListDomMetadata? _listMetadataOf(RenderNode node) {
  if (node is! ElementBox || _displayOf(node) != 'list-item') return null;
  final list = node.metadata?.list;
  if (list == null) return null;
  return _ListDomMetadata(
    level: list.level,
    listId: list.listId,
    ordered: list.ordered,
  );
}

/// Appends children while grouping adjacent logical list items into real
/// `<ol>` / `<ul>` containers.  The list item itself stays keyed and carries
/// the cascaded list style, so reconciliation and selection can still address
/// the authored block directly.
void _appendChildren(
  web.Node parent,
  List<RenderNode> children,
  web.Document document,
  bool stampBlockIds,
) {
  final stack = <_OpenList>[];

  for (final child in children) {
    final list = _listMetadataOf(child);
    if (list == null) {
      stack.clear();
      final childNode = renderNodeToDom(
        child,
        document,
        stampBlockIds: stampBlockIds,
      );
      if (childNode != null) parent.appendChild(childNode);
      continue;
    }

    final level = list.level < stack.length ? list.level : stack.length;
    while (stack.length > level + 1) {
      stack.removeLast();
    }
    final current = level < stack.length ? stack[level] : null;
    if (current == null ||
        current.listId != list.listId ||
        current.ordered != list.ordered) {
      while (stack.length > level) {
        stack.removeLast();
      }
      final listElement = document.createElement(list.ordered ? 'ol' : 'ul');
      listElement.setAttribute(
          'style', 'margin: 0; padding: 0; list-style: none');
      final mount = level > 0 ? (stack[level - 1].lastItem ?? parent) : parent;
      mount.appendChild(listElement);
      stack.add(_OpenList(
        element: listElement,
        listId: list.listId,
        ordered: list.ordered,
      ));
    }

    final childNode = renderNodeToDom(
      child,
      document,
      stampBlockIds: stampBlockIds,
    );
    if (childNode == null) continue;
    final openList = stack[level];
    openList.element.appendChild(childNode);
    if (childNode is web.Element) openList.lastItem = childNode;
  }
}

void _renderListMarker(
  web.Element listItem,
  String? markerText,
  web.Document document,
) {
  if (markerText == null || markerText.isEmpty) return;
  final marker = document.createElement('span');
  marker.setAttribute('data-tw-marker', '');
  marker.setAttribute('contenteditable', 'false');
  marker.setAttribute(
    'style',
    'position: absolute; inset-inline-start: 0; inset-block-start: 0; '
        'user-select: none; pointer-events: none; white-space: nowrap',
  );
  marker.appendChild(document.createTextNode(markerText));
  // It is appended after text/filler, but pinned to the first line.  This keeps
  // generated content out of offset accounting and out of the editable flow.
  listItem.appendChild(marker);
}

web.Node _textBoxToDom(TextBox box, web.Document document) {
  final computed = box.computedStyle;
  web.Node current = document.createTextNode(box.text);

  final css = computed == null ? '' : computedStyleToInlineStyle(computed);
  if (css.isNotEmpty) {
    final span = document.createElement('span');
    span.setAttribute('style', css);
    span.appendChild(current);
    current = span;
  }
  if (computed != null && computed.lineThrough) {
    current = _wrap(document, 's', current);
  }
  if (computed != null && computed.underline) {
    current = _wrap(document, 'u', current);
  }
  if (computed != null && computed.fontStyle == FontStyle.italic) {
    current = _wrap(document, 'em', current);
  }
  if (computed != null && computed.fontWeight.value == FontWeight.bold.value) {
    current = _wrap(document, 'strong', current);
  }

  final link = box.link;
  if (link != null && isExportSafeLinkUrl(link)) {
    final anchor = document.createElement('a');
    anchor.setAttribute('href', link);
    anchor.appendChild(current);
    current = anchor;
  }
  return current;
}

web.Element _wrap(web.Document document, String tag, web.Node child) {
  final element = document.createElement(tag);
  element.appendChild(child);
  return element;
}

/// Render a complete State through the styled render tree into browser-flowed
/// DOM. This is the digital backend entry point; it performs no geometry.
web.Element renderDocumentToDom(
  State state,
  ComponentRegistry components,
  AttrRegistry attrs,
  web.Document document, {
  SuggestionView suggestionView = SuggestionView.suggesting,
  Map<BlockId, int>? pageNumbers,
}) {
  // Use the caller-provided registry for inline runs as well as preserving the
  // public rendering API's default registry for callers that do not inject one.
  final root = cascadePass(renderState(
    state,
    components,
    attrs: attrs,
    suggestionView: suggestionView,
    pageNumbers: pageNumbers,
  ).root);
  final node = renderNodeToDom(root, document, stampBlockIds: true);
  if (node != null && node.nodeType == web.Node.ELEMENT_NODE) {
    return node as web.Element;
  }
  final wrapper = document.createElement('div');
  if (node != null) wrapper.appendChild(node);
  return wrapper;
}

/// Renders one header or footer tree from `templateContents` into a browser
/// DOM subtree. It intentionally shares the same cascade, keys and selection
/// stamps as the main document so a second [DigitalEditorHost] can edit the
/// template while sharing its controller with the document host.
web.Element renderTemplateBodyToDom(
  State state,
  BlockId bodyRootId,
  ComponentRegistry components,
  AttrRegistry attrs,
  web.Document document, {
  SuggestionView suggestionView = SuggestionView.suggesting,
  Map<BlockId, int>? pageNumbers,
  int pageNumber = 1,
  int pageCount = 1,
}) {
  final root = cascadePass(renderTemplateBody(
    state,
    bodyRootId,
    components,
    attrs: attrs,
    suggestionView: suggestionView,
    pageNumbers: pageNumbers,
    pageNumber: pageNumber,
    pageCount: pageCount,
  ).root);
  final node = renderNodeToDom(root, document, stampBlockIds: true);
  if (node != null && node.nodeType == web.Node.ELEMENT_NODE) {
    return node as web.Element;
  }
  final wrapper = document.createElement('div');
  if (node != null) wrapper.appendChild(node);
  return wrapper;
}
