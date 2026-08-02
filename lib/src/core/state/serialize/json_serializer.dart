/// JSON document serializer.
///
/// Port of `serialize/json-serializer.ts`.
library;

import 'dart:convert';

import '../attrs.dart';
import '../block.dart';
import '../block_id.dart';
import '../block_kinds.dart';
import '../build_state_from_blocks.dart';
import '../comments.dart';
import '../inline_content.dart';
import '../list_defs.dart';
import '../state.dart';
import '../suggestions.dart';
import 'document_serializer.dart';

const String jsonFormat = 'taleweaver-json';
const int jsonVersion = 1;

const Set<String> _tableTypes = {'table', 'table-row', 'table-cell'};
const Set<String> _counterRestarts = {'always', 'never', 'after-break'};
const Set<String> _suggestionKinds = {'insertion', 'deletion', 'formatting'};

// ---------------------------------------------------------------------------
// DocumentSerializer Implementation
// ---------------------------------------------------------------------------

class _JsonDocumentSerializer implements DocumentSerializer<String> {
  final IdAllocator allocator;
  final BlockKindResolver blockBlockKindResolver;

  _JsonDocumentSerializer({
    required this.allocator,
    required this.blockBlockKindResolver,
  });

  @override
  String get format => jsonFormat;

  @override
  String encode(State state) {
    final docMap = _encodeDocument(state, blockBlockKindResolver);
    return const JsonEncoder.withIndent('  ').convert(docMap);
  }

  @override
  State decode(String source) {
    return _decodeDocument(source, allocator, blockBlockKindResolver);
  }
}

DocumentSerializer<String> createJsonDocumentSerializer({
  required IdAllocator allocator,
  required BlockKindResolver blockBlockKindResolver,
}) {
  return _JsonDocumentSerializer(
    allocator: allocator,
    blockBlockKindResolver: blockBlockKindResolver,
  );
}

// ---------------------------------------------------------------------------
// Encode
// ---------------------------------------------------------------------------

Map<String, dynamic> _encodeDocument(
  State state,
  BlockKindResolver resolver,
) {
  final root =
      _encodeNode(state, state.rootId, (s, id) => getBlock(s, id), resolver);

  final embedRoots = _encodeForestRoots(
    state,
    state.doc.getEmbedContentIds(),
    (s, id) => getEmbedContent(s, id),
    resolver,
  );

  final templateRoots = _encodeForestRoots(
    state,
    state.doc.getTemplateContentIds(),
    (s, id) => getTemplateContent(s, id),
    resolver,
  );

  final out = <String, dynamic>{
    'format': jsonFormat,
    'version': jsonVersion,
    'root': root,
  };

  if (embedRoots.isNotEmpty) out['embedContents'] = embedRoots;
  if (templateRoots.isNotEmpty) out['templateContents'] = templateRoots;

  final listDefs = _encodeListDefs(state);
  if (listDefs != null) out['listDefs'] = listDefs;

  final comments = _encodeComments(state);
  if (comments != null) out['comments'] = comments;

  final suggestions = _encodeSuggestions(state);
  if (suggestions != null) out['suggestions'] = suggestions;

  return out;
}

List<Map<String, dynamic>> _encodeForestRoots(
  State state,
  List<BlockId> ids,
  Block? Function(State, BlockId) read,
  BlockKindResolver resolver,
) {
  final roots = <Map<String, dynamic>>[];
  for (final id in ids) {
    final block = read(state, id);
    if (block != null && block.parentId == null) {
      roots.add(_encodeNode(state, id, read, resolver));
    }
  }
  return roots;
}

Map<String, dynamic> _encodeNode(
  State state,
  BlockId id,
  Block? Function(State, BlockId) read,
  BlockKindResolver resolver,
) {
  final block = read(state, id);
  if (block == null) {
    throw StateError('json-serializer: block "$id" not found during encode');
  }
  if (_tableTypes.contains(block.type)) {
    throw StateError(
      'json-serializer: cannot encode table block (type "${block.type}") — '
      'tables are not representable in taleweaver-json; use the binary serializer '
      '(taleweaver-binary) for lossless serialization of table-bearing documents.',
    );
  }

  final kind = _resolveKind(resolver, block.type);
  final node = <String, dynamic>{
    'id': block.id.value,
    'type': block.type,
  };

  if (block.attrs.isNotEmpty) {
    node['attrs'] = Map<String, dynamic>.of(block.attrs);
  }

  switch (kind) {
    case Kind.container:
      node['children'] = _encodeChildren(state, block, read, resolver);
      break;
    case Kind.inlineBearingLeaf:
      node['content'] = _encodeInlineContent(block.inlineContent);
      break;
    case Kind.atomicLeaf:
      // Neither content nor children.
      break;
  }

  return node;
}

