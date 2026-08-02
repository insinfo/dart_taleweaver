/// `taleweaver-html` DECODE: HTML string → `State`, via an INJECTED `HtmlParser`.
///
/// Port of `serialize/html-decode.ts`.
library;

import '../../url_safety.dart';
import '../block_id.dart';
import '../build_document_from_tree.dart';
import '../inline_content.dart';
import '../list_defs.dart';
import '../state.dart';
import 'html_node.dart';

const hardBreakEmbedType =
    'hard-break'; // I should use the one from inline_content or define it here if needed.
// Wait, I will import it from inline_content.dart if it's there.
// Or I'll just use 'hard-break' inline since it's just a string const.

ListDef _decimalListDef() {
  return ListDef(levels: [
    ListLevelConfig(style: 'decimal', start: 1, restart: 'always'),
  ]);
}

ListDef _discListDef() {
  return ListDef(levels: [
    ListLevelConfig(style: 'disc', start: 1, restart: 'always'),
  ]);
}

int? _parseOrdinal(String? raw) {
  if (raw == null) return null;
  return int.tryParse(raw);
}

void _recordOrderedLevel(
  _DecodeAccumulator acc,
  String listId,
  int depth,
  int? start,
) {
  final def = acc.listDefs[listId];
  if (def == null) return;

  final base = def.levels.isNotEmpty
      ? def.levels.first
      : const ListLevelConfig(style: 'decimal', start: 1, restart: 'always');

  final levels = List<ListLevelConfig>.from(def.levels);
  while (levels.length <= depth) {
    levels.add(
        ListLevelConfig(style: base.style, start: 1, restart: base.restart));
  }

  if (start != null) {
    final existing = levels[depth];
    levels[depth] = ListLevelConfig(
        style: existing.style, start: start, restart: existing.restart);
  }

  acc.listDefs[listId] = ListDef(levels: levels);
}

const _booleanMarkTags = {
  'STRONG': 'bold',
  'B': 'bold',
  'EM': 'italic',
  'I': 'italic',
  'U': 'underline',
  'S': 'strikethrough',
  'DEL': 'strikethrough',
};

void _accumulateNode(
  HtmlNode node,
  Map<String, dynamic> activeAttrs,
  List<InlineItem> out,
) {
  if (node.kind == HtmlNodeKind.text) {
    final value = node.data;
    if (value.isNotEmpty) {
      out.add(TextItem(text: value, attrs: Map.from(activeAttrs)));
    }
    return;
  }
  if (node.kind != HtmlNodeKind.element) return;

  final tag = node.tagName;
  if (tag == 'BR') {
    out.add(
        EmbedItem(embedType: hardBreakEmbedType, attrs: {}, properties: {}));
    return;
  }

  final markKey = _booleanMarkTags[tag];
  if (markKey != null) {
    final nextAttrs = Map<String, dynamic>.from(activeAttrs);
    nextAttrs[markKey] = true;
    _accumulateInline(node, nextAttrs, out);
    return;
  }

  if (tag == 'A') {
    final href = node.getAttribute('href');
    final nextAttrs = Map<String, dynamic>.from(activeAttrs);
    if (href != null && isExportSafeLinkUrl(href)) {
      nextAttrs['link'] = href;
    }
    _accumulateInline(node, nextAttrs, out);
    return;
  }

  _accumulateInline(node, activeAttrs, out);
}

void _accumulateInline(
  HtmlNode el,
  Map<String, dynamic> activeAttrs,
  List<InlineItem> out,
) {
  for (final node in el.childNodes) {
    _accumulateNode(node, activeAttrs, out);
  }
}

Map<String, dynamic> _inlineContentOf(HtmlNode el) {
  final items = <InlineItem>[];
  _accumulateInline(el, {}, items);
  return {'items': items.map((e) => (e as dynamic).toJson()).toList()};
}

int _headingLevelFromTag(String tag) {
  final n = int.tryParse(tag.substring(1));
  if (n != null && n >= 1 && n <= 6) return n;
  return 1;
}

