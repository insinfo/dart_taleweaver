/// Strict, pure-Dart Quill document-Delta interchange.
///
/// This codec intentionally covers the portable text subset only:
/// paragraphs, headings, alignment, ordered/bullet lists and the usual inline
/// marks. Tables, embeds, templates, tracked changes and operational Delta
/// entries (`retain` / `delete`) are rejected instead of being silently lost.
///
/// A Quill document Delta is an array of operations, for example:
///
/// ```dart
/// final codec = QuillDeltaCodec();
/// final state = codec.decode([
///   {'insert': 'Title'},
///   {'insert': '\n', 'attributes': {'header': 1}},
///   {'insert': 'First item'},
///   {'insert': '\n', 'attributes': {'list': 'bullet'}},
/// ]);
/// final delta = codec.encode(state);
/// ```
///
/// [decodeQuillDelta] additionally accepts a JSON-decoded wrapper in the form
/// `{ "ops": [...] }`, which is convenient at an Open command boundary.
library;

import '../attrs.dart';
import '../block.dart';
import '../block_id.dart';
import '../build_document_from_tree.dart';
import '../inline_content.dart';
import '../list_defs.dart';
import '../state.dart';
import 'document_serializer.dart';

/// Stable format identifier for the Quill document-Delta subset.
const String quillDeltaFormat = 'quill-delta';

/// JSON-ready Quill Delta operation list.
typedef QuillDelta = List<Map<String, dynamic>>;

/// A valid Delta feature that this deliberately small document codec cannot
/// preserve.
///
/// It also extends [MalformedDocumentError], so callers that treat every
/// rejected import as malformed remain compatible while callers that need a
/// helpful message can catch this narrower type.
class UnsupportedQuillDeltaError extends MalformedDocumentError {
  final String reason;

  UnsupportedQuillDeltaError(this.reason) : super(quillDeltaFormat);

  @override
  String toString() => 'UnsupportedQuillDeltaError: $reason';
}

/// A reusable, dependency-free Quill document-Delta codec.
///
/// The optional [allocator] is used only by [decode]. Supplying a deterministic
/// allocator is useful in tests; normal application code can use the default.
class QuillDeltaCodec implements DocumentSerializer<QuillDelta> {
  final IdAllocator allocator;

  QuillDeltaCodec({IdAllocator? allocator})
      : allocator = allocator ?? productionAllocator;

  @override
  String get format => quillDeltaFormat;

  @override
  QuillDelta encode(State state) => encodeQuillDelta(state);

  @override
  State decode(QuillDelta source) =>
      decodeQuillDelta(source, allocator: allocator);
}

/// Construct a [QuillDeltaCodec] for direct Open/Export integration.
QuillDeltaCodec createQuillDeltaCodec({IdAllocator? allocator}) =>
    QuillDeltaCodec(allocator: allocator);

/// Construct the same codec through the generic serializer interface.
DocumentSerializer<QuillDelta> createQuillDeltaDocumentSerializer({
  IdAllocator? allocator,
}) =>
    createQuillDeltaCodec(allocator: allocator);

