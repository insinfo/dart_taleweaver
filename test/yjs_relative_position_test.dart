import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/relative_position.dart';
import 'package:taleweaver/src/yjs/undo_manager.dart';
import 'package:taleweaver/src/yjs/snapshot.dart';
import 'package:taleweaver/src/yjs/types.dart';

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

  test('relative position resolves through later text insertion', () {
    final doc = YDoc();
    final text = doc.getText('text');
    text.insert(0, 'a');
    final relative = createRelativePosition(text, 1);
    text.insert(1, 'b');
    expect(createAbsolutePosition(relative, doc)!.offset, 1);
  });

  test('relative position preserves association around concurrent insertion',
      () {
    final doc = YDoc(clientId: 904);
    final text = doc.getText('text');
    text.insert(0, 'ab');
    final left = createRelativePosition(text, 1, assoc: -1);
    final right = createRelativePosition(text, 1, assoc: 0);
    text.insert(1, 'x');
    final leftAbsolute = createAbsolutePosition(left, doc)!;
    final rightAbsolute = createAbsolutePosition(right, doc)!;
    expect(leftAbsolute.assoc, -1);
    expect(rightAbsolute.assoc, 0);
    expect(leftAbsolute.offset, 1);
    expect(rightAbsolute.offset, 2);
  });

  test('relative anchor follows the surviving boundary after deletion', () {
    final doc = YDoc(clientId: 905);
    final text = doc.getText('text');
    text.insert(0, 'hello world');
    final relative = createRelativePosition(text, 1);
    text.delete(0, 6);
    expect(createAbsolutePosition(relative, doc)!.offset, 0);
  });

  test('relative positions round-trip every internal UTF-16 offset and assoc',
      () {
    final doc = YDoc(clientId: 906);
    final text = doc.getText('text');
    text.insert(0, '1');
    text.insert(0, 'abc');
    text.insert(0, 'z');
    text.insert(0, 'y');
    text.insert(0, 'x');
    for (var offset = 0; offset < text.length; offset++) {
      for (final assoc in [-1, 0, 1]) {
        final relative = createRelativePosition(text, offset, assoc: assoc);
        final restored = relativePositionFromJson(doc, relative.toJson())!;
        final absolute = createAbsolutePosition(restored, doc)!;
        expect(absolute.offset, offset,
            reason: 'offset=$offset assoc=$assoc text=${text.text}');
        expect(absolute.assoc, assoc);
      }
    }
  });

  test('relative position remains resolvable across undo and redo snapshots',
      () {
    final doc = YDoc(clientId: 907);
    final text = doc.getText('text')..insert(0, 'hello world');
    final relative = createRelativePosition(text, 1);
    final manager = YUndoManager(doc);
    manager.beginCapture();
    text.delete(0, 6);
    manager.endCapture();
    expect(createAbsolutePosition(relative, doc)!.offset, 0);
    manager.undo();
    expect(createAbsolutePosition(relative, doc)!.offset, 1);
    manager.redo();
    expect(createAbsolutePosition(relative, doc)!.offset, 0);
  });

  test('snapshot reconstruction preserves nested shared type topology', () {
    final source = YDoc(clientId: 915);
    final items = source.getArray('items');
    final nestedMap = YMap()..set('value', 'map');
    final nestedText = YText()..insert(0, 'text');
    items.push([nestedMap, nestedText]);
    final restored =
        createDocFromSnapshot(source, createSnapshot(source), clientId: 916);
    final restoredItems = restored.getArray('items');
    expect(restoredItems.get(0), isA<YMap>());
    expect((restoredItems.get(0) as YMap).get('value'), 'map');
    expect(restoredItems.get(1), isA<YText>());
    expect((restoredItems.get(1) as YText).text, 'text');
  });

  test('nested YText relative positions round-trip by causal parent item', () {
    final doc = YDoc(clientId: 918);
    final nested = YText()..insert(0, 'nested');
    doc.getArray('items').push([nested]);
    final relative = createRelativePosition(nested, 3, assoc: -1);
    final json = relative.toJson();
    expect(json['type'], isNull);
    expect(json['typeItem'], isA<Map>());
    final restored = relativePositionFromJson(doc, json)!;
    expect(restored.type, same(nested));
    expect(createAbsolutePosition(restored, doc)!.offset, 3);
  });

  test('nested type identity wins over a colliding root key', () {
    final doc = YDoc(clientId: 919);
    doc.getText('same')..insert(0, 'root');
    final nested = YText()..insert(0, 'nested');
    doc.getMap('container').set('same', nested);
    final restored = relativePositionFromJson(
        doc, createRelativePosition(nested, 2).toJson());
    expect(restored?.type, same(nested));
  });
}
