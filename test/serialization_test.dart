import 'dart:convert';

import 'package:test/test.dart';
import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/serialize/html_encode.dart';
import 'package:taleweaver/src/core/state/serialize/json_serializer.dart';
import 'package:taleweaver/src/core/state/state.dart';

void main() {
  test('JSON serializer round-trips the empty document and inline text', () {
    final allocator = createTestAllocator();
    var state = createEmptyDocument(allocator: allocator);
    state = insertText(
        state,
        const Position(blockId: BlockId('blk-1'), offset: 0),
        'Hello', const {}).state;
    final serializer = createJsonDocumentSerializer(
      allocator: createTestAllocator('decoded'),
      blockBlockKindResolver: createDefaultComponentRegistry(),
    );
    final encoded = serializer.encode(state);
    final decoded = serializer.decode(encoded);
    final block = getBlock(decoded, const BlockId('blk-1'))!;
    expect(block.inlineContent!.items.single.toString(), contains('Hello'));
    expect(jsonDecode(encoded)['format'], 'taleweaver-json');
  });

  test('HTML encoder escapes text and applies safe marks', () {
    final allocator = createTestAllocator();
    var state = createEmptyDocument(allocator: allocator);
    state = insertText(
        state,
        const Position(blockId: BlockId('blk-1'), offset: 0),
        '<hello>',
        const {'bold': true}).state;
    final html = encodeHtml(state);
    expect(html, contains('&lt;hello&gt;'));
    expect(html, contains('<strong>'));
  });
}