/// Encode the strictly representable body of [state] as a Quill document Delta.
///
/// The state must contain only direct paragraph, heading or list-item children
/// of its `document` root. Anything richer is rejected rather than dropped.
QuillDelta encodeQuillDelta(State state) {
  if (state.doc.embedContents.isNotEmpty ||
      state.doc.templateContents.isNotEmpty) {
    throw UnsupportedQuillDeltaError(
      'Quill Delta cannot preserve embedded or template document trees.',
    );
  }
  if (state.doc.comments.isNotEmpty || state.doc.suggestions.isNotEmpty) {
    throw UnsupportedQuillDeltaError(
      'Quill Delta cannot preserve comments or tracked suggestions.',
    );
  }

  final root = getBlock(state, state.rootId);
  if (root == null || root.type != 'document' || root.inlineContent != null) {
    throw UnsupportedQuillDeltaError(
      'Quill Delta requires a document root containing text blocks.',
    );
  }
  if (root.attrs.isNotEmpty) {
    throw UnsupportedQuillDeltaError(
      'Document-level attributes are not representable in Quill Delta.',
    );
  }

  // An empty internal root has the same document meaning as Quill's required
  // terminal newline.
  if (root.firstChildId == null) {
    if (root.lastChildId != null || state.doc.blocks.length != 1) {
      throw UnsupportedQuillDeltaError(
        'The document tree is not a single flat Quill-compatible body.',
      );
    }
    return [
      <String, dynamic>{'insert': '\n'}
    ];
  }
  if (root.lastChildId == null) {
    throw UnsupportedQuillDeltaError('The document root has incomplete links.');
  }

  final result = <Map<String, dynamic>>[];
  final listDefs = getListDefsForState(state);
  BlockId? id = root.firstChildId;
  BlockId? previous;
  var visited = 0;

  while (id != null) {
    if (++visited > state.doc.blocks.length) {
      throw UnsupportedQuillDeltaError(
          'The document block links contain a cycle.');
    }
    final block = getBlock(state, id);
    if (block == null ||
        block.parentId != root.id ||
        block.prevSiblingId != previous ||
        block.firstChildId != null ||
        block.lastChildId != null) {
      throw UnsupportedQuillDeltaError(
        'The document is not a flat paragraph/heading/list body.',
      );
    }
    if (!_supportedBlockTypes.contains(block.type) ||
        block.inlineContent == null) {
      throw UnsupportedQuillDeltaError(
        'Block type "${block.type}" is not representable in Quill Delta.',
      );
    }

    for (final item in block.inlineContent!.items) {
      if (item is! TextItem) {
        throw UnsupportedQuillDeltaError(
          'Inline embeds are not representable in this Quill Delta codec.',
        );
      }
      if (item.text.contains('\n') || item.text.contains('\r')) {
        throw UnsupportedQuillDeltaError(
          'A Taleweaver text run must not contain a structural newline.',
        );
      }
      if (item.text.isEmpty) continue;
      _appendTextOperation(result, item.text, _encodeInlineAttrs(item.attrs));
    }

    final lineAttrs = _encodeLineAttrs(block, listDefs);
    result.add(<String, dynamic>{
      'insert': '\n',
      if (lineAttrs.isNotEmpty) 'attributes': lineAttrs,
    });

    previous = block.id;
    id = block.nextSiblingId;
  }

  if (previous != root.lastChildId || state.doc.blocks.length != visited + 1) {
    throw UnsupportedQuillDeltaError(
      'The document contains blocks outside the Quill-compatible body.',
    );
  }
  return result;
}