class _DecodeAccumulator {
  final List<BlockNode> blocks;
  final Map<String, ListDef> listDefs;

  _DecodeAccumulator({required this.blocks, required this.listDefs});
}

const _hyphensKeywords = {'none', 'manual', 'auto'};
const _textAlignKeywords = {
  'start',
  'end',
  'center',
  'justify',
  'left',
  'right'
};

String? _logicalTextAlign(String value) {
  switch (value) {
    case 'left':
    case 'start':
      return 'start';
    case 'right':
    case 'end':
      return 'end';
    case 'center':
      return 'center';
    case 'justify':
      return 'justify';
    default:
      return null;
  }
}

Map<String, dynamic> _resolveInheritedAttrs(
  HtmlNode el,
  Map<String, dynamic> inherited,
) {
  Map<String, dynamic>? next;
  void setKey(String key, dynamic value) {
    next ??= Map<String, dynamic>.from(inherited);
    next![key] = value;
  }

  final lang = el.getAttribute('lang');
  if (lang != null && lang.trim().isNotEmpty) setKey('lang', lang.trim());

  final hyphens = el.getAttribute('hyphens');
  if (hyphens != null && _hyphensKeywords.contains(hyphens.trim())) {
    setKey('hyphens', hyphens.trim());
  }

  final align = el.getStyleProperty('textAlign') ?? '';
  if (align.isNotEmpty && _textAlignKeywords.contains(align)) {
    final logical = _logicalTextAlign(align);
    if (logical != null) setKey('textAlign', logical);
  }

  return next ?? inherited;
}

Map<String, dynamic>? _withInheritedAttrs(Map<String, dynamic> inherited,
    [Map<String, dynamic>? own]) {
  if (inherited.isEmpty) return own;
  final merged = Map<String, dynamic>.from(inherited);
  if (own != null) merged.addAll(own);
  return merged;
}

void _walkList(
  HtmlNode listEl,
  String listId,
  int depth,
  _DecodeAccumulator acc,
  Map<String, dynamic> inherited,
) {
  final def = acc.listDefs[listId];
  final ordered = def != null && classifyListDef(def) == 'ordered';

  if (ordered) {
    _recordOrderedLevel(
        acc, listId, depth, _parseOrdinal(listEl.getAttribute('start')));
  }

  for (final child in listEl.children) {
    final childTag = child.tagName;
    if (childTag == 'UL' || childTag == 'OL') {
      _walkList(child, listId, depth + 1, acc,
          _resolveInheritedAttrs(child, inherited));
      continue;
    }

    if (childTag != 'LI') continue;

    final liInherited = _resolveInheritedAttrs(child, inherited);
    final items = <InlineItem>[];
    final nestedLists = <HtmlNode>[];

    for (final liChild in child.childNodes) {
      if (liChild.kind == HtmlNodeKind.element) {
        final t = liChild.tagName;
        if (t == 'UL' || t == 'OL') {
          nestedLists.add(liChild);
          continue;
        }
      }
      _accumulateNode(liChild, {}, items);
    }

    final override =
        ordered ? _parseOrdinal(child.getAttribute('value')) : null;

    final liAttrs = Map<String, dynamic>.from(liInherited);
    liAttrs['listId'] = listId;
    liAttrs['listLevel'] = depth;
    if (override != null) liAttrs['listCounterOverride'] = override;

    acc.blocks.add(LeafBlockNode(
      type: 'list-item',
      attrs: liAttrs,
      inlineContent: {
        'items': items.map((e) => (e as dynamic).toJson()).toList()
      },
    ));

    for (final nested in nestedLists) {
      _walkList(nested, listId, depth + 1, acc, liInherited);
    }
  }
}

const _blockLevelTags = {
  'P',
  'H1',
  'H2',
  'H3',
  'H4',
  'H5',
  'H6',
  'HR',
  'IMG',
  'UL',
  'OL',
  'TABLE',
  'DIV',
};