List<Map<String, dynamic>> _encodeChildren(
  State state,
  Block parent,
  Block? Function(State, BlockId) read,
  BlockKindResolver resolver,
) {
  final out = <Map<String, dynamic>>[];
  var childId = parent.firstChildId;
  while (childId != null) {
    out.add(_encodeNode(state, childId, read, resolver));
    final child = read(state, childId);
    if (child == null) break;
    childId = child.nextSiblingId;
  }
  return out;
}

List<Map<String, dynamic>> _encodeInlineContent(InlineContent? content) {
  if (content == null) return [];
  return content.items.map(_encodeInlineItem).toList();
}

Map<String, dynamic> _encodeInlineItem(InlineItem item) {
  if (item is TextItem) {
    final out = <String, dynamic>{'text': item.text};
    if (item.attrs.isNotEmpty)
      out['attrs'] = Map<String, dynamic>.of(item.attrs);
    return out;
  } else if (item is EmbedItem) {
    final out = <String, dynamic>{'embed': item.embedType};
    if (item.attrs.isNotEmpty)
      out['attrs'] = Map<String, dynamic>.of(item.attrs);
    if (item.properties.isNotEmpty)
      out['props'] = Map<String, dynamic>.of(item.properties);
    return out;
  }
  throw StateError('Unknown InlineItem type');
}

Map<String, dynamic>? _encodeListDefs(State state) {
  final defs = getListDefsForState(state);
  if (defs.isEmpty) return null;
  final out = <String, dynamic>{};
  final sortedKeys = defs.keys.toList()..sort();
  for (final listId in sortedKeys) {
    final def = defs[listId]!;
    out[listId] = {
      'levels': def.levels
          .map((l) => {
                'style': l.style,
                'start': l.start,
                'restart': l.restart,
              })
          .toList()
    };
  }
  return out;
}

Map<String, dynamic>? _encodeComments(State state) {
  final comments = getComments(state);
  if (comments.isEmpty) return null;
  final out = <String, dynamic>{};
  final sorted = List<CommentRecord>.from(comments)
    ..sort((a, b) => a.id.toString().compareTo(b.id.toString()));
  for (final c in sorted) {
    out[c.id.value] = {
      'author': c.author,
      'body': c.body,
      'createdAt': c.createdAt,
      'replies': c.replies
          .map((r) => {
                'id': r.id,
                'author': r.author,
                'body': r.body,
                'createdAt': r.createdAt,
              })
          .toList(),
      'resolved': c.resolved,
    };
  }
  return out;
}

Map<String, dynamic>? _encodeSuggestions(State state) {
  final suggestions = getSuggestions(state);
  if (suggestions.isEmpty) return null;
  final out = <String, dynamic>{};
  final sorted = List<SuggestionRecord>.from(suggestions)
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  for (final s in sorted) {
    final bare = <String, dynamic>{
      'kind': s.kind,
      'author': s.author,
      'createdAt': s.createdAt,
    };
    if (s.proposedAttrs != null)
      bare['proposedAttrs'] = Map<String, dynamic>.of(s.proposedAttrs!);
    out[s.id.value] = bare;
  }
  return out;
}

Kind _resolveKind(BlockKindResolver resolver, String type) {
  final kind = resolver.getBlockKind(type);
  if (kind == null) {
    throw StateError(
        'json-serializer: block type "$type" is not registered (no Kind)');
  }
  return kind;
}

// ---------------------------------------------------------------------------
// Decode
// ---------------------------------------------------------------------------

State _decodeDocument(
  String source,
  IdAllocator allocator,
  BlockKindResolver resolver,
) {
  dynamic parsed;
  try {
    parsed = jsonDecode(source);
  } catch (_) {
    throw MalformedDocumentError(jsonFormat);
  }

  if (!_isRecord(parsed)) throw MalformedDocumentError(jsonFormat);
  final map = parsed as Map<String, dynamic>;

  if (map['format'] != jsonFormat) throw MalformedDocumentError(jsonFormat);
  if (map['version'] != jsonVersion) throw MalformedDocumentError(jsonFormat);
  if (!_isRecord(map['root'])) throw MalformedDocumentError(jsonFormat);

  final blocks = <Block>[];
  final rootId =
      _flattenNode(map['root'], null, blocks, allocator, resolver).id;

  final embedContents = <Block>[];
  for (final node in _toNodeArray(map['embedContents'])) {
    _flattenNode(node, null, embedContents, allocator, resolver);
  }

  final templateContents = <Block>[];
  for (final node in _toNodeArray(map['templateContents'])) {
    _flattenNode(node, null, templateContents, allocator, resolver);
  }

  return buildStateFromBlocks(BuildStateFromBlocksArgs(
    rootId: rootId,
    blocks: blocks,
    embedContents: embedContents.isNotEmpty ? embedContents : null,
    templateContents: templateContents.isNotEmpty ? templateContents : null,
    listDefs: _decodeListDefs(map['listDefs']),
    comments: _decodeComments(map['comments']),
    suggestions: _decodeSuggestions(map['suggestions']),
  ));
}