/// Decode a JSON-decoded Quill document Delta into a fresh Taleweaver [State].
///
/// [source] may be the usual operation array or an object containing an `ops`
/// array. A final newline is preferred by Quill but an unterminated final text
/// run is accepted and closed as a paragraph for import resilience.
State decodeQuillDelta(
  Object? source, {
  IdAllocator? allocator,
}) {
  final rawOps = _readOps(source);
  final blocks = <BlockNode>[];
  final lists = _DecodedLists();
  var currentItems = <InlineItem>[];

  void finishLine(_QuillLineAttrs line) {
    final attrs = <String, dynamic>{};
    if (line.align != null) attrs['textAlign'] = line.align;

    String type = 'paragraph';
    if (line.header != null) {
      type = 'heading';
      attrs['level'] = line.header;
      lists.breakList();
    } else if (line.list != null) {
      type = 'list-item';
      attrs['listId'] = lists.assign(line.list!, line.indent);
      if (line.indent > 0) attrs['listLevel'] = line.indent;
    } else {
      lists.breakList();
    }

    blocks.add(LeafBlockNode(
      type: type,
      attrs: attrs,
      inlineContent: InlineContent(mergeAdjacentTextItems(currentItems)),
    ));
    currentItems = <InlineItem>[];
  }

  for (var index = 0; index < rawOps.length; index++) {
    final op = _readOperation(rawOps[index], index);
    final insert = op['insert'];
    if (insert is! String) {
      if (insert == null) throw MalformedDocumentError(quillDeltaFormat);
      throw UnsupportedQuillDeltaError(
        'Operation $index contains an embed; only text inserts are supported.',
      );
    }
    final parsed = _decodeAttributes(op['attributes'], index);

    if (insert.contains('\r')) {
      throw MalformedDocumentError(quillDeltaFormat);
    }
    if (insert.isEmpty) {
      if (!parsed.isEmpty) {
        throw UnsupportedQuillDeltaError(
          'Operation $index applies attributes to an empty insert.',
        );
      }
      continue;
    }

    final hasNewline = insert.contains('\n');
    if (parsed.hasLineAttrs && !hasNewline) {
      throw UnsupportedQuillDeltaError(
        'Operation $index applies a line format without a newline.',
      );
    }
    if (parsed.hasLineAttrs && !insert.endsWith('\n')) {
      throw UnsupportedQuillDeltaError(
        'Operation $index mixes a line format with an unterminated text line.',
      );
    }
    if (parsed.inlineAttrs.isNotEmpty && insert.replaceAll('\n', '').isEmpty) {
      throw UnsupportedQuillDeltaError(
        'Operation $index applies inline formatting to a newline only.',
      );
    }

    final pieces = insert.split('\n');
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.isNotEmpty) {
        currentItems.add(TextItem(
          text: piece,
          attrs: Map<String, dynamic>.of(parsed.inlineAttrs),
        ));
      }
      if (i < pieces.length - 1) finishLine(parsed.lineAttrs);
    }
  }

  if (currentItems.isNotEmpty || blocks.isEmpty)
    finishLine(const _QuillLineAttrs());

  return buildDocumentFromTree(
    ContainerBlockNode(type: 'document', children: blocks),
    lists.toListDefs(),
    allocator ?? productionAllocator,
  );
}

const Set<String> _supportedBlockTypes = {'paragraph', 'heading', 'list-item'};
const Set<String> _supportedInlineAttrs = {
  'bold',
  'italic',
  'underline',
  'strikethrough',
  'link',
  'color',
  'highlight',
  'backgroundColor',
  'fontSize',
  'fontFamily',
};
const Set<String> _bulletStyles = {'disc', 'circle', 'square'};
const Set<String> _orderedStyles = {
  'decimal',
  'lower-alpha',
  'upper-alpha',
  'lower-roman',
  'upper-roman',
};

void _appendTextOperation(
  QuillDelta out,
  String text,
  Map<String, dynamic> attrs,
) {
  if (out.isNotEmpty) {
    final previous = out.last;
    final previousText = previous['insert'];
    final previousAttrs = previous['attributes'];
    final sameAttrs = previousAttrs == null
        ? attrs.isEmpty
        : previousAttrs is Map &&
            attrsEqual(Map<String, dynamic>.from(previousAttrs), attrs);
    if (previousText is String && previousText != '\n' && sameAttrs) {
      previous['insert'] = previousText + text;
      return;
    }
  }
  out.add(<String, dynamic>{
    'insert': text,
    if (attrs.isNotEmpty) 'attributes': attrs,
  });
}

