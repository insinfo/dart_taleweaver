import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/layout/template_layout.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/layout_metadata.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/styles/style.dart';

void main() {
  test('materializes direct template render children as block geometry', () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final template = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      createTestAllocator('template-layout'),
    );
    state = insertText(
      template.state,
      Position(blockId: template.firstParagraphId, offset: 0),
      'Header body',
      const {},
    ).state;
    final rendered = renderTemplateBody(
      state,
      template.bodyRootId,
      createDefaultComponentRegistry(),
    ).root;
    final box = layoutTemplateRenderNode(
      root: rendered,
      shaper: createMockShaper(8, 16),
      inlineSize: 160,
      fallbackStyle: initialComputedStyle,
    );
    expect(box.children, hasLength(1));
    expect(box.children.single, isA<BlockBox>());
    expect((box.children.single as BlockBox).blockSize, greaterThan(0));
  });

  test('materializes inline image metadata inside a template slot', () {
    final rendered = ElementBox(
      key: 'header',
      style: const Style(),
      children: [
        const ElementBox(
          key: 'header/inline/0',
          style: Style(),
          metadata: LayoutBoxMetadata(
              embedType: 'inline-image',
              image: ImageMetadata(
                  src: 'https://example.test/a.png', width: 24, height: 12)),
          children: [],
        ),
      ],
    );
    final box = layoutTemplateRenderNode(
      root: rendered,
      shaper: createMockShaper(8, 16),
      inlineSize: 160,
      fallbackStyle: initialComputedStyle,
    );
    expect(box.children.single, isA<ImageBox>());
    expect((box.children.single as ImageBox).src, 'https://example.test/a.png');
  });

  test('floats an image and narrows following text flow', () {
    final rendered = ElementBox(
      key: 'header',
      style: const Style(),
      children: [
        const ElementBox(
          key: 'header/float',
          style: Style(float: Float.inlineStart),
          metadata: LayoutBoxMetadata(
              embedType: 'inline-image',
              image: ImageMetadata(src: 'float.png', width: 40, height: 12)),
          children: [],
        ),
        ElementBox(
          key: 'header/text',
          style: const Style(),
          children: [createTextBox('header/text/0', const Style(), 'Hello')],
        ),
      ],
    );
    final box = layoutTemplateRenderNode(
        root: rendered,
        shaper: createMockShaper(8, 16),
        inlineSize: 120,
        fallbackStyle: initialComputedStyle);
    final image = box.children[0] as ImageBox;
    final text = box.children[1] as BlockBox;
    expect(image.x, 0);
    expect(text.x, 40);
    expect(text.inlineSize, 80);
    expect(text.y, 0);
    expect((text.children.single as LineBox).x, 40);
  });

  test('clear moves following flow below a float', () {
    final rendered = ElementBox(
      key: 'header',
      style: const Style(),
      children: [
        const ElementBox(
          key: 'header/float',
          style: Style(float: Float.inlineStart),
          metadata: LayoutBoxMetadata(
              image: ImageMetadata(src: 'float.png', width: 40, height: 30)),
          children: [],
        ),
        ElementBox(
          key: 'header/clear',
          style: const Style(clear: Clear.inlineStart),
          children: [createTextBox('header/clear/0', const Style(), 'Clear')],
        ),
      ],
    );
    final box = layoutTemplateRenderNode(
        root: rendered,
        shaper: createMockShaper(8, 16),
        inlineSize: 120,
        fallbackStyle: initialComputedStyle);
    expect((box.children[1] as BlockBox).y, 30);
  });

  test('preserves nested element boundaries as hard line breaks', () {
    final rendered = ElementBox(
      key: 'header',
      style: const Style(),
      children: [
        ElementBox(key: 'header/container', style: const Style(), children: [
          ElementBox(
              key: 'header/p1',
              style: const Style(),
              children: [createTextBox('header/p1/0', const Style(), 'One')]),
          ElementBox(
              key: 'header/p2',
              style: const Style(),
              children: [createTextBox('header/p2/0', const Style(), 'Two')]),
        ]),
      ],
    );
    final box = layoutTemplateRenderNode(
      root: rendered,
      shaper: createMockShaper(8, 16),
      inlineSize: 160,
      fallbackStyle: initialComputedStyle,
    );
    expect((box.children.single as BlockBox).children, hasLength(2));
  });

  test('materializes table rows and cells in template slots', () {
    final cell = (String key, String text) => ElementBox(
          key: key,
          style: const Style(display: Display.tableCell),
          children: [createTextBox('$key/0', const Style(), text)],
        );
    final rendered = ElementBox(
      key: 'table',
      style: const Style(display: Display.table),
      metadata: const LayoutBoxMetadata(columnWidths: [60, 60]),
      children: [
        ElementBox(
          key: 'row-0',
          style: const Style(display: Display.tableRow),
          children: [cell('cell-0', 'A'), cell('cell-1', 'B')],
        ),
      ],
    );
    final box = layoutTemplateRenderNode(
      root:
          ElementBox(key: 'header', style: const Style(), children: [rendered]),
      shaper: createMockShaper(8, 16),
      inlineSize: 120,
      fallbackStyle: initialComputedStyle,
    );
    expect(box.children.single, isA<TableBox>());
    expect((box.children.single as TableBox).children, hasLength(1));
    expect(
        (box.children.single as TableBox).children.single, isA<TableRowBox>());
  });
}