class _FlattenedRef {
  final BlockId id;
  final int index;
  const _FlattenedRef(this.id, this.index);
}

_FlattenedRef _flattenNode(
  dynamic raw,
  BlockId? parentId,
  List<Block> out,
  IdAllocator allocator,
  BlockKindResolver resolver,
) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  final type = map['type'];
  if (type is! String) throw MalformedDocumentError(jsonFormat);
  if (_tableTypes.contains(type)) throw MalformedDocumentError(jsonFormat);

  final id =
      map['id'] is String ? BlockId(map['id'] as String) : allocator.allocate();
  final attrs = _decodeAttrs(map['attrs']);
  final kind = _resolveKind(resolver, type);
  final inlineContent = _decodeInlineContent(kind, map['content']);

  final selfIndex = out.length;
  out.add(Block(
    id: id,
    type: type,
    attrs: attrs,
    parentId: parentId,
    prevSiblingId: null,
    nextSiblingId: null,
    firstChildId: null,
    lastChildId: null,
    inlineContent: inlineContent,
  ));

  BlockId? firstChildId;
  BlockId? lastChildId;

  if (kind == Kind.container) {
    final childRefs = <_FlattenedRef>[];
    for (final child in _toNodeArray(map['children'])) {
      childRefs.add(_flattenNode(child, id, out, allocator, resolver));
    }

    for (var i = 0; i < childRefs.length; i++) {
      final ref = childRefs[i];
      final slot = out[ref.index];
      final prev = i > 0 ? childRefs[i - 1] : null;
      final next = i < childRefs.length - 1 ? childRefs[i + 1] : null;

      out[ref.index] = Block(
        id: slot.id,
        type: slot.type,
        attrs: slot.attrs,
        parentId: slot.parentId,
        prevSiblingId: prev?.id,
        nextSiblingId: next?.id,
        firstChildId: slot.firstChildId,
        lastChildId: slot.lastChildId,
        inlineContent: slot.inlineContent,
      );
    }

    if (childRefs.isNotEmpty) {
      firstChildId = childRefs.first.id;
      lastChildId = childRefs.last.id;
    }
  }

  if (firstChildId != null || lastChildId != null) {
    final slot = out[selfIndex];
    out[selfIndex] = Block(
      id: slot.id,
      type: slot.type,
      attrs: slot.attrs,
      parentId: slot.parentId,
      prevSiblingId: slot.prevSiblingId,
      nextSiblingId: slot.nextSiblingId,
      firstChildId: firstChildId,
      lastChildId: lastChildId,
      inlineContent: slot.inlineContent,
    );
  }

  return _FlattenedRef(id, selfIndex);
}

InlineContent? _decodeInlineContent(Kind kind, dynamic rawContent) {
  if (kind != Kind.inlineBearingLeaf) return null;
  final items = <InlineItem>[];
  for (final rawItem in _toItemArray(rawContent)) {
    items.add(_decodeInlineItem(rawItem));
  }
  return InlineContent(items);
}

InlineItem _decodeInlineItem(dynamic raw) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;

  if (map['text'] is String) {
    return TextItem(
      text: map['text'] as String,
      attrs: _decodeAttrs(map['attrs']),
    );
  }
  if (map['embed'] is String) {
    return EmbedItem(
      embedType: map['embed'] as String,
      attrs: _decodeAttrs(map['attrs']),
      properties: _decodeProps(map['props']),
    );
  }
  throw MalformedDocumentError(jsonFormat);
}

ReadonlyAttrs _decodeAttrs(dynamic raw) {
  if (raw == null) return const {};
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  return Map<String, dynamic>.of(raw as Map<String, dynamic>);
}

Map<String, dynamic> _decodeProps(dynamic raw) {
  if (raw == null) return const {};
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  return Map<String, dynamic>.of(raw as Map<String, dynamic>);
}

