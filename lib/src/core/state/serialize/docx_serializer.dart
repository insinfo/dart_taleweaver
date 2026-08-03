/// DOCX (Office Open XML) interchange for the editor's supported model.
///
/// This is intentionally a strict, dependency-light OOXML adapter. It keeps
/// the document body, common run formatting, headings, simple lists, tables
/// and section page setup. Unsupported package parts are not silently copied
/// into the model; callers can inspect [DocxImportReport] when they need to
/// warn about comments, drawings or tracked changes that were not imported.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../attrs.dart';
import '../block.dart';
import '../block_id.dart';
import '../build_document_from_tree.dart';
import '../inline_content.dart';
import '../list_defs.dart';
import '../state.dart';
import 'document_serializer.dart';

const String docxFormat = 'docx';

/// The `html` package provides a small, pure-Dart DOM parser that is also
/// suitable for the namespace-qualified XML used by OOXML. Keep this wrapper
/// private so the public serializer API does not expose an HTML dependency.
class _XmlParser {
  final String source;

  _XmlParser(this.source);

  DocumentFragment parse() => html_parser.parseFragment(source);
}

typedef _XmlElement = Element;

/// Non-fatal features found in a DOCX package but outside the model adapter.
class DocxImportReport {
  final Set<String> unsupportedParts;
  final int importedParagraphs;
  final int importedTables;

  const DocxImportReport({
    this.unsupportedParts = const {},
    this.importedParagraphs = 0,
    this.importedTables = 0,
  });

  bool get hasWarnings => unsupportedParts.isNotEmpty;
}

/// Result of importing a DOCX package without discarding diagnostics.
class DocxImportResult {
  final State state;
  final DocxImportReport report;

  const DocxImportResult(this.state, this.report);
}

class UnsupportedDocxError extends MalformedDocumentError {
  final String reason;

  UnsupportedDocxError(this.reason) : super(docxFormat);

  @override
  String toString() => 'UnsupportedDocxError: $reason';
}

/// Stateless DOCX serializer. It is usable in browser and VM builds because
/// ZIP and XML handling are pure Dart packages.
class DocxSerializer implements DocumentSerializer<Uint8List> {
  final IdAllocator allocator;

  DocxSerializer({IdAllocator? allocator})
      : allocator = allocator ?? productionAllocator;

  @override
  String get format => docxFormat;

  @override
  Uint8List encode(State state) => encodeDocx(state);

  @override
  State decode(Uint8List source) => decodeDocx(source);
}

DocxSerializer createDocxSerializer({IdAllocator? allocator}) =>
    DocxSerializer(allocator: allocator ?? productionAllocator);

Uint8List encodeDocx(State state) {
  final root = getBlock(state, state.rootId);
  if (root == null || root.type != 'document') {
    throw UnsupportedDocxError('DOCX requires a document root.');
  }
  final body = StringBuffer();
  var child = root.firstChildId;
  while (child != null) {
    final block = getBlock(state, child);
    if (block == null) throw UnsupportedDocxError('Broken document links.');
    body.write(_encodeBlock(state, block));
    child = block.nextSiblingId;
  }
  if (body.length == 0) body.write('<w:p/>');

  return _ZipWriter({
    '[Content_Types].xml': _contentTypesXml,
    '_rels/.rels': _rootRelsXml,
    'word/_rels/document.xml.rels': _documentRelsXml,
    'word/document.xml': _documentXml(body.toString(), root.attrs),
    'word/styles.xml': _stylesXml,
    'word/numbering.xml': _numberingXml,
  }).encode();
}

DocxImportResult decodeDocxWithReport(Uint8List source,
    {IdAllocator? allocator}) {
  try {
    final package = _ZipReader(source).readAll();
    final document = package['word/document.xml'];
    if (document == null) {
      throw UnsupportedDocxError('word/document.xml is missing.');
    }
    final numbering = package['word/numbering.xml'];
    final parsed = _parseDocx(
      document,
      numbering,
      allocator ?? productionAllocator,
    );
    final unsupported = <String>{};
    for (final name in [
      'word/comments.xml',
      'word/footnotes.xml',
      'word/endnotes.xml',
      'word/people.xml',
      'word/document.xml.rels',
    ]) {
      if (package.containsKey(name) && name != 'word/document.xml.rels') {
        unsupported.add(name);
      }
    }
    return DocxImportResult(
      parsed.state,
      DocxImportReport(
        unsupportedParts: unsupported,
        importedParagraphs: parsed.paragraphs,
        importedTables: parsed.tables,
      ),
    );
  } on UnsupportedDocxError {
    rethrow;
  } catch (_) {
    throw MalformedDocumentError(docxFormat);
  }
}

