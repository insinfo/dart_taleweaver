import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/types.dart';

void main() {
  test('shared types are stable and serialize recursively', () {
    final doc = YDoc();
    final map = doc.getMap('map');
    expect(identical(map, doc.getMap('map')), isTrue);
    final nested = YMap();
    map.set('nested', nested);
    nested.set('value', 42);
    expect(doc.toJson(), {
      'map': {
        'nested': {'value': 42},
      },
    });
  });

  test('array insert, delete and slicing follow Yjs positions', () {
    final array = YDoc().getArray('array');
    array.insert(0, [1, 2, 3]);
    array.insert(1, ['x']);
    expect(array.toArray(), [1, 'x', 2, 3]);
    expect(array.slice(1, -1), ['x', 2]);
    array.delete(1);
    expect(array.toArray(), [1, 2, 3]);
  });

  test('nested mutations are batched into one document transaction', () {
    final doc = YDoc();
    final map = doc.getMap('map');
    final nested = YMap();
    map.set('nested', nested);
    var calls = 0;
    YTransaction? transaction;
    doc.onAfterTransaction((value) {
      calls++;
      transaction = value;
    });

    doc.transact(() {
      nested.set('a', 1);
      nested.set('b', 2);
    }, origin: 'test');

    expect(calls, 1);
    expect(transaction!.origin, 'test');
    expect(transaction!.events, hasLength(2));
  });

  test('deep observers receive nested changes once per transaction', () {
    final doc = YDoc();
    final map = doc.getMap('map');
    final nested = YMap();
    map.set('nested', nested);
    var calls = 0;
    var eventCount = 0;
    map.observeDeep((events) {
      calls++;
      eventCount = events.length;
    });

    doc.transact(() {
      nested.set('a', 1);
      nested.set('b', 2);
    });

    expect(calls, 1);
    expect(eventCount, 2);
  });

  test('text operations preserve UTF-16 offsets and notify observers', () {
    final text = YDoc().getText('text');
    var changes = 0;
    text.observe((_) => changes++);
    text.insert(0, 'abc');
    text.insert(1, 'X');
    text.delete(2, 1);
    expect(text.toString(), 'aXc');
    expect(changes, 3);
  });
}
