/// Geometry-free accessibility projection of the document model.
library;

import '../state/block.dart';
import '../state/block_id.dart';
import '../state/comments.dart';
import '../state/inline_content.dart';
import '../state/ops/insert_cross_reference.dart';
import '../state/ops/insert_footnote.dart';
import '../state/page_field.dart';
import '../state/state.dart';
import '../state/list_defs.dart';
import '../state/block_traversal.dart';
import '../state/suggestions.dart';
import '../numbering/compute_counters.dart';
import '../numbering/list_collector.dart';
import '../numbering/types.dart';
import '../render/resolve_cross_reference.dart';

enum AccessibilityRole {
  document,
  paragraph,
  heading,
  list,
  listitem,
  table,
  row,
  cell,
  columnheader,
  image,
  separator,
  navigation,
  banner,
  contentinfo,
  footnote,
}

class AccessibilityTextRun {
  final String text;
  final int sourceOffsetStart;
  final int sourceOffsetEnd;
  final List<String>? emphasis;
  final String? link;
  final BlockId? noteref;
  final String? imageAlt;
  final String? fieldKind;
  final String? fieldKey;
  final String? suggestion;
  final String? suggestionId;
  final String? commentId;
  final bool inComment;

  const AccessibilityTextRun({
    required this.text,
    required this.sourceOffsetStart,
    required this.sourceOffsetEnd,
    this.emphasis,
    this.link,
    this.noteref,
    this.imageAlt,
    this.fieldKind,
    this.fieldKey,
    this.suggestion,
    this.suggestionId,
    this.commentId,
    this.inComment = false,
  });
}

class AccessibilityNode {
  final AccessibilityRole role;
  final BlockId? sourceBlockId;
  final String? name;
  final int? level;
  final bool? listOrdered;
  final int? listOrdinal;
  final List<AccessibilityTextRun>? text;
  final List<AccessibilityNode> children;

  const AccessibilityNode({
    required this.role,
    required this.sourceBlockId,
    required this.children,
    this.name,
    this.level,
    this.listOrdered,
    this.listOrdinal,
    this.text,
  });
}

AccessibilityNode buildAccessibilityTree(State state,
    {SuggestionView suggestionView = SuggestionView.suggesting}) {
  final root = getBlock(state, state.rootId);
  if (root == null) {
    throw StateError('Accessibility root ${state.rootId} does not exist');
  }
  final counters =
      computeCounters(collectListEvents(state), getListDefsForState(state));
  final main = _build(state, root, _mainResolve, counters, suggestionView);
  final bodyNodes = <AccessibilityNode>[];
  for (final id in getEmbedContentIds(state)) {
    final body = getEmbedContent(state, id);
    if (body != null) {
      bodyNodes
          .add(_build(state, body, _embedResolve, counters, suggestionView));
    }
  }
  for (final id in getTemplateContentIds(state)) {
    final body = getTemplateContent(state, id);
    if (body != null) {
      bodyNodes
          .add(_build(state, body, _templateResolve, counters, suggestionView));
    }
  }
  if (bodyNodes.isEmpty) return main;
  return AccessibilityNode(
    role: main.role,
    sourceBlockId: main.sourceBlockId,
    name: main.name,
    level: main.level,
    listOrdered: main.listOrdered,
    listOrdinal: main.listOrdinal,
    text: main.text,
    children: [...main.children, ...bodyNodes],
  );
}

Block? _mainResolve(State state, BlockId id) => getBlock(state, id);
Block? _embedResolve(State state, BlockId id) => getEmbedContent(state, id);
Block? _templateResolve(State state, BlockId id) =>
    getTemplateContent(state, id);