State decodeDocx(Uint8List source, {IdAllocator? allocator}) =>
    decodeDocxWithReport(source, allocator: allocator).state;

({State state, int paragraphs, int tables}) _parseDocx(
  String documentXml,
  String? numberingXml,
  IdAllocator allocator,
) {
  final document = _XmlParser(documentXml).parse();
  final body = _first(document, 'body');
  if (body == null) throw UnsupportedDocxError('DOCX body is missing.');
  final lists = _parseNumbering(numberingXml);
  final nodes = <BlockNode>[];
  var paragraphs = 0;
  var tables = 0;
  for (final child in body.children) {
    switch (_local(child)) {
      case 'p':
        nodes.add(_paragraph(child, lists));
        paragraphs++;
      case 'tbl':
        nodes.add(_table(child, lists));
        tables++;
    }
  }
  if (nodes.isEmpty) nodes.add(_paragraph(null, lists));
  final rootAttrs = _sectionAttrs(body);
  final state = buildDocumentFromTree(
    ContainerBlockNode(type: 'document', attrs: rootAttrs, children: nodes),
    lists.definitions,
    allocator,
  );
  return (state: state, paragraphs: paragraphs, tables: tables);
}

LeafBlockNode _paragraph(_XmlElement? paragraph, _NumberingState lists) {
  final attrs = <String, dynamic>{};
  final pPr = paragraph == null ? null : _firstChild(paragraph, 'pPr');
  final style = _val(_firstChild(pPr, 'pStyle'));
  final heading = _headingLevel(style);
  if (heading != null) {
    attrs['level'] = heading;
  }
  final align = _val(_firstChild(pPr, 'jc'));
  if (align != null) attrs['textAlign'] = _decodeAlignment(align);
  final numPr = _firstChild(pPr, 'numPr');
  final numId = _val(_firstChild(numPr, 'numId'));
  final level = int.tryParse(_val(_firstChild(numPr, 'ilvl')) ?? '') ?? 0;
  if (numId != null && heading == null) {
    attrs['listId'] = lists.listId(numId, level);
    if (level > 0) attrs['listLevel'] = level;
  }
  final type = heading == null && numId != null
      ? 'list-item'
      : heading == null
          ? 'paragraph'
          : 'heading';
  final items = <InlineItem>[];
  if (paragraph != null) {
    for (final run in _descendants(paragraph, 'r')) {
      final runAttrs = _runAttrs(_firstChild(run, 'rPr'));
      for (final node in run.children) {
        switch (_local(node)) {
          case 't':
            if (node.text.isNotEmpty) {
              items.add(TextItem(text: node.text, attrs: runAttrs));
            }
          case 'tab':
            items.add(TextItem(text: '\t', attrs: runAttrs));
          case 'br' || 'cr':
            items.add(EmbedItem(
              embedType: hardBreakEmbedType,
              attrs: runAttrs,
            ));
        }
      }
    }
  }
  return LeafBlockNode(
    type: type,
    attrs: attrs,
    inlineContent: InlineContent(mergeAdjacentTextItems(items)),
  );
}

ContainerBlockNode _table(_XmlElement table, _NumberingState lists) {
  final rows = <BlockNode>[];
  for (final row in _children(table, 'tr')) {
    final cells = <BlockNode>[];
    for (final cell in _children(row, 'tc')) {
      final paragraphs = <BlockNode>[];
      for (final p in _children(cell, 'p')) {
        paragraphs.add(_paragraph(p, lists));
      }
      if (paragraphs.isEmpty) paragraphs.add(_paragraph(null, lists));
      final tcPr = _firstChild(cell, 'tcPr');
      final attrs = <String, dynamic>{};
      final gridSpan = int.tryParse(_val(_firstChild(tcPr, 'gridSpan')) ?? '');
      if (gridSpan != null && gridSpan > 1) attrs['colSpan'] = gridSpan;
      cells.add(ContainerBlockNode(
          type: 'table-cell', attrs: attrs, children: paragraphs));
    }
    rows.add(ContainerBlockNode(type: 'table-row', children: cells));
  }
  final sourceRows = _children(table, 'tr');
  final columns =
      sourceRows.isEmpty ? 0 : _children(sourceRows.first, 'tc').length;
  return ContainerBlockNode(
    type: 'table',
    attrs: columns == 0
        ? const {}
        : {'columnWidths': List<double>.filled(columns, 1)},
    children: rows,
  );
}

