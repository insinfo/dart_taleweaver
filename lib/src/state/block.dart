/// A single block in the document tree.
///
/// Port of `block.ts`.
library;

import 'attrs.dart';
import 'block_id.dart';
import 'inline_content.dart';

/// A single block in the document tree.
///
/// Container blocks (section, list, table, etc.) hold child blocks via
/// the [firstChildId]/[lastChildId] linked list and have no [inlineContent].
///
/// Leaf blocks (paragraph, list-item, heading, table-cell) carry
/// [inlineContent] and have no children.
///
/// [Block] is a frozen snapshot view produced by `getBlock(state, id)`;
/// mutations go through Layer 3 ops, not by editing this class.
class Block {
  final BlockId id;
  final String type;
  final ReadonlyAttrs attrs;
  final BlockId? parentId;
  final BlockId? prevSiblingId;
  final BlockId? nextSiblingId;
  final BlockId? firstChildId;
  final BlockId? lastChildId;
  final InlineContent? inlineContent;

  const Block({
    required this.id,
    required this.type,
    this.attrs = const {},
    this.parentId,
    this.prevSiblingId,
    this.nextSiblingId,
    this.firstChildId,
    this.lastChildId,
    this.inlineContent,
  });

  /// Whether this block is a container (has children, no inline content).
  bool get isContainer => firstChildId != null;

  /// Whether this block is a leaf (has inline content, no children).
  bool get isLeaf => inlineContent != null;

  /// Create a copy with some fields replaced.
  Block copyWith({
    BlockId? id,
    String? type,
    ReadonlyAttrs? attrs,
    BlockId? Function()? parentId,
    BlockId? Function()? prevSiblingId,
    BlockId? Function()? nextSiblingId,
    BlockId? Function()? firstChildId,
    BlockId? Function()? lastChildId,
    InlineContent? Function()? inlineContent,
  }) {
    return Block(
      id: id ?? this.id,
      type: type ?? this.type,
      attrs: attrs ?? this.attrs,
      parentId: parentId != null ? parentId() : this.parentId,
      prevSiblingId:
          prevSiblingId != null ? prevSiblingId() : this.prevSiblingId,
      nextSiblingId:
          nextSiblingId != null ? nextSiblingId() : this.nextSiblingId,
      firstChildId: firstChildId != null ? firstChildId() : this.firstChildId,
      lastChildId: lastChildId != null ? lastChildId() : this.lastChildId,
      inlineContent:
          inlineContent != null ? inlineContent() : this.inlineContent,
    );
  }

  @override
  String toString() => 'Block($id, type: $type)';
}
