import 'package:test/test.dart';
import 'package:taleweaver/src/core/state/block.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/block_traversal.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/ops/create_table.dart';
import 'package:taleweaver/src/core/state/ops/insert_items.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/serialize/docx_serializer.dart';
import 'package:taleweaver/src/core/state/state.dart';

void main() {
  test('DOCX preserves text, inline formatting and page setup', () {
    var state = createEmptyDocument(allocator: createTestAllocator('docx'));
    final id = getBlock(state, state.rootId)!.firstChildId!;
    state = insertText(state, Position(blockId: id, offset: 0), 'DOCX ',
        const {'bold': true}).state;
    state = insertText(state, Position(blockId: id, offset: 5), 'nativo',
        const {'italic': true, 'fontSize': 18.0}).state;

    final bytes = encodeDocx(state);
    final result = decodeDocxWithReport(
      bytes,
      allocator: createTestAllocator('docx-decoded'),
    );
    final block = getBlock(result.state, result.state.rootId)!.firstChildId;
    final paragraph = getBlock(result.state, block!)!;
    final runs = paragraph.inlineContent!.items.whereType<TextItem>().toList();
    expect(bytes, isNotEmpty);
    expect(runs.map((run) => run.text).join(), 'DOCX nativo');
    expect(runs.first.attrs['bold'], isTrue);
    expect(runs.last.attrs['italic'], isTrue);
    expect(runs.last.attrs['fontSize'], 18.0);
    expect(result.report.importedParagraphs, 1);
  });

  test('DOCX preserves a simple table tree', () {
    var state =
        createEmptyDocument(allocator: createTestAllocator('docx-table'));
    final root = getBlock(state, state.rootId)!;
    final paragraph = getBlock(state, root.firstChildId!)!;
    final table = createTable(
      state,
      Position(blockId: paragraph.id, offset: 0),
      2,
      2,
      createTestAllocator('docx-table-tree'),
    );
    state = table.result.state;

    final result = decodeDocxWithReport(
      encodeDocx(state),
      allocator: createTestAllocator('docx-table-decoded'),
    );
    expect(result.report.importedTables, 1);
    expect(
      _blocks(result.state).where((block) => block.type == 'table').length,
      1,
    );
    expect(
      _blocks(result.state).where((block) => block.type == 'table-cell').length,
      4,
    );
    expect(root.type, 'document');
  });

  test('DOCX preserves hard line breaks as inline embeds', () {
    var state =
        createEmptyDocument(allocator: createTestAllocator('docx-break'));
    final paragraph = getBlock(state, state.rootId)!.firstChildId!;
    final block = getBlock(state, paragraph)!;
    final plan = planInsertItemsSplitInPlace(
      paragraph,
      ResolvedBlockKind.main,
      block.inlineContent!.items,
      0,
      const [
        TextItem(text: 'before'),
        EmbedItem(embedType: hardBreakEmbedType),
        TextItem(text: 'after'),
      ],
    );
    state = applyOperation(state, (doc) => insertItemsInTx(doc, plan)).state;

    final decoded = decodeDocx(
      encodeDocx(state),
      allocator: createTestAllocator('docx-break-decoded'),
    );
    final items = getBlock(
      decoded,
      getBlock(decoded, decoded.rootId)!.firstChildId!,
    )!
        .inlineContent!
        .items;
    expect(items.whereType<EmbedItem>().map((item) => item.embedType),
        contains(hardBreakEmbedType));
    expect(items.whereType<TextItem>().map((item) => item.text).join(),
        'beforeafter');
  });
}

Iterable<Block> _blocks(State state) sync* {
  yield* iterateBlocksInDocumentOrder(state);
}
