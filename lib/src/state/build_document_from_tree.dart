/// Build a State from a declarative BlockNode tree.
///
/// Port of `build-document-from-tree.ts`.
library;

import 'attrs.dart';
import 'block_id.dart';
import 'inline_content.dart';
import 'list_defs.dart';
import 'state.dart';
import 'tw_doc.dart';

// ---------------------------------------------------------------------------
// BlockNode Types
// ---------------------------------------------------------------------------

/// A declarative document node.
sealed class BlockNode {
  const BlockNode();
  String get type;
  ReadonlyAttrs get attrs;
}

/// A declarative container node: children, NO inlineContent.
class ContainerBlockNode extends BlockNode {
  @override
  final String type;
  @override
  final ReadonlyAttrs attrs;
  final List<BlockNode> children;

  const ContainerBlockNode({
    required this.type,
    this.attrs = const {},
    required this.children,
  });
}

/// A declarative leaf node: inlineContent, NO children.
class LeafBlockNode extends BlockNode {
  @override
  final String type;
  @override
  final ReadonlyAttrs attrs;
  final InlineContent inlineContent;

  const LeafBlockNode({
    required this.type,
    this.attrs = const {},
    required this.inlineContent,
  });
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/// Lower a declarative [BlockNode] tree to a [State]: a depth-first walk
/// minting a fresh [BlockId] per node (via `allocator`), deriving sibling
/// and parent pointers.
///
/// [listDefs] are populated directly into the state.
State buildDocumentFromTree(
  ContainerBlockNode root,
  Map<String, ListDef> listDefs,
  IdAllocator allocator,
) {
  final rootId = allocator.allocate();
  final doc = TwDoc.create(rootId: rootId);

  // Write list defs.
  for (final entry in listDefs.entries) {
    doc.listDefs[entry.key] = {
      'levels': entry.value.levels
          .map((l) => {
                'style': l.style,
                'start': l.start,
                'restart': l.restart,
              })
          .toList(),
    };
  }

  void build(
    BlockNode node,
    BlockId id,
    BlockId? parentId,
    BlockId? prevSiblingId,
    BlockId? nextSiblingId,
  ) {
    if (node is LeafBlockNode) {
      writeBlock(
        doc,
        id,
        type: node.type,
        attrs: node.attrs,
        parentId: parentId,
        prevSiblingId: prevSiblingId,
        nextSiblingId: nextSiblingId,
        inlineContent: node.inlineContent,
      );
      return;
    }

    final container = node as ContainerBlockNode;
    final childIds =
        List.generate(container.children.length, (_) => allocator.allocate());

    for (var i = 0; i < container.children.length; i++) {
      final child = container.children[i];
      final childId = childIds[i];
      final prevChildId = i > 0 ? childIds[i - 1] : null;
      final nextChildId =
          i < container.children.length - 1 ? childIds[i + 1] : null;

      build(child, childId, id, prevChildId, nextChildId);
    }

    writeBlock(
      doc,
      id,
      type: container.type,
      attrs: container.attrs,
      parentId: parentId,
      prevSiblingId: prevSiblingId,
      nextSiblingId: nextSiblingId,
      firstChildId: childIds.isNotEmpty ? childIds.first : null,
      lastChildId: childIds.isNotEmpty ? childIds.last : null,
    );
  }

  // Build the tree using a transaction to avoid intermediate dirty events.
  doc.transact(() {
    build(root, rootId, null, null, null);
  });

  return createState(rootId: rootId, doc: doc);
}