Map<String, dynamic> _sectionAttrs(_XmlElement body) {
  final sectPr = _descendants(body, 'sectPr').firstOrNull;
  if (sectPr == null) return const {};
  final attrs = <String, dynamic>{};
  final size = _firstChild(sectPr, 'pgSz');
  final width = double.tryParse(_attr(size, 'w') ?? '');
  final height = double.tryParse(_attr(size, 'h') ?? '');
  if (width != null && width > 0) attrs['pageInlineSize'] = width / 20;
  if (height != null && height > 0) attrs['pageBlockSize'] = height / 20;
  final margin = _firstChild(sectPr, 'pgMar');
  double? twips(String name) => double.tryParse(_attr(margin, name) ?? '');
  final top = twips('top'),
      right = twips('right'),
      bottom = twips('bottom'),
      left = twips('left');
  if ([top, right, bottom, left]
      .every((value) => value != null && value >= 0)) {
    attrs['pageMargins'] = {
      'blockStart': top! / 20,
      'inlineEnd': right! / 20,
      'blockEnd': bottom! / 20,
      'inlineStart': left! / 20,
    };
  }
  return attrs;
}

Map<String, dynamic> _runAttrs(_XmlElement? rPr) {
  final attrs = <String, dynamic>{};
  bool present(String name) => _firstChild(rPr, name) != null;
  if (present('b')) attrs['bold'] = true;
  if (present('i')) attrs['italic'] = true;
  if (present('strike')) attrs['strikethrough'] = true;
  if (present('u')) attrs['underline'] = true;
  final color = _attr(_firstChild(rPr, 'color'), 'val');
  if (color != null && color != 'auto') attrs['color'] = '#$color';
  final highlight = _attr(_firstChild(rPr, 'highlight'), 'val');
  if (highlight != null) attrs['highlight'] = _wordColor(highlight);
  final size = double.tryParse(_attr(_firstChild(rPr, 'sz'), 'val') ?? '');
  if (size != null && size > 0) attrs['fontSize'] = size / 2;
  final fonts = _firstChild(rPr, 'rFonts');
  final font = _attr(fonts, 'ascii') ?? _attr(fonts, 'hAnsi');
  if (font != null && font.isNotEmpty) attrs['fontFamily'] = font;
  return attrs;
}

class _NumberingState {
  final Map<String, String> formats;
  final Map<String, ListDef> definitions = {};
  final Map<String, String> ids = {};
  int next = 0;

  _NumberingState(this.formats);

  String listId(String numId, int level) {
    final id = ids[numId] ??= 'docx-list-${next++}';
    final format = formats[numId] ?? 'bullet';
    final existing = definitions[id];
    if (existing == null) {
      definitions[id] = ListDef(levels: [
        ListLevelConfig(style: format, start: 1, restart: 'after-break')
      ]);
    } else {
      if (existing.levels.length <= level) {
        definitions[id] = ListDef(levels: [
          ...existing.levels,
          ...List<ListLevelConfig>.generate(
            level + 1 - existing.levels.length,
            (_) => ListLevelConfig(
              style: format,
              start: 1,
              restart: 'after-break',
            ),
          ),
        ]);
      }
    }
    return id;
  }
}

_NumberingState _parseNumbering(String? xml) {
  final formats = <String, String>{};
  if (xml != null) {
    final root = _XmlParser(xml).parse();
    for (final num in _descendants(root, 'num')) {
      final id = _attr(num, 'numId');
      final abstractId = _val(_firstChild(num, 'abstractNumId'));
      if (id == null || abstractId == null) continue;
      final abstract = _descendants(root, 'abstractNum')
          .where((node) => _attr(node, 'abstractNumId') == abstractId)
          .firstOrNull;
      final fmt = abstract == null
          ? null
          : _val(_descendants(abstract, 'numFmt').firstOrNull);
      formats[id] =
          fmt == 'decimal' || fmt == 'lowerLetter' || fmt == 'upperLetter'
              ? 'decimal'
              : 'disc';
    }
  }
  return _NumberingState(formats);
}