AccessibilityNode _build(
    State state,
    Block block,
    Block? Function(State, BlockId) resolve,
    Map<BlockId, CounterValue> counters,
    SuggestionView suggestionView) {
  final children = _children(state, block, resolve, counters, suggestionView);
  switch (block.type) {
    case 'document':
      return AccessibilityNode(
          role: AccessibilityRole.document,
          sourceBlockId: block.id,
          children: children);
    case 'section':
      throw StateError(
          'buildAccessibilityTree: section "${block.id}" must be flattened by its parent');
    case 'paragraph':
      return AccessibilityNode(
          role: AccessibilityRole.paragraph,
          sourceBlockId: block.id,
          text: _runs(state, block, counters, suggestionView),
          children: const []);
    case 'heading':
      final raw = block.attrs['level'];
      final level = raw is int && raw >= 1 && raw <= 6 ? raw : 1;
      return AccessibilityNode(
          role: AccessibilityRole.heading,
          sourceBlockId: block.id,
          level: level,
          text: _runs(state, block, counters, suggestionView),
          children: const []);
    case 'list-item':
      return AccessibilityNode(
          role: AccessibilityRole.listitem,
          sourceBlockId: block.id,
          text: _runs(state, block, counters, suggestionView),
          listOrdinal: counters[block.id]?.value,
          children: children);
    case 'table':
      return AccessibilityNode(
          role: AccessibilityRole.table,
          sourceBlockId: block.id,
          children: children);
    case 'table-row':
      return AccessibilityNode(
          role: AccessibilityRole.row,
          sourceBlockId: block.id,
          children: children);
    case 'table-cell':
      final header =
          block.attrs['header'] == true || block.attrs['isHeader'] == true;
      return AccessibilityNode(
          role:
              header ? AccessibilityRole.columnheader : AccessibilityRole.cell,
          sourceBlockId: block.id,
          text: _runs(state, block, counters, suggestionView),
          children: children);
    case 'image':
      return AccessibilityNode(
          role: AccessibilityRole.image,
          sourceBlockId: block.id,
          name:
              block.attrs['alt'] is String ? block.attrs['alt'] as String : '',
          children: const []);
    case 'horizontal-line':
      return AccessibilityNode(
          role: AccessibilityRole.separator,
          sourceBlockId: block.id,
          children: const []);
    case 'table-of-contents':
      return AccessibilityNode(
          role: AccessibilityRole.navigation,
          sourceBlockId: block.id,
          name: 'Table of contents',
          children: const []);
    case 'footnote-body':
      return AccessibilityNode(
          role: AccessibilityRole.footnote,
          sourceBlockId: block.id,
          children: children);
    case 'template-body':
      return AccessibilityNode(
          role: _templateRole(state, block.id),
          sourceBlockId: block.id,
          children: children);
    default:
      throw StateError(
          'buildAccessibilityTree: no accessibility role mapped for block type "${block.type}"');
  }
}

AccessibilityRole _templateRole(State state, BlockId bodyId) {
  for (final block in iterateBlocksInDocumentOrder(state)) {
    if (block.attrs['headerBlockId'] == bodyId.value) {
      return AccessibilityRole.banner;
    }
    if (block.attrs['footerBlockId'] == bodyId.value) {
      return AccessibilityRole.contentinfo;
    }
  }
  return AccessibilityRole.banner;
}

List<AccessibilityNode> _children(
    State state,
    Block block,
    Block? Function(State, BlockId) resolve,
    Map<BlockId, CounterValue> counters,
    SuggestionView suggestionView) {
  final result = <AccessibilityNode>[];
  var id = block.firstChildId;
  while (id != null) {
    final child = resolve(state, id);
    if (child == null) break;
    if (child.type == 'section') {
      // Sections are display:contents/accessibility-transparent in the
      // TypeScript reference. Build their children independently so list
      // grouping does not merge across a section boundary, then splice the
      // resulting nodes into the parent output.
      result.addAll(_children(state, child, resolve, counters, suggestionView));
      id = child.nextSiblingId;
      continue;
    }
    if (child.type == 'list-item') {
      final listItems = <AccessibilityNode>[];
      final listId = child.attrs['listId'];
      var cursor = child;
      BlockId? afterListId;
      while (cursor.type == 'list-item' && cursor.attrs['listId'] == listId) {
        listItems.add(_build(state, cursor, resolve, counters, suggestionView));
        final next = cursor.nextSiblingId;
        if (next == null) {
          afterListId = null;
          break;
        }
        final nextBlock = resolve(state, next);
        if (nextBlock == null) {
          afterListId = next;
          break;
        }
        if (nextBlock.type != 'list-item' ||
            nextBlock.attrs['listId'] != listId) {
          afterListId = next;
          break;
        }
        cursor = nextBlock;
      }
      final listType = child.attrs['listType'];
      result.add(AccessibilityNode(
          role: AccessibilityRole.list,
          sourceBlockId: child.parentId,
          listOrdered: listType == 'ordered' || listType == 'numbered',
          children: listItems));
      id = afterListId;
      continue;
    }
    result.add(_build(state, child, resolve, counters, suggestionView));
    id = child.nextSiblingId;
  }
  return result;
}

