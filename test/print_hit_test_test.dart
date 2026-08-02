import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/cursor/hit_test.dart';
import 'package:taleweaver/src/core/print/layout/bfc.dart';
import 'package:taleweaver/src/core/print/layout/page_config.dart';
import 'package:taleweaver/src/core/print/layout/pagination.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';

void main() {
  test('hit-test maps a line x coordinate to a block position', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    final position = hitTestPage(page, 25, 5);
    expect(position!.blockId, const BlockId('p'));
    expect(position.offset, 3);
  });

  test('hit-test misses outside all lines', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'a',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 100);
    final page =
        paginateBlock(block: block, config: const PrintLayoutConfig()).single;
    expect(hitTestPage(page, 10, 1000), isNull);
  });
}
