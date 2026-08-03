/// Small JavaScript facade for the embeddable Word-style editor.
///
/// This library deliberately exposes only JSON-shaped options and a fixed,
/// validated command list. The browser entry point in
/// `web/taleweaver_editor_js.dart` installs it as `globalThis.Taleweaver`.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../editor/editor_action.dart';
import '../state/block_position.dart';
import '../state/block_traversal.dart';
import '../state/drawing.dart';
import '../state/extract_text.dart';
import '../state/inline_content.dart';
import '../state/page_config.dart';
import 'word_editor.dart';

typedef _JsonMap = Map<String, Object?>;

typedef _DrawingCommandOptions = ({
  String text,
  double? width,
  double? height,
  DrawingAlignment? alignment,
  String? fill,
  String? outline,
  double? outlineWidth,
});

final _TaleweaverJsApi _globalTaleweaverJsApi = _TaleweaverJsApi();
JSObject? _globalTaleweaverJsWrapper;

/// Installs the `globalThis.Taleweaver` object used by plain JavaScript.
///
/// The function is idempotent and may be called by every compiled entry point
/// that wants to offer the JavaScript surface in the same browser document.
JSObject installTaleweaverJsInterop() {
  final wrapper = _globalTaleweaverJsWrapper ??=
      createJSInteropWrapper(_globalTaleweaverJsApi);
  globalContext.setProperty('Taleweaver'.toJS, wrapper);
  return wrapper;
}

/// Exported only through [installTaleweaverJsInterop].
final class _TaleweaverJsApi {
  /// Mounts a complete Taleweaver editor in [host].
  ///
  /// `options` must contain JSON values only. Callback functions, controllers,
  /// DOM nodes, and arbitrary action objects are intentionally outside this
  /// facade; Dart hosts can use [TaleweaverEditor.mount] directly for those.
  @JSExport('mount')
  JSObject mount(JSObject host, [JSObject? options]) {
    if (!host.isA<web.HTMLElement>()) {
      throw ArgumentError.value(host, 'host', 'must be an HTMLElement');
    }
    final editor = TaleweaverEditor.mount(
      host as web.HTMLElement,
      options:
          _editorOptionsFromJson(_decodeJsonObject(options, name: 'options')),
    );
    return createJSInteropWrapper(_TaleweaverJsEditorHandle(editor));
  }
}

/// JavaScript-facing, per-editor handle returned by `Taleweaver.mount`.
///
/// Every mutating entry point is safe after destruction: it returns `false`
/// instead of reaching into a removed DOM surface. [execute] additionally
/// respects viewer mode, matching the visible editor chrome.
final class _TaleweaverJsEditorHandle {
  TaleweaverEditor? _editor;

  _TaleweaverJsEditorHandle(this._editor);

  TaleweaverEditor? get _liveEditor {
    final editor = _editor;
    if (editor == null || editor.isDestroyed) return null;
    return editor;
  }

  @JSExport('focus')
  JSBoolean focus() {
    final editor = _liveEditor;
    if (editor == null) return false.toJS;
    editor.focus();
    return true.toJS;
  }

  @JSExport('destroy')
  JSBoolean destroy() {
    final editor = _editor;
    if (editor == null) return false.toJS;
    _editor = null;
    editor.destroy();
    return true.toJS;
  }

  @JSExport('setMode')
  JSBoolean setMode(JSString value) {
    final editor = _liveEditor;
    final mode = _editorModeFromString(value.toDart);
    if (editor == null || mode == null) return false.toJS;
    editor.setMode(mode);
    return true.toJS;
  }

  @JSExport('setDocumentView')
  JSBoolean setDocumentView(JSString value) {
    final editor = _liveEditor;
    final view = _documentViewFromString(value.toDart);
    if (editor == null || view == null) return false.toJS;
    editor.setDocumentView(view);
    return true.toJS;
  }

  @JSExport('setZoom')
  JSBoolean setZoom(JSNumber value) {
    final editor = _liveEditor;
    final zoom = value.toDartDouble;
    if (editor == null || !zoom.isFinite) return false.toJS;
    editor.setZoom(zoom);
    return true.toJS;
  }