String _encodeBlock(State state, Block block) {
  if (block.type == 'table') {
    final out = StringBuffer('<w:tbl><w:tblGrid>');
    final widths = block.attrs['columnWidths'];
    if (widths is List) {
      for (final _ in widths) out.write('<w:gridCol w:w="2400"/>');
    }
    out.write('</w:tblGrid>');
    for (final child in _childrenOf(state, block))
      out.write(_encodeBlock(state, child));
    return '${out.toString()}</w:tbl>';
  }
  if (block.type == 'table-row') {
    return '<w:tr>${_childrenOf(state, block).map((child) => _encodeBlock(state, child)).join()}</w:tr>';
  }
  if (block.type == 'table-cell') {
    final span = block.attrs['colSpan'];
    return '<w:tc>${span is num && span > 1 ? '<w:tcPr><w:gridSpan w:val="${span.toInt()}"/></w:tcPr>' : ''}${_childrenOf(state, block).map((child) => _encodeBlock(state, child)).join()}</w:tc>';
  }
  final pPr = StringBuffer();
  if (block.type == 'heading')
    pPr.write('<w:pStyle w:val="Heading${block.attrs['level'] ?? 1}"/>');
  final align = block.attrs['textAlign'];
  if (align != null) pPr.write('<w:jc w:val="${_encodeAlignment(align)}"/>');
  if (block.type == 'list-item') {
    pPr.write(
        '<w:numPr><w:ilvl w:val="${block.attrs['listLevel'] ?? 0}"/><w:numId w:val="1"/></w:numPr>');
  }
  final content = StringBuffer();
  for (final item in block.inlineContent?.items ?? const <InlineItem>[]) {
    if (item is EmbedItem && item.embedType == hardBreakEmbedType) {
      content.write('<w:r>${_encodeRunProperties(item.attrs)}<w:br/></w:r>');
      continue;
    }
    if (item is! TextItem) {
      throw UnsupportedDocxError(
          'This DOCX exporter cannot preserve inline embeds.');
    }
    content.write(
        '<w:r>${_encodeRunProperties(item.attrs)}<w:t xml:space="preserve">${_xml(item.text)}</w:t></w:r>');
  }
  return '<w:p>${pPr.isEmpty ? '' : '<w:pPr>${pPr.toString()}</w:pPr>'}$content</w:p>';
}

