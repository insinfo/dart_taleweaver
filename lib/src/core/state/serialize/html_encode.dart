/// `taleweaver-html` ENCODE: a pure `State` → HTML-string serialization (no parser).
///
/// Port of `serialize/html-encode.ts`.
library;

import '../../url_safety.dart';
import '../attrs.dart';
import '../block.dart';
import '../block_id.dart';
import '../document_order.dart';

import '../inline_content.dart';
import '../list_defs.dart';
import '../../numbering/numbering.dart';
import '../ops/insert_cross_reference.dart';
import '../ops/insert_footnote.dart';
import '../state.dart';
import 'dart:convert' show htmlEscape;

String _escapeHtml(String s) {
  return htmlEscape.convert(s);
}

String? _strAttr(dynamic value) {
  return value is String ? value : null;
}

num? _numAttr(dynamic value) {
  return value is num ? value : null;
}

final _warnDropEmbedTypes = {
  footnoteAnchorEmbedType,
  crossReferenceEmbedType,
};

int _headingLevel(ReadonlyAttrs attrs) {
  final level = _numAttr(attrs['level']);
  if (level != null && level >= 1 && level <= 6) return level.toInt();
  return 1;
}

class _MarkSpec {
  final String attrKey;
  final String Function(String inner, dynamic attrValue) wrap;

  const _MarkSpec({required this.attrKey, required this.wrap});
}

final _markSpecs = <_MarkSpec>[
  _MarkSpec(attrKey: 'strikethrough', wrap: (inner, _) => '<s>$inner</s>'),
  _MarkSpec(attrKey: 'underline', wrap: (inner, _) => '<u>$inner</u>'),
  _MarkSpec(attrKey: 'italic', wrap: (inner, _) => '<em>$inner</em>'),
  _MarkSpec(attrKey: 'bold', wrap: (inner, _) => '<strong>$inner</strong>'),
  _MarkSpec(
    attrKey: 'link',
    wrap: (inner, value) {
      final url = _strAttr(value);
      return url != null && isExportSafeLinkUrl(url)
          ? '<a href="${_escapeHtml(url)}">$inner</a>'
          : inner;
    },
  ),
];

bool _isMarkActive(dynamic value) {
  return value != null && value != false;
}

String _wrapMarks(String escapedText, ReadonlyAttrs attrs) {
  var out = escapedText;
  for (final spec in _markSpecs) {
    final value = attrs[spec.attrKey];
    if (_isMarkActive(value)) {
      out = spec.wrap(out, value);
    }
  }
  return out;
}

void Function(String) _makeDropWarner() {
  final warned = <String>{};
  return (String embedType) {
    if (!_warnDropEmbedTypes.contains(embedType)) return;
    if (warned.contains(embedType)) return;
    warned.add(embedType);
    // In dev mode, we could print a warning. For now we just print it.
    print(
      '[@taleweaver/core] taleweaver-html encode dropped a content-bearing '
      '"$embedType" embed — the HTML format does not support it, so this '
      'content is LOST on export. Use the "taleweaver-binary" format for '
      'lossless, id-preserving interchange.',
    );
  };
}

String _emitImgTag(String? src, num? width, num? height, String? alt) {
  final safeSrc = src != null && isExportSafeLinkUrl(src) ? src : "";
  var attrsStr = ' src="${_escapeHtml(safeSrc)}"';
  if (width != null) attrsStr += ' width="$width"';
  if (height != null) attrsStr += ' height="$height"';
  if (alt != null) attrsStr += ' alt="${_escapeHtml(alt)}"';
  return '<img$attrsStr>';
}

String _encodeInline(InlineContent? content, void Function(String) warnDrop) {
  if (content == null) return '';
  var out = '';
  for (final item in content.items) {
    if (item is TextItem) {
      out += _wrapMarks(_escapeHtml(item.text), item.attrs);
    } else if (item is EmbedItem) {
      if (item.embedType == hardBreakEmbedType) {
        out += '<br>';
      } else if (item.embedType == inlineImageEmbedType) {
        out += _emitImgTag(
          _strAttr(item.properties['src']),
          _numAttr(item.properties['width']),
          _numAttr(item.properties['height']),
          _strAttr(item.properties['alt']),
        );
      } else {
        warnDrop(item.embedType);
      }
    }
  }
  return out;
}

String _encodeLeaf(Block block, void Function(String) warnDrop) {
  final inner = _encodeInline(block.inlineContent, warnDrop);
  switch (block.type) {
    case 'heading':
      final level = _headingLevel(block.attrs);
      return '<h$level>$inner</h$level>';
    case 'paragraph':
      return '<p>$inner</p>';
    case 'horizontal-line':
      return '<hr>';
    case 'image':
      return _emitImgTag(
        _strAttr(block.attrs['src']),
        _numAttr(block.attrs['width']),
        _numAttr(block.attrs['height']),
        _strAttr(block.attrs['alt']),
      );
    default:
      return '';
  }
}

class _RunItem {
  final int level;
  final String inner;
  final int? value;
  const _RunItem({required this.level, required this.inner, this.value});
}

