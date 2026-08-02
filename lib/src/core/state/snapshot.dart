/// Snapshot cache — reads blocks from TwDoc and caches frozen Block instances.
///
/// Port of `snapshot.ts`.
library;

import 'attrs.dart';
import 'block.dart';
import 'block_id.dart';
import 'block_schema.dart';
import 'inline_content.dart';
import 'tw_doc.dart';

// ---------------------------------------------------------------------------
// SnapshotCache
// ---------------------------------------------------------------------------

/// Cache of frozen [Block] snapshots read from a [TwDoc].
///
/// Subsequent reads with no intervening mutation return the same reference.
class SnapshotCache {
  final Map<String, Block?> _blockCache = {};
  final Map<String, Block?> _embedCache = {};
  final Map<String, Block?> _templateCache = {};

  /// Invalidate all cached entries. Called when the doc mutates.
  void invalidateAll() {
    _blockCache.clear();
    _embedCache.clear();
    _templateCache.clear();
  }

  /// Invalidate specific block IDs.
  void invalidate(Set<String> dirtyIds) {
    for (final id in dirtyIds) {
      _blockCache.remove(id);
      _embedCache.remove(id);
      _templateCache.remove(id);
    }
  }
}

// ---------------------------------------------------------------------------
// Snapshot readers
// ---------------------------------------------------------------------------

/// Read a frozen [Block] snapshot from the main tree by id.
///
/// Returns null for unknown ids. Subsequent reads with no intervening
/// mutation return the same reference (cache hit).
Block? getBlockSnapshot(TwDoc doc, BlockId id, SnapshotCache cache) {
  if (cache._blockCache.containsKey(id.value)) {
    return cache._blockCache[id.value];
  }
  final map = doc.getBlockMap(id.value);
  if (map == null) {
    cache._blockCache[id.value] = null;
    return null;
  }
  final block = _mapToBlock(id, map);
  cache._blockCache[id.value] = block;
  return block;
}

/// Read a frozen [Block] snapshot from the embed-contents tree.
Block? getEmbedContentSnapshot(TwDoc doc, BlockId id, SnapshotCache cache) {
  if (cache._embedCache.containsKey(id.value)) {
    return cache._embedCache[id.value];
  }
  final map = doc.getEmbedContentMap(id.value);
  if (map == null) {
    cache._embedCache[id.value] = null;
    return null;
  }
  final block = _mapToBlock(id, map);
  cache._embedCache[id.value] = block;
  return block;
}

/// Read a frozen [Block] snapshot from the template-contents tree.
Block? getTemplateContentSnapshot(TwDoc doc, BlockId id, SnapshotCache cache) {
  if (cache._templateCache.containsKey(id.value)) {
    return cache._templateCache[id.value];
  }
  final map = doc.getTemplateContentMap(id.value);
  if (map == null) {
    cache._templateCache[id.value] = null;
    return null;
  }
  final block = _mapToBlock(id, map);
  cache._templateCache[id.value] = block;
  return block;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Convert a raw field map to a [Block] instance.
Block _mapToBlock(BlockId id, Map<String, dynamic> map) {
  return Block(
    id: id,
    type: map[BlockFields.type] as String? ?? 'paragraph',
    attrs: _readAttrs(map[BlockFields.attrs]),
    parentId: _readBlockId(map[BlockFields.parentId]),
    prevSiblingId: _readBlockId(map[BlockFields.prevSiblingId]),
    nextSiblingId: _readBlockId(map[BlockFields.nextSiblingId]),
    firstChildId: _readBlockId(map[BlockFields.firstChildId]),
    lastChildId: _readBlockId(map[BlockFields.lastChildId]),
    inlineContent: _readInlineContent(map[BlockFields.inlineContent]),
  );
}

ReadonlyAttrs _readAttrs(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

BlockId? _readBlockId(dynamic raw) {
  if (raw is String) return BlockId(raw);
  return null;
}

InlineContent? _readInlineContent(dynamic raw) {
  if (raw == null) return null;
  if (raw is InlineContent) return raw;
  if (raw is List) {
    final items = <InlineItem>[];
    for (final itemRaw in raw) {
      if (itemRaw is InlineItem) {
        items.add(itemRaw);
      } else if (itemRaw is Map) {
        final kind = itemRaw['kind'] as String?;
        if (kind == 'text') {
          items.add(TextItem(
            text: itemRaw['text'] as String? ?? '',
            attrs: _readAttrs(itemRaw['attrs']),
          ));
        } else if (kind == 'embed') {
          items.add(EmbedItem(
            embedType: itemRaw['embedType'] as String? ?? '',
            attrs: _readAttrs(itemRaw['attrs']),
            properties: itemRaw['properties'] is Map
                ? Map<String, dynamic>.from(itemRaw['properties'] as Map)
                : const {},
          ));
        }
      }
    }
    return InlineContent(items);
  }
  return null;
}