List<AccessibilityTextRun> _runs(State state, Block block,
    Map<BlockId, CounterValue> counters, SuggestionView suggestionView) {
  final content = block.inlineContent;
  if (content == null) return const [];
  final runs = <AccessibilityTextRun>[];
  var offset = 0;
  var commentDepth = 0;
  String? activeCommentId;
  final commentStack = <String?>[];
  for (var index = 0; index < content.items.length; index++) {
    final item = content.items[index];
    final length = item is TextItem ? item.text.length : 1;
    if (!itemVisibleInView(item, suggestionView)) {
      offset += length;
      continue;
    }
    if (item is EmbedItem && item.embedType == commentStartEmbedType) {
      commentStack.add(activeCommentId);
      commentDepth++;
      final raw = item.properties['commentId'];
      if (raw is String) activeCommentId = raw;
      offset++;
      continue;
    }
    if (item is EmbedItem && item.embedType == commentEndEmbedType) {
      commentDepth = commentDepth > 0 ? commentDepth - 1 : 0;
      activeCommentId =
          commentStack.isNotEmpty ? commentStack.removeLast() : null;
      offset++;
      continue;
    }
    if (item is TextItem) {
      final emphasis = <String>[];
      for (final key in const [
        'bold',
        'italic',
        'underline',
        'strikethrough'
      ]) {
        if (item.attrs[key] == true) emphasis.add(key);
      }
      runs.add(AccessibilityTextRun(
          text: item.text,
          sourceOffsetStart: offset,
          sourceOffsetEnd: offset + length,
          emphasis: emphasis.isEmpty ? null : emphasis,
          link: item.attrs['link'] is String
              ? item.attrs['link'] as String
              : null,
          suggestion: item.attrs['insertionSuggestionId'] is String
              ? 'insertion'
              : item.attrs['deletionSuggestionId'] is String
                  ? 'deletion'
                  : null,
          suggestionId: item.attrs['insertionSuggestionId'] is String
              ? item.attrs['insertionSuggestionId'] as String
              : item.attrs['deletionSuggestionId'] is String
                  ? item.attrs['deletionSuggestionId'] as String
                  : null,
          commentId: activeCommentId,
          inComment: commentDepth > 0));
    } else if (item is EmbedItem && item.embedType == footnoteAnchorEmbedType) {
      final raw = item.properties['contentBlockId'];
      runs.add(AccessibilityTextRun(
          text: '',
          sourceOffsetStart: offset,
          sourceOffsetEnd: offset + 1,
          noteref: raw is String ? BlockId(raw) : null,
          commentId: activeCommentId,
          inComment: commentDepth > 0));
    } else if (item is EmbedItem && item.embedType == inlineImageEmbedType) {
      final alt = item.properties['alt'];
      runs.add(AccessibilityTextRun(
          text: '',
          sourceOffsetStart: offset,
          sourceOffsetEnd: offset + 1,
          imageAlt: alt is String ? alt : '',
          commentId: activeCommentId,
          inComment: commentDepth > 0));
    } else if (item is EmbedItem && item.embedType == pageFieldEmbedType) {
      final kind = item.properties['fieldKind'];
      runs.add(AccessibilityTextRun(
          text: '',
          sourceOffsetStart: offset,
          sourceOffsetEnd: offset + 1,
          fieldKind: kind is String ? kind : null,
          fieldKey: '${block.id.value}/inline/$index',
          commentId: activeCommentId,
          inComment: commentDepth > 0));
    } else if (item is EmbedItem && item.embedType == crossReferenceEmbedType) {
      final mode = item.properties['refMode'];
      final target = item.properties['targetId'];
      final resolved = mode is String && mode != 'page' && target is String
          ? resolveCrossReference(
              state,
              counters,
              CrossReferenceProps(
                targetId: BlockId(target),
                refMode: mode,
              ),
              view: suggestionView,
            )
          : '';
      runs.add(AccessibilityTextRun(
          text: resolved,
          sourceOffsetStart: offset,
          sourceOffsetEnd: offset + 1,
          fieldKind: mode is String ? 'cross-ref-$mode' : 'cross-ref',
          fieldKey: '${block.id.value}/inline/$index',
          commentId: activeCommentId,
          inComment: commentDepth > 0));
    }
    offset += length;
  }
  return runs;
}
