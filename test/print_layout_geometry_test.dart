import 'package:test/test.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';
import 'package:taleweaver/src/core/print/layout/page_box.dart';
import 'package:taleweaver/src/core/print/layout/page_config.dart';
import 'package:taleweaver/src/core/styles/writing_mode.dart';

void main() {
  test('print page config computes content geometry', () {
    const config = PrintLayoutConfig();
    expect(config.contentWidth, 468);
    expect(config.contentHeight, 648);
  });

  test('page box retains page-relative children and dimensions', () {
    const child = TextRunBox(
        key: 'text',
        inlineOffset: 0,
        blockOffset: 0,
        inlineSize: 20,
        blockSize: 16,
        x: 0,
        y: 0,
        width: 20,
        height: 16,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        text: 'Hi',
        offsetLength: 2);
    final page = createPageBox(
        key: 'page-0',
        inlineSize: 468,
        blockSize: 648,
        blockOffset: 0,
        writingMode: WritingMode.horizontalTb,
        direction: Direction.ltr,
        containingInlineSize: 468,
        children: [child],
        pageIndex: 0);
    expect(page.type, 'page');
    expect(page.children.single, same(child));
    expect(page.width, 468);
  });
}