Map<String, ListDef>? _decodeListDefs(dynamic raw) {
  if (raw == null) return null;
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  final out = <String, ListDef>{};
  for (final entry in map.entries) {
    out[entry.key] = _decodeListDef(entry.value);
  }
  return out;
}

ListDef _decodeListDef(dynamic raw) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  if (map['levels'] is! List) throw MalformedDocumentError(jsonFormat);
  final levels = (map['levels'] as List).map(_decodeListLevel).toList();
  return ListDef(levels: levels);
}

ListLevelConfig _decodeListLevel(dynamic raw) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  final style = map['style'];
  if (style is! String)
    throw MalformedDocumentError(
        jsonFormat); // Simple check, real impl could validate format-counter
  final start = map['start'];
  if (start is! num) throw MalformedDocumentError(jsonFormat);
  final restart = map['restart'];
  if (restart is! String || !_counterRestarts.contains(restart))
    throw MalformedDocumentError(jsonFormat);

  return ListLevelConfig(
    style: style,
    start: start.toInt(),
    restart: restart,
  );
}

List<CommentRecord>? _decodeComments(dynamic raw) {
  if (raw == null) return null;
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  final out = <CommentRecord>[];
  for (final entry in map.entries) {
    final rec = entry.value;
    if (!_isRecord(rec)) throw MalformedDocumentError(jsonFormat);
    final recMap = rec as Map<String, dynamic>;
    if (recMap['author'] is! String) throw MalformedDocumentError(jsonFormat);
    if (recMap['body'] is! String) throw MalformedDocumentError(jsonFormat);
    if (recMap['createdAt'] is! num) throw MalformedDocumentError(jsonFormat);
    if (recMap['resolved'] is! bool) throw MalformedDocumentError(jsonFormat);
    if (recMap['replies'] is! List) throw MalformedDocumentError(jsonFormat);

    final replies =
        (recMap['replies'] as List).map(_decodeCommentReply).toList();
    out.add(CommentRecord(
      id: CommentId(entry.key),
      author: recMap['author'] as String,
      body: recMap['body'] as String,
      createdAt: (recMap['createdAt'] as num).toInt(),
      replies: replies,
      resolved: recMap['resolved'] as bool,
    ));
  }
  return out;
}

CommentReply _decodeCommentReply(dynamic raw) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  if (map['id'] is! String) throw MalformedDocumentError(jsonFormat);
  if (map['author'] is! String) throw MalformedDocumentError(jsonFormat);
  if (map['body'] is! String) throw MalformedDocumentError(jsonFormat);
  if (map['createdAt'] is! num) throw MalformedDocumentError(jsonFormat);
  return CommentReply(
    id: map['id'] as String,
    author: map['author'] as String,
    body: map['body'] as String,
    createdAt: (map['createdAt'] as num).toInt(),
  );
}

List<SuggestionRecord>? _decodeSuggestions(dynamic raw) {
  if (raw == null) return null;
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  final map = raw as Map<String, dynamic>;
  final out = <SuggestionRecord>[];
  for (final entry in map.entries) {
    final rec = entry.value;
    if (!_isRecord(rec)) throw MalformedDocumentError(jsonFormat);
    final recMap = rec as Map<String, dynamic>;
    final kind = recMap['kind'];
    if (kind is! String || !_suggestionKinds.contains(kind))
      throw MalformedDocumentError(jsonFormat);
    if (recMap['author'] is! String) throw MalformedDocumentError(jsonFormat);
    if (recMap['createdAt'] is! num) throw MalformedDocumentError(jsonFormat);

    out.add(SuggestionRecord(
      id: SuggestionId(entry.key),
      kind: kind,
      author: recMap['author'] as String,
      createdAt: (recMap['createdAt'] as num).toInt(),
      proposedAttrs: recMap['proposedAttrs'] != null
          ? _decodeProposedAttrs(recMap['proposedAttrs'])
          : null,
    ));
  }
  return out;
}

Map<String, dynamic> _decodeProposedAttrs(dynamic raw) {
  if (!_isRecord(raw)) throw MalformedDocumentError(jsonFormat);
  return Map<String, dynamic>.of(raw as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _isRecord(dynamic value) {
  return value is Map<String, dynamic>;
}

List<dynamic> _toNodeArray(dynamic value) {
  if (value == null) return [];
  if (value is! List) throw MalformedDocumentError(jsonFormat);
  return value;
}

List<dynamic> _toItemArray(dynamic value) {
  if (value == null) return [];
  if (value is! List) throw MalformedDocumentError(jsonFormat);
  return value;
}
