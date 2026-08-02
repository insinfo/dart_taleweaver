import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/render_pipeline.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/ops/insert_template_body.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/block_id.dart';

void main() {
  test('render pipeline cascades every node with computed styles', () {
    final state = createEmptyDocument();
    final root = renderCascadedState(state, createDefaultComponentRegistry());
    expect(root.computedStyle, isNotNull);
    final element = root as ElementBox;
    expect(element.children.single.computedStyle, isNotNull);
  });

  test('incremental cascade reuses unchanged cascaded nodes', () {
    final registry = createDefaultComponentRegistry();
    final state = createEmptyDocument();
    final raw = renderState(state, registry).root;
    final cascaded = renderCascadedState(state, registry);
    final next = renderCascadedIncremental(
        state: state,
        registry: registry,
        oldRender: raw,
        oldCascaded: cascaded);
    expect(next.computedStyle, same(cascaded.computedStyle));
  });

  test('cascaded template body stays isolated from the main tree', () {
    var state = createEmptyDocument();
    final root = getBlock(state, state.rootId)!;
    final template = insertTemplateBody(
      state,
      InsertTemplateBodyArgs(region: 'header', sectionBlockId: root.id),
      createTestAllocator('pipeline-template'),
    );
    state = insertText(
      template.state,
      Position(blockId: template.firstParagraphId, offset: 0),
      'Header',
      const {},
    ).state;
    final cascaded = renderCascadedTemplateBody(
      state,
      template.bodyRootId,
      createDefaultComponentRegistry(),
    );
    expect(cascaded.computedStyle, isNotNull);
    expect((cascaded as ElementBox).children, hasLength(1));
  });

  test('incremental pipeline short-circuits empty invalidation', () {
    final registry = createDefaultComponentRegistry();
    final state = createEmptyDocument();
    final raw = renderState(state, registry).root;
    final cascaded = renderCascadedState(state, registry);
    final next = renderCascadedIncremental(
      state: state,
      registry: registry,
      oldRender: raw,
      oldCascaded: cascaded,
      dirtyIds: const {},
    );
    expect(next, same(cascaded));
  });
}