String _encodeListRun(List<_RunItem> items, String tag) {
  final ordered = tag == 'ol';
  var out = '';
  var openLevels = 0;
  var liOpenAtLevel = -1;
  final expectedAtLevel = <int?>[];

  void openList(int? startValue) {
    out += (ordered && startValue != null && startValue != 1)
        ? '<ol start="$startValue">'
        : '<$tag>';
    openLevels++;
  }

  void closeList() {
    out += '</$tag>';
    openLevels--;
  }

  void closeLiIfOpen() {
    if (liOpenAtLevel >= 0) {
      out += '</li>';
      liOpenAtLevel = -1;
    }
  }

  String emitLiTag(_RunItem item, bool ordered, List<int?> expectedAtLevel) {
    if (!ordered || item.value == null) return '<li>';
    final expected = expectedAtLevel.length > item.level ? expectedAtLevel[item.level] : null;
    final tag = (expected != null && item.value != expected)
        ? '<li value="${item.value}">'
        : '<li>';
    
    while (expectedAtLevel.length <= item.level) {
      expectedAtLevel.add(null);
    }
    expectedAtLevel[item.level] = item.value! + 1;
    return tag;
  }

  for (final item in items) {
    final target = item.level + 1;
    if (target > openLevels) {
      while (openLevels < target) {
        final isFinal = openLevels == target - 1;
        openList(isFinal ? item.value : null);
      }
    } else if (target < openLevels) {
      closeLiIfOpen();
      while (openLevels > target) {
        closeList();
        out += '</li>';
        liOpenAtLevel = -1;
      }
      expectedAtLevel.length = target;
    } else {
      closeLiIfOpen();
    }
    
    out += emitLiTag(item, ordered, expectedAtLevel);
    out += item.inner;
    liOpenAtLevel = item.level;
  }
  
  closeLiIfOpen();
  while (openLevels > 0) {
    closeList();
    if (openLevels > 0) out += '</li>';
  }
  return out;
}

String _encodeTable(
  State state,
  Block table,
  Map<String, ListDef> listDefs,
  Map<BlockId, CounterValue> counters,
  void Function(String) warnDrop,
) {
  var out = '<table>';

  final widths = table.attrs['columnWidths'];
  if (widths is List && widths.isNotEmpty) {
    out += '<colgroup>';
    for (final w in widths) {
      if (w is num) {
        out += '<col style="width:${(w * 100).toStringAsFixed(4)}%">';
      } else {
        out += '<col>';
      }
    }
    out += '</colgroup>';
  }

  var rowId = table.firstChildId;
  while (rowId != null) {
    final row = getBlock(state, rowId);
    if (row == null) break;
    if (row.type == 'table-row') {
      out += '<tr>';
      var cellId = row.firstChildId;
      while (cellId != null) {
        final cellBlock = getBlock(state, cellId);
        if (cellBlock == null) break;
        if (cellBlock.type == 'table-cell') {
          out += _encodeCell(state, cellBlock, listDefs, counters, warnDrop);
        }
        cellId = cellBlock.nextSiblingId;
      }
      out += '</tr>';
    }
    rowId = row.nextSiblingId;
  }

  return out + '</table>';
}

String _encodeCell(
  State state,
  Block cell,
  Map<String, ListDef> listDefs,
  Map<BlockId, CounterValue> counters,
  void Function(String) warnDrop,
) {
  final rowSpan = _numAttr(cell.attrs['rowSpan']);
  final colSpan = _numAttr(cell.attrs['colSpan']);
  var attrsStr = '';
  if (rowSpan != null && rowSpan > 1) attrsStr += ' rowspan="$rowSpan"';
  if (colSpan != null && colSpan > 1) attrsStr += ' colspan="$colSpan"';
  final inner = _encodeBlockSequence(state, cell.firstChildId, listDefs, counters, warnDrop);
  return '<td$attrsStr>$inner</td>';
}

String _encodeBlockSequence(
  State state,
  BlockId? firstChildId,
  Map<String, ListDef> listDefs,
  Map<BlockId, CounterValue> counters,
  void Function(String) warnDrop,
) {
  final blocks = <Block>[];
  var childId = firstChildId;
  while (childId != null) {
    final block = getBlock(state, childId);
    if (block == null) break;
    blocks.add(block);
    childId = block.nextSiblingId;
  }

  var out = '';
  var i = 0;
  while (i < blocks.length) {
    final block = blocks[i];
    if (block.type == 'list-item') {
      final listIdRaw = _strAttr(block.attrs['listId']);
      final listId = listIdRaw ?? '';
      final runItems = <_RunItem>[];
      var j = i;
      while (j < blocks.length && blocks[j].type == 'list-item') {
        final itemBlock = blocks[j];
        final itemListId = _strAttr(itemBlock.attrs['listId']) ?? '';
        if (itemListId != listId) break;
        final levelRaw = _numAttr(itemBlock.attrs['listLevel']);
        final level = levelRaw != null && levelRaw >= 0 ? levelRaw.toInt() : 0;
        runItems.add(_RunItem(
          level: level,
          inner: _encodeInline(itemBlock.inlineContent, warnDrop),
          value: counters[itemBlock.id]?.value,
        ));
        j++;
      }
      final def = listDefs[listId];
      final tag = (def != null && classifyListDef(def) == 'unordered') ? 'ul' : 'ol';
      out += _encodeListRun(runItems, tag);
      i = j;
    } else if (block.type == 'table') {
      out += _encodeTable(state, block, listDefs, counters, warnDrop);
      i++;
    } else {
      out += _encodeLeaf(block, warnDrop);
      i++;
    }
  }
  return out;
}

/// Encode the document State to an HTML string.
String encodeHtml(State state) {
  final root = getBlock(state, state.rootId);
  if (root == null) return '<body></body>';
  final listDefs = getListDefsForState(state);
  final counters = docHasLists(state)
      ? computeCounters(collectListEvents(state), listDefs)
      : <BlockId, CounterValue>{};
  final body = _encodeBlockSequence(state, root.firstChildId, listDefs, counters, _makeDropWarner());
  return '<body>$body</body>';
}
