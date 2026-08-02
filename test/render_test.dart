import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/state.dart';

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
}
