import 'package:test/test.dart';
import 'package:taleweaver/src/core/accessibility/accessibility.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/comments.dart';
import 'package:taleweaver/src/core/state/suggestions.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/ops/insert_page_field.dart';
import 'package:taleweaver/src/core/state/ops/insert_cross_reference.dart';
import 'package:taleweaver/src/core/state/ops/set_block_attrs.dart';
import 'package:taleweaver/src/core/state/ops/set_block_type.dart';
import 'package:taleweaver/src/core/state/ops/insert_comment_markers.dart';
import 'package:taleweaver/src/core/state/ops/section_break.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/render/resolve_cross_reference.dart';
import 'package:taleweaver/src/core/state/block_schema.dart';

void main() {
  test('accessibility tree rejects unknown block roles explicitly', () {
    final state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final paragraph = root.firstChildId!;
    updateBlockField(state.doc, paragraph, BlockFields.type, 'mystery-widget');
    expect(() => buildAccessibilityTree(state), throwsStateError);
  });

  test('accessibility tree maps document and heading semantics', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final result = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'Accessible',
      const {},
    );
    state = result.state;
    final tree = buildAccessibilityTree(state);
    expect(tree.role, AccessibilityRole.document);
    expect(tree.children.single.role, AccessibilityRole.paragraph);
    expect(tree.children.single.text!.single.text, 'Accessible');
    expect(tree.children.single.text!.single.sourceOffsetEnd, 10);
  });

  test('accessibility tree flattens transparent section containers', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'section text',
      const {},
    ).state;
    state = applySectionBreak(
      state,
      Position(blockId: paragraph, offset: 6),
      productionAllocator,
    ).result.state;
    final tree = buildAccessibilityTree(state);
    expect(
        tree.children.where((node) => node.role == AccessibilityRole.document),
        isEmpty);
    expect(
        tree.children.where((node) => node.role == AccessibilityRole.paragraph),
        isNotEmpty);
  });

  test('accessibility tree classifies template bodies as banner/contentinfo',
      () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final header = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      productionAllocator,
    );
    state = header.state;
    final footer = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'footer', sectionBlockId: root.id),
      productionAllocator,
    );
    state = footer.state;
    final tree = buildAccessibilityTree(state);
    expect(
        tree.children
            .where((node) => node.sourceBlockId == header.bodyRootId)
            .single
            .role,
        AccessibilityRole.banner);
    expect(
        tree.children
            .where((node) => node.sourceBlockId == footer.bodyRootId)
            .single
            .role,
        AccessibilityRole.contentinfo);
  });

  test('accessibility tree groups contiguous list items into a list role', () {
    var state = createEmptyDocument();
    final first = getBlock(state, state.rootId)!.firstChildId!;
    state = setBlockAttrs(state, first, const {
      'listId': 'main',
      'listType': 'ordered',
    }).state;
    state = setBlockType(
      state,
      first,
      'list-item',
      createDefaultComponentRegistry(),
    ).state;
    final tree = buildAccessibilityTree(state);
    expect(tree.children.single.role, AccessibilityRole.list);
    expect(tree.children.single.listOrdered, isTrue);
    expect(
        tree.children.single.children.single.role, AccessibilityRole.listitem);
    expect(tree.children.single.children.single.listOrdinal, 1);
  });

  test('accessibility runs expose page fields as geometry-free field markers',
      () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertPageField(
      state,
      Position(blockId: paragraph, offset: 0),
      'page-number',
    ).state;
    final run = buildAccessibilityTree(state).children.single.text!.single;
    expect(run.fieldKind, 'page-number');
    expect(run.fieldKey, '${paragraph.value}/inline/0');
    expect(run.sourceOffsetStart, 0);
    expect(run.sourceOffsetEnd, 1);
  });

  test('accessibility runs expose every cross-reference mode', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertCrossReference(
      state,
      Position(blockId: paragraph, offset: 0),
      paragraph,
      'number',
    ).state;
    final run = buildAccessibilityTree(state).children.single.text!.single;
    expect(run.fieldKind, 'cross-ref-number');
    expect(run.fieldKey, '${paragraph.value}/inline/0');
    expect(run.text, brokenCrossReferenceText);
  });

  test('page cross-reference remains a geometry-free field marker', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertCrossReference(
      state,
      Position(blockId: paragraph, offset: 0),
      paragraph,
      'page',
    ).state;
    final run = buildAccessibilityTree(state).children.single.text!.single;
    expect(run.fieldKind, 'cross-ref-page');
    expect(run.text, isEmpty);
  });

  test('accessibility runs retain suggestion and comment identities', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'Suggested',
      const {'insertionSuggestionId': 's-1'},
    ).state;
    state = insertCommentMarkers(
      state,
      Span(
        anchor: Position(blockId: paragraph, offset: 0),
        focus: Position(blockId: paragraph, offset: 9),
      ),
      const CommentId('c-1'),
    ).state;
    final run = buildAccessibilityTree(state).children.single.text!;
    final suggested = run.firstWhere((item) => item.text == 'Suggested');
    expect(suggested.suggestion, 'insertion');
    expect(suggested.suggestionId, 's-1');
    expect(suggested.commentId, 'c-1');
    expect(suggested.inComment, isTrue);
  });

  test('accessibility suggestion views filter invisible literal runs', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'old',
      const {'deletionSuggestionId': 's-del'},
    ).state;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 3),
      'new',
      const {'insertionSuggestionId': 's-ins'},
    ).state;
    final finalRuns = buildAccessibilityTree(
      state,
      suggestionView: SuggestionView.finalView,
    ).children.single.text!;
    final originalRuns = buildAccessibilityTree(
      state,
      suggestionView: SuggestionView.originalView,
    ).children.single.text!;
    expect(finalRuns.map((run) => run.text), ['new']);
    expect(originalRuns.map((run) => run.text), ['old']);
    expect(finalRuns.single.sourceOffsetStart, 3);
    expect(originalRuns.single.sourceOffsetStart, 0);
  });
}
