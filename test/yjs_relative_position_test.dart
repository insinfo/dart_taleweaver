import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/relative_position.dart';

void main() {
  test('relative position serializes a root YText key and resolves', () {
    final doc = YDoc();
    final text = doc.getText('paragraph')..insert(0, 'hello');
    final relative = createRelativePosition(text, 3, assoc: -1);
    final restored = relativePositionFromJson(doc, relative.toJson());
    final absolute = createAbsolutePosition(restored!, doc)!;

    expect(absolute.type, same(text));
    expect(absolute.offset, 3);
    expect(restored.assoc, -1);
  });

  test('relative position from another document does not resolve', () {
    final first = YDoc();
    final second = YDoc();
    final relative = createRelativePosition(first.getText('text'), 0);
    expect(createAbsolutePosition(relative, second), isNull);
  });
}
