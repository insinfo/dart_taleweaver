/// Build a State by writing whole-document fixtures directly into the TwDoc.
///
/// Port of `build-state-from-blocks.ts`.
library;

import 'block.dart';
import 'block_id.dart';
import 'comments.dart';
import 'list_defs.dart';
import 'state.dart';
import 'suggestions.dart';
import 'tw_doc.dart';
import 'block_schema.dart';

class BuildStateFromBlocksArgs {
  final BlockId rootId;
  final List<Block> blocks;
  final List<Block>? embedContents;
  final List<Block>? templateContents;
  final Map<String, ListDef>? listDefs;
  final List<CommentRecord>? comments;
  final List<SuggestionRecord>? suggestions;

  const BuildStateFromBlocksArgs({
    required this.rootId,
    required this.blocks,
    this.embedContents,
    this.templateContents,
    this.listDefs,
    this.comments,
    this.suggestions,
  });
}

/// Build a `State` by writing whole-document fixtures directly into the
/// underlying `TwDoc`, id-PRESERVING.
State buildStateFromBlocks(BuildStateFromBlocksArgs args) {
  final doc = TwDoc.create(rootId: args.rootId);
  
  doc.transact(() {
    for (final block in args.blocks) {
      doc.setBlockMap(block.id.value, {
        BlockFields.type: block.type,
        BlockFields.attrs: Map<String, dynamic>.of(block.attrs),
        if (block.parentId != null) BlockFields.parentId: block.parentId!.value,
        if (block.prevSiblingId != null) BlockFields.prevSiblingId: block.prevSiblingId!.value,
        if (block.nextSiblingId != null) BlockFields.nextSiblingId: block.nextSiblingId!.value,
        if (block.firstChildId != null) BlockFields.firstChildId: block.firstChildId!.value,
        if (block.lastChildId != null) BlockFields.lastChildId: block.lastChildId!.value,
        if (block.inlineContent != null) BlockFields.inlineContent: block.inlineContent!,
      });
    }

    if (args.embedContents != null) {
      for (final block in args.embedContents!) {
        doc.setEmbedContentMap(block.id.value, {
          BlockFields.type: block.type,
          BlockFields.attrs: Map<String, dynamic>.of(block.attrs),
          if (block.parentId != null) BlockFields.parentId: block.parentId!.value,
          if (block.prevSiblingId != null) BlockFields.prevSiblingId: block.prevSiblingId!.value,
          if (block.nextSiblingId != null) BlockFields.nextSiblingId: block.nextSiblingId!.value,
          if (block.firstChildId != null) BlockFields.firstChildId: block.firstChildId!.value,
          if (block.lastChildId != null) BlockFields.lastChildId: block.lastChildId!.value,
          if (block.inlineContent != null) BlockFields.inlineContent: block.inlineContent!,
        });
      }
    }

    if (args.templateContents != null) {
      for (final block in args.templateContents!) {
        doc.setTemplateContentMap(block.id.value, {
          BlockFields.type: block.type,
          BlockFields.attrs: Map<String, dynamic>.of(block.attrs),
          if (block.parentId != null) BlockFields.parentId: block.parentId!.value,
          if (block.prevSiblingId != null) BlockFields.prevSiblingId: block.prevSiblingId!.value,
          if (block.nextSiblingId != null) BlockFields.nextSiblingId: block.nextSiblingId!.value,
          if (block.firstChildId != null) BlockFields.firstChildId: block.firstChildId!.value,
          if (block.lastChildId != null) BlockFields.lastChildId: block.lastChildId!.value,
          if (block.inlineContent != null) BlockFields.inlineContent: block.inlineContent!,
        });
      }
    }

    if (args.listDefs != null) {
      for (final entry in args.listDefs!.entries) {
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
    }

    if (args.comments != null) {
      for (final record in args.comments!) {
        doc.comments[record.id] = {
          'author': record.author,
          'body': record.body,
          'createdAt': record.createdAt,
          'replies': record.replies
              .map((r) => {
                    'id': r.id,
                    'author': r.author,
                    'body': r.body,
                    'createdAt': r.createdAt,
                  })
              .toList(),
          'resolved': record.resolved,
        };
      }
    }

    if (args.suggestions != null) {
      for (final record in args.suggestions!) {
        doc.suggestions[record.id.value] = {
          'kind': record.kind,
          'author': record.author,
          'createdAt': record.createdAt,
          if (record.proposedAttrs != null)
            'proposedAttrs': Map<String, dynamic>.of(record.proposedAttrs!),
        };
      }
    }
  });
  
  return createState(rootId: args.rootId, doc: doc);
}
