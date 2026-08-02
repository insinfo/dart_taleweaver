import 'package:test/test.dart';
import 'package:taleweaver/src/core/numbering/types.dart';
import 'package:taleweaver/src/core/render/resolve_cross_reference.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/build_document_from_tree.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/list_defs.dart';
import 'package:taleweaver/src/core/state/state.dart';

void main() {
  test('cross-reference page mode resolves a one-based page number', () {
    final state = buildDocumentFromTree(
      const ContainerBlockNode(
        type: 'document',
        children: [
          LeafBlockNode(
            type: 'heading',
            inlineContent: InlineContent([TextItem(text: 'Chapter')]),
          ),
        ],
      ),
      const <String, ListDef>{},
      createTestAllocator('xref'),
    );
    final target = getBlock(state, state.rootId)!.firstChildId!;
    expect(
      resolveCrossReference(
        state,
        const <BlockId, CounterValue>{},
        CrossReferenceProps(targetId: target, refMode: 'page'),
        pageNumbers: {target: 4},
      ),
      '5',
    );
  });

  test('cross-reference page mode reports missing targets', () {
    final state = buildDocumentFromTree(
      const ContainerBlockNode(type: 'document', children: []),
      const <String, ListDef>{},
      createTestAllocator('xref-missing'),
    );
    expect(
      resolveCrossReference(
        state,
        const <BlockId, CounterValue>{},
        const CrossReferenceProps(
            targetId: BlockId('missing'), refMode: 'page'),
        pageNumbers: const {},
      ),
      brokenCrossReferenceText,
    );
  });
}
