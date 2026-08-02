/// Embed-content cascade-delete helpers.
///
/// Port of `embed-content-cascade.ts`.
library;

import 'block.dart';
import 'block_id.dart';
import 'inline_content.dart';
import 'state.dart';

// ---------------------------------------------------------------------------
// Cascade collection
// ---------------------------------------------------------------------------

/// Walk an embed-content subtree rooted at [rootId] and add every visited
/// id to [out]. Follows both child links and nested embed references.
void collectEmbedContentSubtree(State state, BlockId rootId, Set<BlockId> out) {
  if (out.contains(rootId)) return;
  final block = getEmbedContent(state, rootId);
  if (block == null) return;
  out.add(rootId);

  // Children of an embed-content block are themselves embed-content.
  var childId = block.firstChildId;
  while (childId != null) {
    if (out.contains(childId)) break;
    collectEmbedContentSubtree(state, childId, out);
    final child = getEmbedContent(state, childId);
    childId = child?.nextSiblingId;
  }

  // Nested embed-content references.
  if (block.inlineContent != null) {
    collectEmbedContentSubtreeFromInlineContent(state, block.inlineContent!, out);
  }
}

/// Walk an InlineContent for `EmbedItem.properties.contentBlockId`
/// references and collect each referenced embed-content subtree into [out].
void collectEmbedContentSubtreeFromInlineContent(
  State state,
  InlineContent content,
  Set<BlockId> out,
) {
  for (final item in content.items) {
    if (item is EmbedItem) {
      final cbId = item.properties['contentBlockId'];
      if (cbId is String) {
        collectEmbedContentSubtree(state, BlockId(cbId), out);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Dev-mode Assertions
// ---------------------------------------------------------------------------

/// Dev-mode invariant assertion: check that no `contentBlockId` references
/// a missing embed-content root.
void assertNoOrphanedEmbedContent(
  State state,
  String opName, {
  Set<BlockId>? dirtyIds,
}) {
  bool needsFullScan = false;
  if (dirtyIds != null) {
    for (final id in dirtyIds) {
      final main = getBlock(state, id);
      if (main != null) {
        if (main.inlineContent != null) {
          _assertNoOrphansInInlineContent(state, id, main.inlineContent!, opName);
        }
        continue;
      }
      final embed = getEmbedContent(state, id);
      if (embed != null) {
        if (embed.inlineContent != null) {
          _assertNoOrphansInInlineContent(state, id, embed.inlineContent!, opName);
        }
        continue;
      }
      final template = getTemplateContent(state, id);
      if (template != null) {
        if (template.inlineContent != null) {
          _assertNoOrphansInInlineContent(state, id, template.inlineContent!, opName);
        }
        continue;
      }
      needsFullScan = true;
    }
    if (!needsFullScan) return;
  }
  _fullScanForOrphans(state, opName);
}

void _fullScanForOrphans(State state, String opName) {
  _iterateMapForOrphans(state, state.doc.blocks.keys, (id) => getBlock(state, id), opName);
  _iterateMapForOrphans(state, state.doc.embedContents.keys, (id) => getEmbedContent(state, id), opName);
  _iterateMapForOrphans(state, state.doc.templateContents.keys, (id) => getTemplateContent(state, id), opName);
}

void _iterateMapForOrphans(
  State state,
  Iterable<String> keys,
  Block? Function(BlockId) resolve,
  String opName,
) {
  for (final key in keys) {
    final id = BlockId(key);
    final block = resolve(id);
    if (block?.inlineContent != null) {
      _assertNoOrphansInInlineContent(state, id, block!.inlineContent!, opName);
    }
  }
}

void _assertNoOrphansInInlineContent(
  State state,
  BlockId owningBlockId,
  InlineContent content,
  String opName,
) {
  for (final item in content.items) {
    if (item is EmbedItem) {
      final cbId = item.properties['contentBlockId'];
      if (cbId is String) {
        if (getEmbedContent(state, BlockId(cbId)) == null) {
          throw StateError(
            'assertNoOrphanedEmbedContent (op: "$opName"): EmbedItem in block '
            '"$owningBlockId" references missing embedContent root "$cbId"',
          );
        }
      }
    }
  }
}

/// Dev-mode invariant assertion: check that no embedContent root is referenced
/// by more than one anchor.
void assertNoSharedEmbedContent(
  State state,
  String opName, {
  Set<BlockId>? dirtyIds,
}) {
  if (dirtyIds != null && !_anyDirtyBlockHasEmbedRef(state, dirtyIds)) {
    return;
  }
  _fullScanForSharing(state, opName);
}

bool _anyDirtyBlockHasEmbedRef(State state, Set<BlockId> dirtyIds) {
  for (final id in dirtyIds) {
    final block = getBlock(state, id) ?? getEmbedContent(state, id) ?? getTemplateContent(state, id);
    if (block?.inlineContent != null) {
      for (final item in block!.inlineContent!.items) {
        if (item is EmbedItem && item.properties['contentBlockId'] is String) {
          return true;
        }
      }
    }
  }
  return false;
}

void _fullScanForSharing(State state, String opName) {
  final seenRefs = <BlockId, BlockId>{};
  _iterateMapForSharing(state.doc.blocks.keys, (id) => getBlock(state, id), seenRefs, opName);
  _iterateMapForSharing(state.doc.embedContents.keys, (id) => getEmbedContent(state, id), seenRefs, opName);
  _iterateMapForSharing(state.doc.templateContents.keys, (id) => getTemplateContent(state, id), seenRefs, opName);
}

void _iterateMapForSharing(
  Iterable<String> keys,
  Block? Function(BlockId) resolve,
  Map<BlockId, BlockId> seenRefs,
  String opName,
) {
  for (final key in keys) {
    final id = BlockId(key);
    final block = resolve(id);
    if (block?.inlineContent != null) {
      for (final item in block!.inlineContent!.items) {
        if (item is EmbedItem) {
          final cbId = item.properties['contentBlockId'];
          if (cbId is String) {
            final cbBlockId = BlockId(cbId);
            final prevOwner = seenRefs[cbBlockId];
            if (prevOwner != null) {
              throw StateError(
                'assertNoSharedEmbedContent (op: "$opName"): embedContent root '
                '"$cbId" is referenced by multiple anchors ("$prevOwner" and "$id")',
              );
            }
            seenRefs[cbBlockId] = id;
          }
        }
      }
    }
  }
}