Map<String, dynamic> _encodeInlineAttrs(ReadonlyAttrs attrs) {
  for (final key in attrs.keys) {
    if (!_supportedInlineAttrs.contains(key)) {
      throw UnsupportedQuillDeltaError(
        'Inline attribute "$key" is not representable in Quill Delta.',
      );
    }
  }

  final out = <String, dynamic>{};
  void boolean(String stateKey, String quillKey) {
    if (!attrs.containsKey(stateKey)) return;
    if (attrs[stateKey] != true) {
      throw UnsupportedQuillDeltaError(
        'Inline attribute "$stateKey" must be true when present.',
      );
    }
    out[quillKey] = true;
  }

  boolean('bold', 'bold');
  boolean('italic', 'italic');
  boolean('underline', 'underline');
  boolean('strikethrough', 'strike');

  void text(String stateKey, String quillKey) {
    if (!attrs.containsKey(stateKey)) return;
    final value = attrs[stateKey];
    if (value is! String || value.isEmpty) {
      throw UnsupportedQuillDeltaError(
        'Inline attribute "$stateKey" must be a non-empty string.',
      );
    }
    out[quillKey] = value;
  }

  text('link', 'link');
  text('color', 'color');
  text('fontFamily', 'font');

  final hasHighlight = attrs.containsKey('highlight');
  final hasBackground = attrs.containsKey('backgroundColor');
  if (hasHighlight || hasBackground) {
    final highlight = attrs['highlight'];
    final background = attrs['backgroundColor'];
    if (hasHighlight && (highlight is! String || highlight.isEmpty)) {
      throw UnsupportedQuillDeltaError(
          'Inline attribute "highlight" is invalid.');
    }
    if (hasBackground && (background is! String || background.isEmpty)) {
      throw UnsupportedQuillDeltaError(
        'Inline attribute "backgroundColor" is invalid.',
      );
    }
    if (hasHighlight && hasBackground && highlight != background) {
      throw UnsupportedQuillDeltaError(
        'Quill Delta has one background attribute; Taleweaver has two different values.',
      );
    }
    out['background'] = hasHighlight ? highlight : background;
  }

  if (attrs.containsKey('fontSize')) {
    out['size'] = _encodeFontSize(attrs['fontSize']);
  }
  return out;
}

dynamic _encodeFontSize(dynamic value) {
  if (value is num && value.isFinite && value > 0) return value;
  if (value is Map) {
    final unit = value['unit'];
    final amount = value['value'];
    if (unit == 'px' && amount is num && amount.isFinite && amount > 0) {
      return amount;
    }
    if (unit == 'em' && amount is num) {
      if (amount == 0.75) return 'small';
      if (amount == 1.5) return 'large';
      if (amount == 2.5) return 'huge';
    }
  }
  throw UnsupportedQuillDeltaError(
    'Font sizes must be positive pixels or Quill small/large/huge equivalents.',
  );
}

Map<String, dynamic> _encodeLineAttrs(
  Block block,
  Map<String, ListDef> listDefs,
) {
  final allowed = switch (block.type) {
    'paragraph' => const {'textAlign'},
    'heading' => const {'level', 'textAlign'},
    'list-item' => const {'listId', 'listLevel', 'textAlign'},
    _ => const <String>{},
  };
  for (final key in block.attrs.keys) {
    if (!allowed.contains(key)) {
      throw UnsupportedQuillDeltaError(
        'Block attribute "$key" on ${block.type} is not representable in Quill Delta.',
      );
    }
  }

  final out = <String, dynamic>{};
  final align = _encodeAlign(block.attrs['textAlign']);
  if (align != null) out['align'] = align;

  if (block.type == 'heading') {
    final level = _readLevel(block.attrs['level'], 'heading level');
    out['header'] = level;
  } else if (block.type == 'list-item') {
    final level = block.attrs.containsKey('listLevel')
        ? _readIndent(block.attrs['listLevel'])
        : 0;
    final rawId = block.attrs['listId'];
    if (rawId != null && (rawId is! String || rawId.isEmpty)) {
      throw UnsupportedQuillDeltaError('A listId must be a non-empty string.');
    }
    final listId = rawId as String?;
    var listType = 'bullet';
    final definition = listId == null ? null : listDefs[listId];
    if (definition != null && definition.levels.isNotEmpty) {
      if (level >= definition.levels.length) {
        throw UnsupportedQuillDeltaError(
          'List level $level has no matching list definition.',
        );
      }
      final style = definition.levels[level].style;
      if (_bulletStyles.contains(style)) {
        listType = 'bullet';
      } else if (_orderedStyles.contains(style)) {
        listType = 'ordered';
      } else {
        throw UnsupportedQuillDeltaError(
          'List marker style "$style" is not representable in Quill Delta.',
        );
      }
    }
    out['list'] = listType;
    if (level > 0) out['indent'] = level;
  }
  return out;
}