  @JSExport('setDocumentTitle')
  JSBoolean setDocumentTitle(JSString value) {
    final editor = _liveEditor;
    if (editor == null) return false.toJS;
    editor.setDocumentTitle(value.toDart);
    return true.toJS;
  }

  @JSExport('setRulersVisible')
  JSBoolean setRulersVisible(JSBoolean value) {
    final editor = _liveEditor;
    if (editor == null) return false.toJS;
    editor.setRulersVisible(value.toDart);
    return true.toJS;
  }

  @JSExport('setStatusBarVisible')
  JSBoolean setStatusBarVisible(JSBoolean value) {
    final editor = _liveEditor;
    if (editor == null) return false.toJS;
    editor.setStatusBarVisible(value.toDart);
    return true.toJS;
  }

  /// Returns the text from all leaf blocks, using the normal embed serializer.
  @JSExport('getText')
  JSString getText() {
    final editor = _liveEditor;
    return (editor == null ? '' : _documentText(editor)).toJS;
  }

  /// Executes one command from the fixed public command vocabulary.
  ///
  /// It returns `false` for an unknown/malformed command, a destroyed handle,
  /// or viewer mode. It never accepts a caller-provided action name or an
  /// arbitrary document mutation object.
  @JSExport('execute')
  JSBoolean execute(JSString rawCommand, [JSObject? rawArguments]) {
    final editor = _liveEditor;
    if (editor == null || editor.mode == TaleweaverEditorMode.viewer) {
      return false.toJS;
    }
    try {
      final action = _actionForCommand(
        rawCommand.toDart,
        _decodeJsonObject(rawArguments, name: 'command arguments'),
      );
      if (action == null) return false.toJS;
      editor.dispatch(action);
      return true.toJS;
    } on ArgumentError {
      return false.toJS;
    } on FormatException {
      return false.toJS;
    }
  }
}

TaleweaverEditorOptions _editorOptionsFromJson(_JsonMap values) {
  final mode = _editorModeFromString(
          _stringValue(values, 'mode', TaleweaverEditorMode.editor.name)) ??
      (throw ArgumentError.value(
          values['mode'], 'mode', 'must be "editor" or "viewer"'));
  final appearance = _appearanceFromString(_stringValue(
          values, 'appearance', TaleweaverEditorAppearance.word.name)) ??
      (throw ArgumentError.value(
          values['appearance'], 'appearance', 'must be "word" or "compact"'));
  final documentView = _documentViewFromString(_stringValue(
          values, 'documentView', TaleweaverDocumentView.paginated.name)) ??
      (throw ArgumentError.value(values['documentView'], 'documentView',
          'must be "paginated" or "continuous"'));

  return TaleweaverEditorOptions(
    mode: mode,
    appearance: appearance,
    documentView: documentView,
    height: _cssLengthValue(
      values.containsKey('height') ? values['height'] : null,
      name: 'height',
      fallback: '720px',
    ),
    width: _optionalCssLengthValue(values['width'], name: 'width'),
    documentTitle:
        _stringValue(values, 'documentTitle', 'Documento sem título'),
    locale: _stringValue(values, 'locale', 'pt-BR'),
    placeholder: _stringValue(values, 'placeholder', 'Comece a escrever'),
    showToolbar: _booleanValue(
      values,
      'showToolbar',
      _booleanValue(values, 'toolbar', true),
    ),
    showRulers: _booleanValue(
      values,
      'showRulers',
      _booleanValue(values, 'rulers', true),
    ),
    showStatusBar: _booleanValue(
      values,
      'showStatusBar',
      _booleanValue(values, 'statusBar', true),
    ),
    showTitleBar: _booleanValue(
      values,
      'showTitleBar',
      _booleanValue(values, 'titleBar', false),
    ),
    zoom: _finiteNumberValue(values, 'zoom', 1),
    pageConfig: _pageConfigFromJson(values),
    initialText: _optionalStringValue(values, 'initialText'),
    themeVariables: _themeVariablesFromJson(values),
    assets: _assetsFromJson(values),
  );
}