String _encodeRunProperties(ReadonlyAttrs attrs) {
  final out = StringBuffer('<w:rPr>');
  if (attrs['bold'] == true) out.write('<w:b/>');
  if (attrs['italic'] == true) out.write('<w:i/>');
  if (attrs['underline'] == true) out.write('<w:u w:val="single"/>');
  if (attrs['strikethrough'] == true) out.write('<w:strike/>');
  final color = attrs['color'];
  if (color is String)
    out.write('<w:color w:val="${color.replaceFirst('#', '')}"/>');
  final size = attrs['fontSize'];
  if (size is num && size > 0)
    out.write('<w:sz w:val="${(size * 2).round()}"/>');
  final family = attrs['fontFamily'];
  if (family is String && family.isNotEmpty)
    out.write(
        '<w:rFonts w:ascii="${_xml(family)}" w:hAnsi="${_xml(family)}"/>');
  out.write('</w:rPr>');
  return out.toString();
}

List<Block> _childrenOf(State state, Block parent) {
  final result = <Block>[];
  var id = parent.firstChildId;
  while (id != null) {
    final child = getBlock(state, id);
    if (child == null) throw UnsupportedDocxError('Broken container links.');
    result.add(child);
    id = child.nextSiblingId;
  }
  return result;
}

String _documentXml(String body, ReadonlyAttrs attrs) =>
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="${_twips(attrs['pageInlineSize'], 11906)}" w:h="${_twips(attrs['pageBlockSize'], 16838)}"/><w:pgMar w:top="${_twips(_margin(attrs, 'blockStart'), 1440)}" w:right="${_twips(_margin(attrs, 'inlineEnd'), 1440)}" w:bottom="${_twips(_margin(attrs, 'blockEnd'), 1440)}" w:left="${_twips(_margin(attrs, 'inlineStart'), 1440)}"/></w:sectPr></w:body></w:document>''';

double _margin(ReadonlyAttrs attrs, String key) =>
    (attrs['pageMargins'] is Map ? (attrs['pageMargins'] as Map)[key] : null)
            is num
        ? ((attrs['pageMargins'] as Map)[key] as num).toDouble()
        : 72;
int _twips(dynamic value, int fallback) =>
    value is num && value > 0 ? (value.toDouble() * 20).round() : fallback;
String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _local(Element element) => element.localName.toString().split(':').last;
String? _attr(Element? element, String name) => element?.attributes.entries
    .where((entry) =>
        entry.key.toString().split(':').last.toLowerCase() ==
        name.toLowerCase())
    .map((entry) => entry.value.toString())
    .firstOrNull;
String? _val(Element? element) => _attr(element, 'val');
Element? _first(Node node, String name) => node is Element
    ? (_local(node).toLowerCase() == name.toLowerCase()
        ? node
        : _descendants(node, name).firstOrNull)
    : node.nodes
        .whereType<Element>()
        .map((child) {
          if (_local(child) == name) return child;
          return _descendants(child, name).firstOrNull;
        })
        .whereType<Element>()
        .firstOrNull;
Element? _firstChild(Node? node, String name) => node is Element
    ? (node.children
            .where((child) => _local(child).toLowerCase() == name.toLowerCase())
            .firstOrNull ??
        _descendants(node, name).firstOrNull)
    : null;
List<Element> _children(Node node, String name) => node is Element
    ? node.children
        .where((child) => _local(child).toLowerCase() == name.toLowerCase())
        .toList()
    : const [];
List<Element> _descendants(Node node, String name) {
  final result = <Element>[];
  void visit(Node current) {
    for (final child in current.nodes) {
      if (child is Element) {
        if (_local(child).toLowerCase() == name.toLowerCase())
          result.add(child);
        visit(child);
      }
    }
  }

  visit(node);
  return result;
}

int? _headingLevel(String? style) => style == null
    ? null
    : int.tryParse(
        style.replaceFirst(RegExp('^Heading', caseSensitive: false), ''));
String _decodeAlignment(String value) => value == 'both'
    ? 'justify'
    : value == 'right'
        ? 'right'
        : value == 'center'
            ? 'center'
            : 'left';
String _encodeAlignment(dynamic value) => value == 'justify'
    ? 'both'
    : value?.toString() == 'right'
        ? 'right'
        : value?.toString() == 'center'
            ? 'center'
            : 'left';
String _wordColor(String value) =>
    const {
      'yellow': '#ffff00',
      'green': '#00ff00',
      'cyan': '#00ffff',
      'magenta': '#ff00ff',
      'blue': '#0000ff',
      'red': '#ff0000'
    }[value] ??
    value;

// DOCX is a ZIP package. This deliberately small implementation keeps the
// serializer usable with only the package's two runtime dependencies.
class _ZipWriter {
  final Map<String, String> files;
  _ZipWriter(this.files);

  Uint8List encode() {
    final output = <int>[];
    final directory = <int>[];
    for (final entry in files.entries) {
      final name = utf8.encode(entry.key);
      final data = utf8.encode(entry.value);
      final offset = output.length;
      _zip32(output, 0x04034b50);
      _zip16(output, 20);
      _zip16(output, 0x800);
      _zip16(output, 0);
      _zip16(output, 0);
      _zip16(output, 0);
      _zip32(output, _crc32(data));
      _zip32(output, data.length);
      _zip32(output, data.length);
      _zip16(output, name.length);
      _zip16(output, 0);
      output
        ..addAll(name)
        ..addAll(data);
      _zip32(directory, 0x02014b50);
      _zip16(directory, 20);
      _zip16(directory, 20);
      _zip16(directory, 0x800);
      _zip16(directory, 0);
      _zip16(directory, 0);
      _zip16(directory, 0);
      _zip32(directory, _crc32(data));
      _zip32(directory, data.length);
      _zip32(directory, data.length);
      _zip16(directory, name.length);
      _zip16(directory, 0);
      _zip16(directory, 0);
      _zip16(directory, 0);
      _zip16(directory, 0);
      _zip32(directory, 0);
      _zip32(directory, offset);
      directory.addAll(name);
    }
    final directoryOffset = output.length;
    output.addAll(directory);
    _zip32(output, 0x06054b50);
    _zip16(output, 0);
    _zip16(output, 0);
    _zip16(output, files.length);
    _zip16(output, files.length);
    _zip32(output, directory.length);
    _zip32(output, directoryOffset);
    _zip16(output, 0);
    return Uint8List.fromList(output);
  }
}

class _ZipReader {
  final Uint8List bytes;
  _ZipReader(this.bytes);

  Map<String, String> readAll() {
    final result = <String, String>{};
    var offset = 0;
    while (
        offset + 30 <= bytes.length && _zipGet32(bytes, offset) == 0x04034b50) {
      final method = _zipGet16(bytes, offset + 8);
      final compressedSize = _zipGet32(bytes, offset + 18);
      final nameSize = _zipGet16(bytes, offset + 26);
      final extraSize = _zipGet16(bytes, offset + 28);
      final nameStart = offset + 30;
      final dataStart = nameStart + nameSize + extraSize;
      final dataEnd = dataStart + compressedSize;
      if (dataEnd > bytes.length) throw FormatException('Truncated ZIP entry.');
      final name = utf8.decode(bytes.sublist(nameStart, nameStart + nameSize));
      final compressed = bytes.sublist(dataStart, dataEnd);
      final data = method == 0
          ? compressed
          : method == 8
              ? _inflateRaw(compressed)
              : throw FormatException('Unsupported ZIP compression method.');
      result[name] = utf8.decode(data);
      offset = dataEnd;
    }
    if (result.isEmpty) throw FormatException('ZIP has no local entries.');
    return result;
  }
}

void _zip16(List<int> out, int value) {
  out
    ..add(value & 255)
    ..add((value >> 8) & 255);
}

void _zip32(List<int> out, int value) {
  out
    ..add(value & 255)
    ..add((value >> 8) & 255)
    ..add((value >> 16) & 255)
    ..add((value >> 24) & 255);
}

int _zipGet16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);
int _zipGet32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

class _DeflateBits {
  final List<int> bytes;
  int offset = 0;
  int buffer = 0;
  int available = 0;
  _DeflateBits(this.bytes);

  int read(int count) {
    while (available < count) {
      if (offset >= bytes.length)
        throw FormatException('Truncated DEFLATE stream.');
      buffer |= bytes[offset++] << available;
      available += 8;
    }
    final value = buffer & ((1 << count) - 1);
    buffer >>= count;
    available -= count;
    return value;
  }

  void align() {
    buffer = 0;
    available = 0;
  }
}

class _Huffman {
  final Map<int, int> codes;
  _Huffman(this.codes);

  int decode(_DeflateBits bits) {
    var code = 0;
    for (var length = 1; length <= 15; length++) {
      code |= bits.read(1) << (length - 1);
      final symbol = codes[(length << 16) | code];
      if (symbol != null) return symbol;
    }
    throw FormatException('Invalid DEFLATE Huffman code.');
  }
}

_Huffman _huffman(List<int> lengths) {
  final counts = List<int>.filled(16, 0);
  for (final length in lengths) {
    if (length < 0 || length > 15)
      throw FormatException('Invalid Huffman length.');
    if (length > 0) counts[length]++;
  }
  final next = List<int>.filled(16, 0);
  var code = 0;
  for (var length = 1; length <= 15; length++) {
    code = (code + counts[length - 1]) << 1;
    next[length] = code;
  }
  final result = <int, int>{};
  for (var symbol = 0; symbol < lengths.length; symbol++) {
    final length = lengths[symbol];
    if (length == 0) continue;
    result[(length << 16) | _reverseBits(next[length]++, length)] = symbol;
  }
  return _Huffman(result);
}

int _reverseBits(int value, int count) {
  var result = 0;
  for (var i = 0; i < count; i++) result = (result << 1) | ((value >> i) & 1);
  return result;
}

({_Huffman literal, _Huffman distance}) _fixedTrees() => (
      literal: _huffman([
        ...List<int>.filled(144, 8),
        ...List<int>.filled(112, 9),
        ...List<int>.filled(24, 7),
        ...List<int>.filled(8, 8),
      ]),
      distance: _huffman(List<int>.filled(32, 5)),
    );

({_Huffman literal, _Huffman distance}) _dynamicTrees(_DeflateBits bits) {
  final literalCount = bits.read(5) + 257;
  final distanceCount = bits.read(5) + 1;
  final codeCount = bits.read(4) + 4;
  const order = [
    16,
    17,
    18,
    0,
    8,
    7,
    9,
    6,
    10,
    5,
    11,
    4,
    12,
    3,
    13,
    2,
    14,
    1,
    15
  ];
  final codeLengths = List<int>.filled(19, 0);
  for (var i = 0; i < codeCount; i++) codeLengths[order[i]] = bits.read(3);
  final codeTree = _huffman(codeLengths);
  final lengths = <int>[];
  while (lengths.length < literalCount + distanceCount) {
    final symbol = codeTree.decode(bits);
    if (symbol <= 15) {
      lengths.add(symbol);
    } else if (symbol == 16) {
      if (lengths.isEmpty) throw FormatException('Invalid DEFLATE repeat.');
      lengths.addAll(List<int>.filled(bits.read(2) + 3, lengths.last));
    } else if (symbol == 17) {
      lengths.addAll(List<int>.filled(bits.read(3) + 3, 0));
    } else if (symbol == 18) {
      lengths.addAll(List<int>.filled(bits.read(7) + 11, 0));
    } else {
      throw FormatException('Invalid DEFLATE code length.');
    }
    if (lengths.length > literalCount + distanceCount)
      throw FormatException('DEFLATE lengths overflow.');
  }
  return (
    literal: _huffman(lengths.sublist(0, literalCount)),
    distance: _huffman(lengths.sublist(literalCount)),
  );
}

Uint8List _inflateRaw(List<int> input) {
  final bits = _DeflateBits(input);
  final output = <int>[];
  var last = false;
  while (!last) {
    last = bits.read(1) == 1;
    final type = bits.read(2);
    if (type == 0) {
      bits.align();
      final length = bits.read(16);
      if ((length ^ 0xffff) != bits.read(16))
        throw FormatException('Invalid stored DEFLATE block.');
      for (var i = 0; i < length; i++) output.add(bits.read(8));
      continue;
    }
    if (type == 3) throw FormatException('Reserved DEFLATE block.');
    final trees = type == 1 ? _fixedTrees() : _dynamicTrees(bits);
    while (true) {
      final symbol = trees.literal.decode(bits);
      if (symbol < 256) {
        output.add(symbol);
      } else if (symbol == 256) {
        break;
      } else if (symbol <= 285) {
        final index = symbol - 257;
        final length = _lengthBase[index] + bits.read(_lengthExtra[index]);
        final distanceSymbol = trees.distance.decode(bits);
        if (distanceSymbol > 29)
          throw FormatException('Invalid DEFLATE distance.');
        final distance = _distanceBase[distanceSymbol] +
            bits.read(_distanceExtra[distanceSymbol]);
        if (distance > output.length)
          throw FormatException('DEFLATE distance exceeds output.');
        for (var i = 0; i < length; i++)
          output.add(output[output.length - distance]);
      } else {
        throw FormatException('Invalid DEFLATE literal.');
      }
    }
  }
  return Uint8List.fromList(output);
}

const _lengthBase = [
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  13,
  15,
  17,
  19,
  23,
  27,
  31,
  35,
  43,
  51,
  59,
  67,
  83,
  99,
  115,
  131,
  163,
  195,
  227,
  258
];
const _lengthExtra = [
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  0
];
const _distanceBase = [
  1,
  2,
  3,
  4,
  5,
  7,
  9,
  13,
  17,
  25,
  33,
  49,
  65,
  97,
  129,
  193,
  257,
  385,
  513,
  769,
  1025,
  1537,
  2049,
  3073,
  4097,
  6145,
  8193,
  12289,
  16385,
  24577
];
const _distanceExtra = [
  0,
  0,
  0,
  0,
  1,
  1,
  2,
  2,
  3,
  3,
  4,
  4,
  5,
  5,
  6,
  6,
  7,
  7,
  8,
  8,
  9,
  9,
  10,
  10,
  11,
  11,
  12,
  12,
  13,
  13
];

const _contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>';
const _rootRelsXml =
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
const _documentRelsXml =
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>';
const _stylesXml =
    '<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style></w:styles>';
const _numberingXml =
    '<?xml version="1.0" encoding="UTF-8"?><w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>';