String? _encodeAlign(dynamic value) {
  if (value == null) return null;
  switch (value) {
    case 'start':
    case 'left':
      return null;
    case 'end':
    case 'right':
      return 'right';
    case 'center':
    case 'justify':
      return value as String;
    default:
      throw UnsupportedQuillDeltaError(
        'Text alignment "$value" is not representable in Quill Delta.',
      );
  }
}

List<dynamic> _readOps(Object? source) {
  Object? candidate = source;
  if (source is Map) {
    final wrapper = _stringMap(source);
    if (wrapper.length != 1 || !wrapper.containsKey('ops')) {
      throw MalformedDocumentError(quillDeltaFormat);
    }
    candidate = wrapper['ops'];
  }
  if (candidate is! List) throw MalformedDocumentError(quillDeltaFormat);
  return candidate;
}

Map<String, dynamic> _readOperation(dynamic raw, int index) {
  final op = _stringMap(raw);
  if (!op.containsKey('insert')) {
    if (op.containsKey('retain') || op.containsKey('delete')) {
      throw UnsupportedQuillDeltaError(
        'Operation $index is a change Delta; only document inserts are supported.',
      );
    }
    throw MalformedDocumentError(quillDeltaFormat);
  }
  for (final key in op.keys) {
    if (key != 'insert' && key != 'attributes') {
      throw UnsupportedQuillDeltaError(
        'Operation $index has unsupported field "$key".',
      );
    }
  }
  return op;
}

Map<String, dynamic> _stringMap(dynamic raw) {
  if (raw is! Map) throw MalformedDocumentError(quillDeltaFormat);
  final out = <String, dynamic>{};
  for (final entry in raw.entries) {
    if (entry.key is! String) throw MalformedDocumentError(quillDeltaFormat);
    out[entry.key as String] = entry.value;
  }
  return out;
}

class _ParsedAttributes {
  final Map<String, dynamic> inlineAttrs;
  final _QuillLineAttrs lineAttrs;

  const _ParsedAttributes(this.inlineAttrs, this.lineAttrs);

  bool get hasLineAttrs => !lineAttrs.isEmpty;
  bool get isEmpty => inlineAttrs.isEmpty && lineAttrs.isEmpty;
}

class _QuillLineAttrs {
  final int? header;
  final String? align;
  final String? list;
  final int indent;

  const _QuillLineAttrs({
    this.header,
    this.align,
    this.list,
    this.indent = 0,
  });

  bool get isEmpty =>
      header == null && align == null && list == null && indent == 0;
}

_ParsedAttributes _decodeAttributes(dynamic raw, int opIndex) {
  if (raw == null) return const _ParsedAttributes({}, _QuillLineAttrs());
  final attrs = _stringMap(raw);
  final inline = <String, dynamic>{};
  int? header;
  String? align;
  String? list;
  int? indent;

  for (final entry in attrs.entries) {
    final key = entry.key;
    final value = entry.value;
    switch (key) {
      case 'bold':
      case 'italic':
      case 'underline':
        if (value != true) _unsupportedAttr(opIndex, key);
        inline[key] = true;
        break;
      case 'strike':
        if (value != true) _unsupportedAttr(opIndex, key);
        inline['strikethrough'] = true;
        break;
      case 'link':
      case 'color':
        if (value is! String || value.isEmpty) _unsupportedAttr(opIndex, key);
        inline[key] = value;
        break;
      case 'background':
        if (value is! String || value.isEmpty) _unsupportedAttr(opIndex, key);
        inline['highlight'] = value;
        break;
      case 'font':
        if (value is! String || value.isEmpty) _unsupportedAttr(opIndex, key);
        inline['fontFamily'] = value;
        break;
      case 'size':
        inline['fontSize'] = _decodeFontSize(value, opIndex);
        break;
      case 'header':
        header = _readLevel(value, 'header in operation $opIndex');
        break;
      case 'align':
        align = _decodeAlign(value, opIndex);
        break;
      case 'list':
        if (value != 'ordered' && value != 'bullet')
          _unsupportedAttr(opIndex, key);
        list = value as String;
        break;
      case 'indent':
        indent = _readIndent(value);
        break;
      default:
        _unsupportedAttr(opIndex, key);
    }
  }

  if (header != null && list != null) {
    throw UnsupportedQuillDeltaError(
      'Operation $opIndex combines mutually exclusive header and list formats.',
    );
  }
  if (indent != null && list == null) _unsupportedAttr(opIndex, 'indent');

  return _ParsedAttributes(
    inline,
    _QuillLineAttrs(
      header: header,
      align: align,
      list: list,
      indent: indent ?? 0,
    ),
  );
}

