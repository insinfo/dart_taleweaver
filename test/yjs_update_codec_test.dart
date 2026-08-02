import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/id.dart';
import 'package:taleweaver/src/yjs/ids.dart';
import 'package:taleweaver/src/yjs/structs.dart';
import 'package:taleweaver/src/yjs/update_codec.dart';

void main() {
  test('struct update codec round-trips all supported struct kinds', () {
    final source = YStructUpdate(
      structs: [
        YGC(const YId(1, 0), 2),
        YItem(const YId(1, 2), 1, 'a', isDeleted: true),
        YSkip(const YId(1, 3), 4),
      ],
      deleteSet: YIdSet()..add(1, 2, 1),
    );
    final decoded =
        YStructUpdateCodec.decode(YStructUpdateCodec.encode(source));

    expect(decoded.structs, hasLength(3));
    expect(decoded.structs[0], isA<YGC>());
    expect((decoded.structs[1] as YItem).content, 'a');
    expect(decoded.structs[1].deleted, isTrue);
    expect(decoded.structs[2], isA<YSkip>());
    expect(decoded.deleteSet.covers(1, 2, 1), isTrue);
  });

  test('merge removes duplicate struct identities deterministically', () {
    final first = YStructUpdateCodec.encode(YStructUpdate(structs: [
      YItem(const YId(2, 0), 1, 'x'),
    ]));
    final second = YStructUpdateCodec.encode(YStructUpdate(structs: [
      YItem(const YId(2, 0), 1, 'x'),
      YGC(const YId(2, 1), 2),
    ]));
    final merged = YStructUpdateCodec.decode(
      YStructUpdateCodec.merge([first, second]),
    );

    expect(merged.structs, hasLength(2));
    expect(merged.structs.map((value) => value.id.clock), [0, 1]);
  });

  test('merged updates apply to an empty store and converge', () {
    final first = YStructUpdateCodec.encode(YStructUpdate(structs: [
      YItem(const YId(4, 0), 1, 'a'),
    ]));
    final second = YStructUpdateCodec.encode(YStructUpdate(structs: [
      YItem(const YId(4, 1), 1, 'b'),
      YGC(const YId(4, 2), 1),
    ]));
    final merged = YStructUpdateCodec.merge([first, second]);
    final left = YStructStore();
    final right = YStructStore();
    YStructUpdateCodec.apply(left, merged);
    YStructUpdateCodec.apply(right, YStructUpdateCodec.merge([second, first]));

    expect(left.stateVector, right.stateVector);
    expect(left.deleteSet, right.deleteSet);
    left.checkIntegrity();
    right.checkIntegrity();
  });

  test('YDoc allocates client clocks and exports its local structs', () {
    final doc = YDoc(clientId: 17);
    doc.getArray('items').push(['a', 'b']);
    doc.getText('text').insert(0, 'hi');

    final update = YStructUpdateCodec.decode(encodeStateAsUpdate(doc));
    expect(update.structs.map((value) => value.id), [
      const YId(17, 0),
      const YId(17, 2),
    ]);
    expect(doc.store.stateVector[17], 4);
  });

  test('public merge and apply update functions share the store contract', () {
    final source = YDoc(clientId: 9);
    source.getArray('items').push([1, 2]);
    final target = YDoc(clientId: 10);

    applyUpdate(target, encodeStateAsUpdate(source), 'remote');

    expect(target.store.stateVector[9], 2);
    expect(encodeStateAsUpdate(target),
        mergeUpdates([encodeStateAsUpdate(source)]));
  });
}
