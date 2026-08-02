import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/id.dart';
import 'package:taleweaver/src/yjs/structs.dart';

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
}