List<BlockNode> _decodeFlowContent(
  HtmlNode el,
  _DecodeAccumulator acc,
  Map<String, dynamic> inherited,
) {
  final cellAcc = _DecodeAccumulator(blocks: [], listDefs: acc.listDefs);
  var pending = <InlineItem>[];

  void flush() {
    if (pending.isEmpty) return;
    cellAcc.blocks.add(LeafBlockNode(
      type: 'paragraph',
      attrs: _withInheritedAttrs(inherited) ?? {},
      inlineContent: {
        'items': pending.map((e) => (e as dynamic).toJson()).toList()
      },
    ));
    pending = [];
  }

  for (final child in el.childNodes) {
    if (child.kind == HtmlNodeKind.element &&
        _blockLevelTags.contains(child.tagName)) {
      flush();
      if (child.tagName == 'DIV') {
        cellAcc.blocks.addAll(_decodeFlowContent(
            child, acc, _resolveInheritedAttrs(child, inherited)));
      } else {
        _decodeBlockElement(child, cellAcc, inherited);
      }
    } else {
      _accumulateNode(child, {}, pending);
    }
  }
  flush();
  return cellAcc.blocks;
}

int _parseSpan(String? raw) {
  if (raw == null) return 1;
  final n = int.tryParse(raw);
  return n != null && n > 1 ? n : 1;
}

double? _parseColWidth(HtmlNode col) {
  final raw = col.getStyleProperty('width');
  if (raw == null) return null;
  final match = RegExp(r'^([\d.]+)%$').firstMatch(raw.trim());
  if (match == null) return null;
  final numStr = match.group(1)!;
  final frac = double.tryParse(numStr);
  if (frac != null && frac > 0) return frac / 100.0;
  return null;
}

List<double> _fillEqualShare(List<double?> widths) {
  final knownSum = widths.whereType<double>().fold(0.0, (a, b) => a + b);
  final nullCount = widths.where((w) => w == null).length;
  final each = nullCount > 0
      ? (1.0 - knownSum).clamp(0.0, double.infinity) / nullCount
      : 0.0;
  return widths.map((w) => w ?? each).toList();
}

ContainerBlockNode _decodeTableRow(
  HtmlNode rowEl,
  _DecodeAccumulator acc,
  Map<String, dynamic> inherited,
) {
  final rowInherited = _resolveInheritedAttrs(rowEl, inherited);
  final cells = <ContainerBlockNode>[];

  for (final cellEl in rowEl.children) {
    if (cellEl.tagName != 'TD' && cellEl.tagName != 'TH') continue;
    final cellInherited = _resolveInheritedAttrs(cellEl, rowInherited);
    final attrs = <String, dynamic>{};

    final colSpan = _parseSpan(cellEl.getAttribute('colspan'));
    final rowSpan = _parseSpan(cellEl.getAttribute('rowspan'));
    if (colSpan > 1) attrs['colSpan'] = colSpan;
    if (rowSpan > 1) attrs['rowSpan'] = rowSpan;

    var children = _decodeFlowContent(cellEl, acc, cellInherited);
    if (children.isEmpty) {
      children = [
        LeafBlockNode(
            type: 'paragraph', attrs: {}, inlineContent: {'items': []})
      ];
    }

    cells.add(ContainerBlockNode(
        type: 'table-cell', attrs: attrs, children: children));
  }

  return ContainerBlockNode(type: 'table-row', attrs: {}, children: cells);
}

