import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/print/layout/bfc.dart';
import 'package:taleweaver/src/core/print/layout/ifc.dart';
import 'package:taleweaver/src/core/print/layout/layout_box.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';

void main() {
  test('IFC wraps at grapheme cluster boundaries', () {
    final lines = layoutInlineText(
        text: 'abcdef',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        maxInlineSize: 25);
    expect(lines, hasLength(3));
    expect(lines.map((line) => line.children.single is TextRunBox),
        everyElement(isTrue));
    expect(lines.map((line) => (line.children.single as TextRunBox).text),
        ['ab', 'cd', 'ef']);
  });

  test('BFC wraps inline lines and computes block size', () {
    final box = layoutBlockText(
        key: 'p',
        text: 'abcd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        inlineSize: 25);
    expect(box.children, hasLength(2));
    expect(box.blockSize, 40);
  });

  test('IFC prefers UAX14 whitespace break opportunities', () {
    final lines = layoutInlineText(
        text: 'abc def',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        maxInlineSize: 45);
    expect(lines.map((line) => (line.children.single as TextRunBox).text),
        ['abc ', 'def']);
  });

  test('IFC honors mandatory line breaks', () {
    final lines = layoutInlineText(
        text: 'ab\ncd',
        ownerBlockId: const BlockId('p'),
        shaper: createMockShaper(10, 20),
        style: initialComputedStyle,
        maxInlineSize: 100);
    expect(lines, hasLength(2));
    expect(lines.map((line) => (line.children.single as TextRunBox).text),
        ['ab', 'cd']);
  });
}
