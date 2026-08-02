/// Block kind resolution: container vs leaf, known types.
///
/// Port of `block-kinds.ts`.
library;

// ---------------------------------------------------------------------------
// Known block types
// ---------------------------------------------------------------------------

/// Container block types (hold children, no inline content).
const containerBlockTypes = <String>{
  'document',
  'section',
  'table',
  'table-row',
  'table-of-contents',
};

/// Leaf block types (have inline content, no children).
const leafBlockTypes = <String>{
  'paragraph',
  'heading',
  'list-item',
  'table-cell',
  'image',
  'horizontal-line',
  'footnote-body',
  'template-body',
};

// ---------------------------------------------------------------------------
// BlockKindResolver
// ---------------------------------------------------------------------------

/// Determines whether a block type is a container or leaf.
typedef BlockKindResolver = bool Function(String blockType);

/// Returns `true` if [blockType] is a container type (has children).
bool isContainerType(String blockType) {
  return containerBlockTypes.contains(blockType);
}

/// Returns `true` if [blockType] is a leaf type (has inline content).
bool isLeafType(String blockType) {
  return leafBlockTypes.contains(blockType);
}