TaleweaverEditorAssets _assetsFromJson(_JsonMap values) {
  final assets = _mapValue(values['assets'], name: 'assets');
  return TaleweaverEditorAssets(
    editorStylesheetUrl: _assetUrl(
      assets,
      values,
      'editorStylesheetUrl',
      TaleweaverEditorAssets.defaultEditorStylesheetUrl,
    ),
    iconStylesheetUrl: _assetUrl(
      assets,
      values,
      'iconStylesheetUrl',
      TaleweaverEditorAssets.defaultIconStylesheetUrl,
    ),
    iconFontFamily: _assetFontFamily(assets, values),
  );
}

PageConfig _pageConfigFromJson(_JsonMap values) {
  const defaults = PageConfig();
  final page = _mapValue(values['page'], name: 'page');
  final margins = _mapValue(
    page.containsKey('margins') ? page['margins'] : values['pageMargins'],
    name: 'page margins',
  );
  final width = _positivePageNumber(
    _firstValue(page, 'width', values, 'pageWidth'),
    name: 'page width',
    fallback: defaults.width,
  );
  final height = _positivePageNumber(
    _firstValue(page, 'height', values, 'pageHeight'),
    name: 'page height',
    fallback: defaults.height,
  );
  final top = _nonNegativePageNumber(
    _firstValue(margins, 'top', values, 'marginTop'),
    name: 'top margin',
    fallback: defaults.margins.top,
  );
  final right = _nonNegativePageNumber(
    _firstValue(margins, 'right', values, 'marginRight'),
    name: 'right margin',
    fallback: defaults.margins.right,
  );
  final bottom = _nonNegativePageNumber(
    _firstValue(margins, 'bottom', values, 'marginBottom'),
    name: 'bottom margin',
    fallback: defaults.margins.bottom,
  );
  final left = _nonNegativePageNumber(
    _firstValue(margins, 'left', values, 'marginLeft'),
    name: 'left margin',
    fallback: defaults.margins.left,
  );
  final headerFooterGap = _nonNegativePageNumber(
    _firstValue(page, 'headerFooterGap', values, 'headerFooterGap'),
    name: 'header/footer gap',
    fallback: defaults.headerFooterGap,
  );
  if (top + bottom >= height || left + right >= width) {
    throw ArgumentError('Page margins must leave a positive text area.');
  }
  return PageConfig(
    width: width,
    height: height,
    margins: PageMargins(top: top, right: right, bottom: bottom, left: left),
    headerFooterGap: headerFooterGap,
  );
}

Map<String, String> _themeVariablesFromJson(_JsonMap values) {
  final raw = _mapValue(values['themeVariables'], name: 'themeVariables');
  final variables = <String, String>{};
  for (final entry in raw.entries) {
    if (!entry.key.startsWith('--') || entry.value is! String) {
      throw ArgumentError.value(
        entry.value,
        'themeVariables.${entry.key}',
        'must map a CSS custom-property name to a string',
      );
    }
    variables[entry.key] = entry.value as String;
  }
  return variables;
}

EditorAction? _actionForCommand(String rawCommand, _JsonMap arguments) {
  switch (rawCommand.trim().toLowerCase()) {
    case 'bold':
      return const ToggleStyleAction('bold');
    case 'italic':
      return const ToggleStyleAction('italic');
    case 'underline':
      return const ToggleStyleAction('underline');
    case 'undo':
      return const UndoAction();
    case 'redo':
      return const RedoAction();
    case 'paste':
      final text = _optionalStringValue(arguments, 'text');
      return text == null ? null : PasteTextAction(text);
    case 'pagebreak':
    case 'page-break':
      return const PageBreakAction();
    case 'heading':
      return SetHeadingLevelAction(
        _integerValue(arguments, 'level', fallback: 1, min: 1, max: 6),
      );
    case 'list':
      final type = _stringValue(arguments, 'type', 'unordered').toLowerCase();
      return switch (type) {
        'unordered' || 'bullets' => const ToggleListAction('unordered'),
        'ordered' ||
        'numbered' ||
        'numbering' =>
          const ToggleListAction('ordered'),
        _ => null,
      };
    case 'table':
      return InsertTableAction(
        _integerValue(arguments, 'rows', fallback: 2, min: 1, max: 100),
        _integerValue(arguments, 'cols', fallback: 2, min: 1, max: 100),
      );
    case 'textbox':
    case 'text-box':
      final drawing = _drawingCommandOptions(arguments);
      return InsertTextBoxAction(
        text: drawing.text,
        width: drawing.width,
        height: drawing.height,
        alignment: drawing.alignment,
        fill: drawing.fill,
        outline: drawing.outline,
        outlineWidth: drawing.outlineWidth,
      );
    case 'rectangle':
      return _shapeAction(DrawingShapeKind.rectangle, arguments);
    case 'ellipse':
      return _shapeAction(DrawingShapeKind.ellipse, arguments);
    case 'line':
      return _shapeAction(DrawingShapeKind.line, arguments);
    case 'shape':
    case 'shapes':
      final kindValue = _optionalStringValue(arguments, 'kind') ??
          _optionalStringValue(arguments, 'shape');
      final kind = kindValue == null
          ? null
          : DrawingShapeKind.fromValue(kindValue.toLowerCase());
      return kind == null ? null : _shapeAction(kind, arguments);
    default:
      return null;
  }
}

