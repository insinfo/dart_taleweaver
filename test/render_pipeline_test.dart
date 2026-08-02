import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/render_pipeline.dart';
import 'package:taleweaver/src/core/state/state.dart';

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
}
