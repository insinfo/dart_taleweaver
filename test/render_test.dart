import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/render/render_pipeline.dart';
import 'package:taleweaver/src/core/render/footnote_numbering.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/ops/set_block_type.dart';
import 'package:taleweaver/src/core/state/ops/set_block_attrs.dart';
import 'package:taleweaver/src/core/state/list_defs.dart';
import 'package:taleweaver/src/core/state/ops/set_list_type.dart';
import 'package:taleweaver/src/core/state/ops/insert_footnote.dart';
import 'package:taleweaver/src/core/state/ops/insert_cross_reference.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/ops/insert_page_field.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/styles/length.dart';

void main() {
  test('renderState builds document and paragraph render nodes', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
            state, Position(blockId: paragraph, offset: 0), 'Hello', const {})
        .state;
    final output = renderState(state, createDefaultComponentRegistry());
    expect(output.root, isA<ElementBox>());
    final root = output.root as ElementBox;
    expect(root.children, hasLength(1));
    expect(
        (root.children.single as ElementBox).children.single, isA<TextBox>());
    expect(
        ((root.children.single as ElementBox).children.single as TextBox).text,
        'Hello');
  });

  test('renderState cascades inline text attributes into a styled run', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'Styled',
      const {
        'bold': true,
        'italic': true,
        'underline': true,
        'strikethrough': true,
        'link': 'https://example.test/docs',
        'color': '#8030a0',
        'backgroundColor': '#fff2a8',
        'fontFamily': 'Georgia',
        'fontSize': 18,
      },
    ).state;

    final raw =
        renderState(state, createDefaultComponentRegistry()).root as ElementBox;
    final rawRun =
        (raw.children.single as ElementBox).children.single as TextBox;
    expect(rawRun.link, 'https://example.test/docs');
    expect(rawRun.style.fontWeight?.value, 'bold');
    expect(rawRun.style.fontStyle?.value, 'italic');
    expect(rawRun.style.underline, isTrue);
    expect(rawRun.style.lineThrough, isTrue);
    expect(rawRun.style.color, '#8030a0');
    expect(rawRun.style.backgroundColor, '#fff2a8');
    expect(rawRun.style.fontFamily, 'Georgia');

    final cascaded =
        renderCascadedState(state, createDefaultComponentRegistry())
            as ElementBox;
    final cascadedRun =
        (cascaded.children.single as ElementBox).children.single as TextBox;
    expect(cascadedRun.computedStyle?.fontWeight.value, 'bold');
    expect(cascadedRun.computedStyle?.fontStyle.value, 'italic');
    expect(cascadedRun.computedStyle?.underline, isTrue);
    expect(cascadedRun.computedStyle?.lineThrough, isTrue);
    expect(cascadedRun.computedStyle?.color, '#8030a0');
    expect(cascadedRun.computedStyle?.backgroundColor, '#fff2a8');
    expect(cascadedRun.computedStyle?.fontFamily, 'Georgia');
  });

  test('renderState computes list markers through numbering context', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = setBlockType(
      state,
      paragraph,
      'list-item',
      createDefaultComponentRegistry(),
    ).state;
    state = setBlockAttrs(state, paragraph, {'listId': 'list-1'}).state;
    state = applyOperation(state, (doc) {
      writeListDefInTx(doc, 'list-1', orderedDef);
    }).state;
    final root =
        renderState(state, createDefaultComponentRegistry()).root as ElementBox;
    final item = root.children.single as ElementBox;
    expect(item.style.markerText, '1.');
  });

  test('paragraph-indent attrs propagate through all text leaf components', () {
    final registry = createDefaultComponentRegistry();
    for (final type in ['paragraph', 'heading', 'list-item']) {
      var state = createEmptyDocument();
      final id = getBlock(state, state.rootId)!.firstChildId!;
      if (type != 'paragraph') {
        state = setBlockType(state, id, type, registry).state;
      }
      state = setBlockAttrs(state, id, {
        'marginInlineStart': 36.0,
        'marginInlineEnd': 18.0,
        'textIndent': -12.0,
      }).state;

      final root = renderState(state, registry).root as ElementBox;
      final leaf = root.children.single as ElementBox;
      expect(leaf.style.marginInlineStart, const LengthValue(PxLength(36.0)),
          reason: type);
      expect(leaf.style.marginInlineEnd, const LengthValue(PxLength(18.0)),
          reason: type);
      expect(leaf.style.textIndent, const PxLength(-12.0), reason: type);
    }
  });

  test('footnote numbering follows anchor document order', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final footnote = insertFootnote(
      state,
      Position(blockId: paragraph, offset: 0),
      createTestAllocator('foot'),
    );
    state = freshState(state);
    final index = buildFootnoteNumberIndex(state);
    expect(index, hasLength(1));
    expect(index.values.single, '1');
    expect(index.keys.single, const BlockId('foot-0'));

    state = insertText(
      state,
      Position(blockId: footnote.firstParagraphId, offset: 0),
      'Body',
      const {},
    ).state;
    final body = renderFootnoteBody(
      state,
      footnote.bodyRootId,
      createDefaultComponentRegistry(),
    ).root as ElementBox;
    expect(body.children, hasLength(1));
    expect(
        (body.children.single as ElementBox).children.single, isA<TextBox>());
  });

  test('footnote numbering honors root counter format policy', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    insertFootnote(
      state,
      Position(blockId: paragraph, offset: 0),
      createTestAllocator('policy'),
    );
    state = freshState(state);
    state = setBlockAttrs(state, state.rootId, {
      'footnoteNumberingFormat': 'upper-roman',
    }).state;
    final index = buildFootnoteNumberIndex(state);
    expect(index[const BlockId('policy-0')], 'I');
  });

  test('renderTemplateBody renders templateContents independently', () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final inserted = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      createTestAllocator('template'),
    );
    state = inserted.state;
    state = insertText(
      state,
      Position(blockId: inserted.firstParagraphId, offset: 0),
      'Header',
      const {},
    ).state;
    final output = renderTemplateBody(
      state,
      inserted.bodyRootId,
      createDefaultComponentRegistry(),
    ).root as ElementBox;
    expect(output.children, hasLength(1));
    expect(
        (output.children.single as ElementBox).children.single, isA<TextBox>());
  });

  test('renderTemplateBody resolves page fields for a concrete page', () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final inserted = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      createTestAllocator('template-page-field'),
    );
    state = inserted.state;
    state = insertPageField(
      state,
      Position(blockId: inserted.firstParagraphId, offset: 0),
      'page-number',
      'upper-roman',
    ).state;
    final output = renderTemplateBody(
      state,
      inserted.bodyRootId,
      createDefaultComponentRegistry(),
      pageNumber: 4,
      pageCount: 12,
    ).root as ElementBox;
    final text =
        ((output.children.single as ElementBox).children.single as TextBox);
    expect(text.text, 'IV');
  });

  test('renderState resolves cross-reference embeds into text boxes', () {
    var state = createEmptyDocument();
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'Target',
      const {},
    ).state;
    state = insertCrossReference(
      state,
      Position(blockId: paragraph, offset: 0),
      paragraph,
      'page',
    ).state;

    final root = renderState(
      state,
      createDefaultComponentRegistry(),
      pageNumbers: {paragraph: 2},
    ).root as ElementBox;
    final children = (root.children.single as ElementBox).children;
    expect(children.first, isA<TextBox>());
    expect((children.first as TextBox).text, '3');
  });
}