InsertShapeAction _shapeAction(
  DrawingShapeKind kind,
  _JsonMap arguments,
) {
  final drawing = _drawingCommandOptions(arguments);
  return InsertShapeAction(
    kind,
    text: drawing.text,
    width: drawing.width,
    height: drawing.height,
    alignment: drawing.alignment,
    fill: drawing.fill,
    outline: drawing.outline,
    outlineWidth: drawing.outlineWidth,
  );
}

_DrawingCommandOptions _drawingCommandOptions(_JsonMap values) {
  final width = _optionalFiniteNumberValue(values, 'width');
  final height = _optionalFiniteNumberValue(values, 'height');
  final outlineWidth = _optionalFiniteNumberValue(values, 'outlineWidth');
  if (width != null && !isDrawingDimension(width)) {
    throw ArgumentError.value(width, 'width', 'must be a positive dimension');
  }
  if (height != null && !isDrawingDimension(height)) {
    throw ArgumentError.value(height, 'height', 'must be a positive dimension');
  }
  if (outlineWidth != null && !isDrawingOutlineWidth(outlineWidth)) {
    throw ArgumentError.value(
        outlineWidth, 'outlineWidth', 'must be between 0 and 256');
  }
  final alignmentValue = _optionalStringValue(values, 'alignment');
  final alignment = alignmentValue == null
      ? null
      : DrawingAlignment.fromValue(alignmentValue);
  if (alignmentValue != null && alignment == null) {
    throw ArgumentError.value(alignmentValue, 'alignment',
        'must be inline-start, center or inline-end');
  }
  final fill = _optionalSafeDrawingColor(values, 'fill');
  final outline = _optionalSafeDrawingColor(values, 'outline');
  return (
    text: _stringValue(values, 'text', ''),
    width: width,
    height: height,
    alignment: alignment,
    fill: fill,
    outline: outline,
    outlineWidth: outlineWidth,
  );
}

String? _optionalSafeDrawingColor(_JsonMap values, String key) {
  final value = _optionalStringValue(values, key);
  if (value != null && !isSafeDrawingColor(value)) {
    throw ArgumentError.value(value, key, 'must be a safe CSS color token');
  }
  return value;
}

String _documentText(TaleweaverEditor editor) {
  final state = editor.editorState.state;
  final leaves = iterateLeafBlocksInDocumentOrder(state).toList();
  if (leaves.isEmpty) return '';
  final first = leaves.first;
  final last = leaves.last;
  final lastContent = last.inlineContent!;
  return extractText(
    state,
    Span(
      anchor: Position(blockId: first.id, offset: 0),
      focus: Position(
        blockId: last.id,
        offset: inlineContentLength(lastContent),
      ),
    ),
    builtinEmbedSerializer,
  );
}

_JsonMap _decodeJsonObject(JSObject? value, {required String name}) =>
    value == null
        ? const <String, Object?>{}
        : _mapValue(value.dartify(), name: name);