Never _unsupportedAttr(int opIndex, String attr) =>
    throw UnsupportedQuillDeltaError(
      'Operation $opIndex uses unsupported or invalid attribute "$attr".',
    );

dynamic _decodeFontSize(dynamic value, int opIndex) {
  if (value is num && value.isFinite && value > 0) return value;
  switch (value) {
    case 'small':
      return const {'unit': 'em', 'value': 0.75};
    case 'large':
      return const {'unit': 'em', 'value': 1.5};
    case 'huge':
      return const {'unit': 'em', 'value': 2.5};
    default:
      throw UnsupportedQuillDeltaError(
        'Operation $opIndex uses unsupported font size "$value".',
      );
  }
}

int _readLevel(dynamic value, String label) {
  if (value is! num || !value.isFinite) {
    throw UnsupportedQuillDeltaError('$label must be an integer from 1 to 6.');
  }
  final level = value.toInt();
  if (value.toDouble() != level.toDouble() || level < 1 || level > 6) {
    throw UnsupportedQuillDeltaError('$label must be an integer from 1 to 6.');
  }
  return level;
}

int _readIndent(dynamic value) {
  if (value is! num || !value.isFinite) {
    throw UnsupportedQuillDeltaError(
        'List indent must be an integer from 0 to 8.');
  }
  final indent = value.toInt();
  if (value.toDouble() != indent.toDouble() || indent < 0 || indent > 8) {
    throw UnsupportedQuillDeltaError(
        'List indent must be an integer from 0 to 8.');
  }
  return indent;
}

String _decodeAlign(dynamic value, int opIndex) {
  switch (value) {
    case 'left':
      return 'left';
    case 'right':
      return 'right';
    case 'center':
      return 'center';
    case 'justify':
      return 'justify';
    default:
      throw UnsupportedQuillDeltaError(
        'Operation $opIndex uses unsupported alignment "$value".',
      );
  }
}

class _DecodedLists {
  int _nextId = 0;
  String? _activeId;
  final Map<String, List<String>> _styles = {};

  String assign(String type, int level) {
    var id = _activeId;
    if (id == null || _hasConflictingStyle(id, type, level)) {
      id = 'quill-list-${_nextId++}';
      _activeId = id;
      _styles[id] = List<String>.filled(level + 1, type);
      return id;
    }

    final levels = _styles[id]!;
    while (levels.length <= level) {
      levels.add(type);
    }
    return id;
  }

  bool _hasConflictingStyle(String id, String type, int level) {
    final levels = _styles[id]!;
    return level < levels.length && levels[level] != type;
  }

  void breakList() => _activeId = null;

  Map<String, ListDef> toListDefs() {
    return {
      for (final entry in _styles.entries)
        entry.key: ListDef(
          levels: entry.value
              .map(
                (type) => ListLevelConfig(
                  style: type == 'ordered' ? 'decimal' : 'disc',
                  start: 1,
                  restart: 'after-break',
                ),
              )
              .toList(growable: false),
        ),
    };
  }
}