void _decodeTable(
  HtmlNode el,
  _DecodeAccumulator acc,
  Map<String, dynamic> inherited,
) {
  final rowEls = <HtmlNode>[];
  int headerRowCount = 0;
  bool sawBodyRows = false;
  List<double>? columnWidths;

  for (final child in el.children) {
    switch (child.tagName) {
      case 'COLGROUP':
        final widths = <double?>[];
        bool anyUsable = false;
        for (final col in child.children) {
          if (col.tagName != 'COL') continue;
          final w = _parseColWidth(col);
          if (w != null) anyUsable = true;
          widths.add(w);
        }
        if (anyUsable) columnWidths = _fillEqualShare(widths);
        break;
      case 'THEAD':
        final theadRows =
            child.children.where((c) => c.tagName == 'TR').toList();
        if (!sawBodyRows) headerRowCount = theadRows.length;
        rowEls.addAll(theadRows);
        break;
      case 'TBODY':
      case 'TFOOT':
        sawBodyRows = true;
        rowEls.addAll(child.children.where((c) => c.tagName == 'TR'));
        break;
      case 'TR':
        sawBodyRows = true;
        rowEls.add(child);
        break;
    }
  }

  final rows =
      rowEls.map((rowEl) => _decodeTableRow(rowEl, acc, inherited)).toList();
  final attrs = <String, dynamic>{};
  if (columnWidths != null) attrs['columnWidths'] = columnWidths;
  if (headerRowCount > 0) attrs['headerRowCount'] = headerRowCount;

  acc.blocks
      .add(ContainerBlockNode(type: 'table', attrs: attrs, children: rows));
}

void _decodeBlockElement(
  HtmlNode el,
  _DecodeAccumulator acc,
  Map<String, dynamic> parentInherited,
) {
  final tag = el.tagName;
  final inherited = _resolveInheritedAttrs(el, parentInherited);

  switch (tag) {
    case 'P':
      acc.blocks.add(LeafBlockNode(
        type: 'paragraph',
        attrs: _withInheritedAttrs(inherited) ?? {},
        inlineContent: _inlineContentOf(el),
      ));
      return;
    case 'H1':
    case 'H2':
    case 'H3':
    case 'H4':
    case 'H5':
    case 'H6':
      acc.blocks.add(LeafBlockNode(
        type: 'heading',
        attrs: _withInheritedAttrs(
                inherited, {'level': _headingLevelFromTag(tag)}) ??
            {},
        inlineContent: _inlineContentOf(el),
      ));
      return;
    case 'HR':
      acc.blocks.add(LeafBlockNode(
          type: 'horizontal-line', attrs: {}, inlineContent: {'items': []}));
      return;
    case 'IMG':
      final rawSrc = el.getAttribute('src');
      final src = rawSrc != null && isExportSafeLinkUrl(rawSrc) ? rawSrc : '';
      final attrs = <String, dynamic>{'src': src};

      final width = el.getAttribute('width');
      if (width != null &&
          width.trim().isNotEmpty &&
          double.tryParse(width) != null) {
        attrs['width'] = double.parse(width);
      }

      final height = el.getAttribute('height');
      if (height != null &&
          height.trim().isNotEmpty &&
          double.tryParse(height) != null) {
        attrs['height'] = double.parse(height);
      }

      final alt = el.getAttribute('alt');
      if (alt != null) attrs['alt'] = alt;

      acc.blocks.add(LeafBlockNode(
          type: 'image', attrs: attrs, inlineContent: {'items': []}));
      return;
    case 'UL':
    case 'OL':
      final listId = newListId();
      acc.listDefs[listId] = tag == 'OL' ? _decimalListDef() : _discListDef();
      _walkList(el, listId, 0, acc, inherited);
      return;
    case 'TABLE':
      _decodeTable(el, acc, inherited);
      return;
    default:
      for (final child in el.children) {
        _decodeBlockElement(child, acc, inherited);
      }
      return;
  }
}

/// Decode an HTML string to a State.
State decodeHtml(
  String html,
  IdAllocator allocator,
  HtmlParser parseHtml,
) {
  final body = parseHtml(html);
  final acc = _DecodeAccumulator(blocks: [], listDefs: {});

  final rootInherited = _resolveInheritedAttrs(body, {});
  for (final child in body.children) {
    _decodeBlockElement(child, acc, rootInherited);
  }

  if (acc.blocks.isEmpty) {
    acc.blocks.add(LeafBlockNode(
        type: 'paragraph', attrs: {}, inlineContent: {'items': []}));
  }

  final root =
      ContainerBlockNode(type: 'document', attrs: {}, children: acc.blocks);
  return buildDocumentFromTree(root, acc.listDefs, allocator);
}
