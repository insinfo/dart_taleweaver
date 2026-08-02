import 'package:test/test.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_schema.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/tw_doc.dart';

void main() {
  test('applyOperation captures direct tree-map mutations', () {
    final allocator = createTestAllocator();
    final state = createEmptyDocument(allocator: allocator);
    final paragraph = getBlock(state, BlockId('blk-1'))!;

    final result = applyOperation(state, (doc) {
      doc.getBlockMap(paragraph.id.value)![BlockFields.attrs] = {
        'textAlign': 'center',
      };
    });

    expect(result.dirtyIds, contains(paragraph.id));
    expect(result.state, isNot(same(state)));
    expect(getBlock(result.state, paragraph.id)!.attrs['textAlign'], 'center');
  });

  test('applyOperation tracks inserted and deleted block ids', () {
    final doc = TwDoc.create(rootId: BlockId('root'));
    final state = createState(rootId: BlockId('root'), doc: doc);

    final inserted = applyOperation(state, (current) {
      current.setBlockMap('child', {
        BlockFields.type: 'paragraph',
        BlockFields.attrs: <String, dynamic>{},
        BlockFields.inlineContent: InlineContent.empty,
      });
    });
    expect(inserted.dirtyIds, contains(BlockId('child')));

    final deleted = applyOperation(inserted.state, (current) {
      current.deleteBlock('child');
    });
    expect(deleted.dirtyIds, contains(BlockId('child')));
    expect(getBlock(deleted.state, BlockId('child')), isNull);
  });

  test('snapshot tables are deep copies of inline attrs and properties', () {
    final doc = TwDoc();
    final attrs = <String, dynamic>{
      'link': <String, dynamic>{'url': '/a'}
    };
    doc.blocks['b'] = {
      BlockFields.type: 'paragraph',
      BlockFields.inlineContent: InlineContent([
        EmbedItem(
          embedType: 'mention',
          attrs: attrs,
          properties: <String, dynamic>{
            'data': <String>['one']
          },
        ),
      ]),
    };

    final snapshot = doc.snapshotBlocks();
    attrs['link']!['url'] = '/changed';
    final properties =
        (doc.blocks['b']![BlockFields.inlineContent] as InlineContent)
            .items
            .single as EmbedItem;
    (properties.properties['data'] as List<String>)[0] = 'changed';

    final item = (snapshot['b']![BlockFields.inlineContent] as InlineContent)
        .items
        .single as EmbedItem;
    expect(item.attrs['link']['url'], '/a');
    expect(item.properties['data'], ['one']);
  });

  test('no-op transactions preserve the State identity', () {
    final state = createEmptyDocument(allocator: createTestAllocator());
    final result = applyOperation(state, (_) {});

    expect(result.dirtyIds, isEmpty);
    expect(result.state, same(state));
  });
}
