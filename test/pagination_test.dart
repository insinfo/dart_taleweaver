import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/layout/bfc.dart';
import 'package:taleweaver/src/core/print/layout/page_config.dart';
import 'package:taleweaver/src/core/print/layout/pagination.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/state/block_id.dart';

void main() {
  test('pagination splits block lines at content height', () {
    final block = layoutBlockText(
        key: 'p',
        text: 'abcdefghijklmnopqrst',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 25);
    final pages = paginateBlock(
        block: block,
        config: const PrintLayoutConfig(
            pageSize: PrintPageSize(300, 180),
            margins:
                PrintPageMargins(top: 20, right: 20, bottom: 20, left: 20)));
    expect(pages, hasLength(2));
    expect(pages[0].children, hasLength(7));
    expect(pages[1].children, hasLength(3));
    expect(pages[1].pageIndex, 1);
  });
}
