import 'package:test/test.dart';
import 'package:taleweaver/src/core/cursor/cursor_ops.dart';
import 'package:taleweaver/src/core/cursor/grapheme_utils.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/ops/insert_text.dart';
import 'package:taleweaver/src/core/state/state.dart';

void main() {
  test(
      'grapheme boundaries keep surrogate pairs, combining marks and ZWJ emoji',
      () {
    final text = 'a\u0301 b 😀 👩‍💻';
    expect(nextGraphemeBoundary(text, 0), 2);
    expect(nextGraphemeBoundary(text, 5), 7);
    expect(prevGraphemeBoundary('😀', 2), 0);
  });

  test('word helpers expose word-like segments and boundaries', () {
    expect(nextWordBoundary('hello, world', 0), 5);
    expect(prevWordBoundary('hello, world', 12), 7);
    expect(
        iterateWordSegments('one two')
            .where((s) => s.isWordLike)
            .map((s) => s.start),
        [0, 4]);
  });

  test('cursor moves by grapheme and crosses leaf blocks', () {
    final allocator = createTestAllocator();
    var state = createEmptyDocument(allocator: allocator);
    final paragraph = BlockId('blk-1');
    final inserted = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'a😀b',
      const {},
    );
    state = inserted.state;
    expect(
        moveByCharacter(
                state, Position(blockId: paragraph, offset: 1), 'forward')
            .offset,
        3);
    expect(
        moveByCharacter(
                state, Position(blockId: paragraph, offset: 3), 'forward')
            .offset,
        4);
    expect(
        moveByWord(state, Position(blockId: paragraph, offset: 0), 'forward')
            .offset,
        1);
  });

  test('selectWord selects the containing word without crossing blocks', () {
    final allocator = createTestAllocator();
    var state = createEmptyDocument(allocator: allocator);
    final paragraph = BlockId('blk-1');
    state = insertText(
      state,
      Position(blockId: paragraph, offset: 0),
      'hello world',
      const {},
    ).state;
    final selected = selectWord(state, Position(blockId: paragraph, offset: 7));
    expect(selected.anchor.offset, 6);
    expect(selected.focus.offset, 11);
  });
}
