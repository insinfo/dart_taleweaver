import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/id.dart';
import 'package:taleweaver/src/yjs/ids.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/snapshot.dart';
import 'package:taleweaver/src/yjs/structs.dart';
import 'package:taleweaver/src/yjs/types.dart';
import 'package:taleweaver/src/yjs/update_codec.dart';

void main() {
  test('structs merge only when type and clocks are contiguous', () {
    final left = YGC(const YId(1, 0), 2);
    expect(left.mergeWith(YGC(const YId(1, 2), 3)), isTrue);
    expect(left.length, 5);
    expect(left.mergeWith(YSkip(const YId(1, 5), 1)), isFalse);
  });

  test('store replaces a skip while preserving prefix and suffix', () {
    final store = YStructStore();
    store.clients[3] = [YSkip(const YId(3, 0), 10)];
    store.skips.add(3, 0, 10);
    store.add(YItem(const YId(3, 4), 2, 'ab'));

    expect(store.clients[3]!.map((s) => [s.id.clock, s.length]), [
      [0, 4],
      [4, 2],
      [6, 4],
    ]);
    expect(store.get(const YId(3, 4)), isA<YItem>());
    expect(store.skips.has(3, 0), isTrue);
    expect(store.skips.has(3, 4), isFalse);
    store.checkIntegrity();
  });

  test('store computes delete set and next state-vector clocks', () {
    final store = YStructStore()
      ..add(YItem(const YId(8, 0), 3, 'abc'))
      ..add(YGC(const YId(8, 3), 2));
    final deleted = store.get(const YId(8, 3));
    expect(deleted.deleted, isTrue);
    expect(store.deleteSet.covers(8, 3, 2), isTrue);
    expect(store.getClock(8), 5);
    expect(store.stateVector[8], 5);
  });

  test('partial deletion fragments an item and preserves surviving clocks', () {
    final doc = YDoc(clientId: 41);
    final text = doc.getText('body');
    text.insert(0, 'hello');
    text.delete(1, 2);
    expect(text.text, 'hlo');
    expect(doc.store.deleteSet.covers(41, 1, 2), isTrue);
    expect(doc.store.get(YId(41, 0)).length, 1);
    expect(doc.store.get(YId(41, 3)).length, 2);
  });

  test('duplicate struct ids with divergent payloads are rejected', () {
    final store = YStructStore();
    store.add(YItem(const YId(44, 0), 1, 'a', parent: 'text'));
    expect(
      () => store.addOrPend(YItem(const YId(44, 0), 1, 'b', parent: 'text')),
      throwsStateError,
    );
  });

  test('snapshot captures state vector and deleted visibility', () {
    final doc = YDoc(clientId: 42);
    final text = doc.getText('body');
    text.insert(0, 'abc');
    text.delete(1, 1);
    final snapshot = createSnapshot(doc);
    expect(snapshot.contains(const YId(42, 0)), isTrue);
    expect(snapshot.contains(const YId(42, 1)), isFalse);
    expect(YSnapshot.fromJson(snapshot.toJson())?.toJson(), snapshot.toJson());
  });

  test('snapshot membership distinguishes updates before and after boundary',
      () {
    final doc = YDoc(clientId: 45);
    final text = doc.getText('body');
    text.insert(0, 'a');
    final first = doc.store.get(const YId(45, 0));
    final snapshot = createSnapshot(doc);
    text.insert(1, 'b');
    final second = doc.store.get(const YId(45, 1));
    expect(snapshot.containsStruct(first), isTrue);
    expect(snapshot.containsStruct(second), isFalse);
  });

  test('snapshots compare and identify contained updates', () {
    final source = YDoc(clientId: 121);
    final text = source.getText('body');
    text.insert(0, 'before');
    final snapshot = createSnapshot(source);
    final first = encodeStateAsUpdate(source);
    text.insert(text.text.length, 'after');
    final later = encodeStateAsUpdate(source, snapshot.stateVector);

    expect(equalSnapshots(snapshot, YSnapshot.fromJson(snapshot.toJson())!),
        isTrue);
    expect(snapshotContainsUpdate(snapshot, first), isTrue);
    expect(snapshotContainsUpdate(snapshot, later), isFalse);
    final laterV2 = encodeStateAsUpdateV2(source, snapshot.stateVector);
    expect(snapshotContainsUpdate(snapshot, laterV2, v2: true), isFalse);
    expect(snapshotContainsUpdateV1(snapshot, first), isTrue);
    expect(snapshotContainsUpdateV2(snapshot, laterV2), isFalse);
  });

  test('snapshot update containment survives later deletes', () {
    final source = YDoc(clientId: 125);
    final text = source.getText('body');
    text.insert(0, 'gone');
    final inserted = encodeStateAsUpdate(source);
    final snapshotBeforeDelete = createSnapshot(source);
    text.delete(0, text.length);
    final snapshotAfterDelete = createSnapshot(source);

    expect(snapshotContainsUpdate(snapshotBeforeDelete, inserted), isTrue);
    expect(snapshotContainsUpdate(snapshotAfterDelete, inserted), isTrue);
  });

  test('empty snapshot is the zero causal boundary', () {
    expect(
        equalSnapshots(emptySnapshot,
            YSnapshot(stateVector: YStateVector(), deleteSet: YIdSet())),
        isTrue);
    final doc = YDoc(clientId: 122);
    doc.getText('body').insert(0, 'x');
    expect(snapshotContainsUpdate(emptySnapshot, encodeStateAsUpdate(doc)),
        isFalse);
  });

  test('snapshots round-trip through the binary V1 framing', () {
    final doc = YDoc(clientId: 123);
    final text = doc.getText('body');
    text.insert(0, 'abc');
    text.delete(1, 1);
    final snapshot = createSnapshot(doc);
    final decoded = decodeSnapshot(encodeSnapshot(snapshot));
    expect(equalSnapshots(snapshot, decoded), isTrue);
  });

  test('snapshots round-trip through the binary V2 framing', () {
    final doc = YDoc(clientId: 124);
    final text = doc.getText('body');
    text.insert(0, 'abcdef');
    text.delete(2, 2);
    final snapshot = createSnapshot(doc);
    final decoded = decodeSnapshotV2(encodeSnapshotV2(snapshot));
    expect(equalSnapshots(snapshot, decoded), isTrue);
  });

  test('snapshot materialization excludes updates after the boundary', () {
    final source = YDoc(clientId: 46);
    final text = source.getText('body');
    text.insert(0, 'before');
    final snapshot = createSnapshot(source);
    text.insert(text.length, 'after');
    final restored = createDocFromSnapshot(source, snapshot, clientId: 1046);
    expect(restored.getText('body').text, 'before');
    expect(source.getText('body').text, 'beforeafter');
  });

  test('snapshot materialization restores an item deleted after the boundary',
      () {
    final source = YDoc(clientId: 47);
    final array = source.getArray('items');
    array.push(['item1', 'item2']);
    final snapshot = createSnapshot(source);
    array.delete(0);
    final restored = createDocFromSnapshot(source, snapshot, clientId: 1047);
    expect(restored.getArray('items').toArray(), ['item1', 'item2']);
    expect(array.toArray(), ['item2']);
  });

  test('snapshot materialization preserves nested attributes at its boundary',
      () {
    final source = YDoc(clientId: 48);
    final root = source.getMap('root');
    final nested = YMap()..set('value', 'before');
    root.set('nested', nested);
    final snapshot = createSnapshot(source);
    nested.set('value', 'after');
    final restored = createDocFromSnapshot(source, snapshot, clientId: 1048);
    final restoredNested = restored.getMap('root').get('nested');
    expect(restoredNested, isA<YMap>());
    expect((restoredNested as YMap).get('value'), 'before');
    expect(nested.get('value'), 'after');
  });

  test('array partial deletion contributes to the DeleteSet', () {
    final doc = YDoc(clientId: 43);
    final array = doc.getArray('items');
    array.push(['a', 'b', 'c']);
    array.delete(1);
    expect(array.toArray(), ['a', 'c']);
    expect(doc.store.deleteSet.covers(43, 1, 1), isTrue);
  });
}
