/// Block schema — field specs for reading/writing blocks to TwDoc.
///
/// Port of `block-schema.ts`.
library;

/// The field keys stored in a block's map entry within TwDoc.
abstract final class BlockFields {
  static const String type = 'type';
  static const String attrs = 'attrs';
  static const String parentId = 'parentId';
  static const String prevSiblingId = 'prevSiblingId';
  static const String nextSiblingId = 'nextSiblingId';
  static const String firstChildId = 'firstChildId';
  static const String lastChildId = 'lastChildId';
  static const String inlineContent = 'inlineContent';
}