_JsonMap _mapValue(Object? value, {required String name}) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map) {
    throw ArgumentError.value(value, name, 'must be a JSON object');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw ArgumentError.value(entry.key, name, 'must use string keys');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

Object? _firstValue(
  _JsonMap first,
  String firstKey,
  _JsonMap second,
  String secondKey,
) {
  if (first.containsKey(firstKey)) return first[firstKey];
  if (second.containsKey(secondKey)) return second[secondKey];
  return null;
}

String _stringValue(_JsonMap values, String key, String fallback) {
  final value = _optionalStringValue(values, key);
  return value ?? fallback;
}

String? _optionalStringValue(_JsonMap values, String key) {
  if (!values.containsKey(key) || values[key] == null) return null;
  final value = values[key];
  if (value is String) return value;
  throw ArgumentError.value(value, key, 'must be a string');
}

bool _booleanValue(_JsonMap values, String key, bool fallback) {
  if (!values.containsKey(key) || values[key] == null) return fallback;
  final value = values[key];
  if (value is bool) return value;
  throw ArgumentError.value(value, key, 'must be a boolean');
}

double _finiteNumberValue(_JsonMap values, String key, double fallback) {
  final value = _optionalFiniteNumberValue(values, key);
  return value ?? fallback;
}

double? _optionalFiniteNumberValue(_JsonMap values, String key) {
  if (!values.containsKey(key) || values[key] == null) return null;
  final value = values[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw ArgumentError.value(value, key, 'must be a finite number');
}

int _integerValue(
  _JsonMap values,
  String key, {
  required int fallback,
  required int min,
  required int max,
}) {
  final value = _optionalFiniteNumberValue(values, key);
  if (value == null) return fallback;
  if (value != value.truncateToDouble()) {
    throw ArgumentError.value(value, key, 'must be an integer');
  }
  final integer = value.toInt();
  if (integer < min || integer > max) {
    throw ArgumentError.value(value, key, 'must be between $min and $max');
  }
  return integer;
}

String _cssLengthValue(
  Object? value, {
  required String name,
  required String fallback,
}) =>
    _optionalCssLengthValue(value, name: name) ?? fallback;

String? _optionalCssLengthValue(Object? value, {required String name}) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  } else if (value is num && value.isFinite && value >= 0) {
    return '${value.toString()}px';
  }
  throw ArgumentError.value(
      value, name, 'must be a CSS length string or pixel number');
}

double _positivePageNumber(
  Object? value, {
  required String name,
  required double fallback,
}) {
  final result = _pageNumber(value, name: name, fallback: fallback);
  if (result <= 0) {
    throw ArgumentError.value(value, name, 'must be greater than zero');
  }
  return result;
}

double _nonNegativePageNumber(
  Object? value, {
  required String name,
  required double fallback,
}) {
  final result = _pageNumber(value, name: name, fallback: fallback);
  if (result < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
  return result;
}

double _pageNumber(
  Object? value, {
  required String name,
  required double fallback,
}) {
  if (value == null) return fallback;
  if (value is num && value.isFinite) return value.toDouble();
  throw ArgumentError.value(value, name, 'must be a finite number in points');
}

String? _assetUrl(
  _JsonMap assets,
  _JsonMap options,
  String key,
  String? fallback,
) {
  final hasValue = assets.containsKey(key) || options.containsKey(key);
  if (!hasValue) return fallback;
  final value = assets.containsKey(key) ? assets[key] : options[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ArgumentError.value(value, key, 'must be a string or null');
}

String _assetFontFamily(_JsonMap assets, _JsonMap options) {
  const key = 'iconFontFamily';
  final hasValue = assets.containsKey(key) || options.containsKey(key);
  if (!hasValue) return TaleweaverEditorAssets.defaultIconFontFamily;
  final value = assets.containsKey(key) ? assets[key] : options[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw ArgumentError.value(value, key, 'must be a non-empty string');
}

TaleweaverEditorMode? _editorModeFromString(String value) =>
    switch (value.trim().toLowerCase()) {
      'editor' => TaleweaverEditorMode.editor,
      'viewer' => TaleweaverEditorMode.viewer,
      _ => null,
    };

TaleweaverEditorAppearance? _appearanceFromString(String value) =>
    switch (value.trim().toLowerCase()) {
      'word' => TaleweaverEditorAppearance.word,
      'compact' => TaleweaverEditorAppearance.compact,
      _ => null,
    };

TaleweaverDocumentView? _documentViewFromString(String value) =>
    switch (value.trim().toLowerCase()) {
      'paginated' => TaleweaverDocumentView.paginated,
      'continuous' => TaleweaverDocumentView.continuous,
      _ => null,
    };
