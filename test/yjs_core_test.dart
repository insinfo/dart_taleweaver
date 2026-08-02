import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/types.dart';
import 'package:taleweaver/src/yjs/id.dart';
import 'package:taleweaver/src/yjs/structs.dart';

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

  test('YMap mutations are represented as keyed ContentAny items', () {
    final doc = YDoc(clientId: 51);
    final map = doc.getMap('meta');
    map.set('title', 'Taleweaver');
    expect(map.get('title'), 'Taleweaver');
    expect(doc.store.clients[51], hasLength(1));
    map.remove('title');
    expect(doc.store.deleteSet.covers(51, 0, 1), isTrue);
  });

  test('map and array clear retain tombstones in the store', () {
    final doc = YDoc(clientId: 52);
    final map = doc.getMap('meta')
      ..set('a', 1)
      ..set('b', 2);
    final array = doc.getArray('items')..push([1, 2]);
    map.clear();
    array.clear();
    expect(doc.store.deleteSet.covers(52, 0, 4), isTrue);
  });

  test('YMap remote conflicts resolve by deterministic YId ordering', () {
    final map = YDoc().getMap('meta');
    map.applyRemote('title', 'newer', id: const YId(20, 1));
    map.applyRemote('title', 'older', id: const YId(10, 9));
    expect(map.get('title'), 'newer');
    map.applyRemote('title', 'latest', id: const YId(20, 2));
    expect(map.get('title'), 'latest');
  });

  test('YMap remote delete tombstone blocks stale resurrection', () {
    final map = YDoc().getMap('meta');
    map.applyRemote('title', 'value', id: const YId(7, 1));
    map.applyRemoteDelete(const YId(7, 1));
    map.applyRemote('title', 'stale', id: const YId(7, 1));
    expect(map.containsKey('title'), isFalse);
    map.applyRemote('title', 'new', id: const YId(7, 2));
    expect(map.get('title'), 'new');
  });

  test('YMap remembers deletes delivered before the remote item', () {
    final map = YDoc().getMap('meta');
    const deleted = YId(9, 4);
    map.applyRemoteDelete(deleted, key: 'title');
    map.applyRemote('title', 'stale', id: deleted);
    expect(map.containsKey('title'), isFalse);
    map.applyRemote('title', 'new', id: const YId(9, 5));
    expect(map.get('title'), 'new');
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

  test('YArray concurrent remote inserts converge by YId and causal origins',
      () {
    final array = YDoc().getArray('array');
    array.applyRemote(['high'], id: const YId(20, 1));
    array.applyRemote(['low'], id: const YId(10, 1));
    expect(array.toArray(), ['low', 'high']);
    array.applyRemote(['tail'], id: const YId(30, 1), origin: const YId(20, 1));
    expect(array.toArray(), ['low', 'high', 'tail']);
  });

  test('YArray tombstone rejects stale remote resurrection', () {
    final array = YDoc().getArray('array');
    array.applyRemote(['value'], id: const YId(4, 1));
    array.applyRemoteDelete(const YId(4, 1), 1);
    array.applyRemote(['stale'], id: const YId(4, 1));
    expect(array.toArray(), isEmpty);
    array.applyRemote(['new'], id: const YId(4, 2));
    expect(array.toArray(), ['new']);
  });

  test('YArray remembers remote deletes delivered before the item', () {
    final array = YDoc().getArray('array');
    array.applyRemoteDelete(const YId(6, 2), 1);
    array.applyRemote(['stale'], id: const YId(6, 2));
    expect(array.toArray(), isEmpty);
    array.applyRemote(['new'], id: const YId(6, 3));
    expect(array.toArray(), ['new']);
  });

  test('YArray partial deletes preserve surviving clock fragments', () {
    final array = YDoc().getArray('array');
    array.applyRemote(['a', 'b', 'c', 'd'], id: const YId(11, 20));
    array.applyRemoteDeleteRange(const YId(11, 20), 1, 2);
    expect(array.toArray(), ['a', 'd']);
    array.applyRemote(['a', 'b', 'c', 'd'], id: const YId(11, 20));
    expect(array.toArray(), ['a', 'd']);
    array.applyRemote(['e'], id: const YId(11, 24));
    expect(array.toArray(), ['a', 'd', 'e']);
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

  test('empty YArray/YText inserts are no-ops after range validation', () {
    final doc = YDoc();
    final array = doc.getArray('array');
    final text = doc.getText('text');
    var events = 0;
    array.observe((_) => events++);
    text.observe((_) => events++);
    array.insert(0, const []);
    text.insert(0, '');
    expect(array.toArray(), isEmpty);
    expect(text.text, isEmpty);
    expect(events, 0);
    expect(() => text.insert(1, ''), throwsRangeError);
  });

  test('YText preserves insert attributes and formats in delta runs', () {
    final doc = YDoc(clientId: 60);
    final text = doc.getText('text');
    text.insert(0, 'ab', {'bold': true});
    text.insert(2, 'cd');
    text.format(1, 2, {'italic': true});
    expect(text.toDelta(), [
      {
        'insert': 'a',
        'attributes': {'bold': true}
      },
      {
        'insert': 'b',
        'attributes': {'bold': true, 'italic': true}
      },
      {
        'insert': 'c',
        'attributes': {'italic': true}
      },
      {'insert': 'd'},
    ]);
    text.format(1, 2, {'bold': null});
    expect(text.toDelta()[1]['attributes'], {'italic': true});
    expect(doc.store.clients[60], isNotEmpty);
  });

  test('YText formatting follows UTF-16 offsets through surrogate pairs', () {
    final text = YDoc().getText('text');
    text.insert(0, '👾👾');
    text.format(1, 2, {'bold': true});
    expect(text.toDelta(), [
      {'insert': '\ud83d'},
      {
        'insert': '\udc7e\ud83d',
        'attributes': {'bold': true}
      },
      {'insert': '\udc7e'},
    ]);
  });

  test('remote YFormatContent applies at its causal text boundary', () {
    final doc = YDoc();
    final text = doc.getText('text');
    text.applyRemote('a', id: const YId(40, 0));
    text.applyRemote('b', id: const YId(40, 1), origin: const YId(40, 0));
    doc.applyRemoteItem(YItem(
      const YId(41, 0),
      1,
      const YFormatContent('bold', true),
      parent: 'text',
      origin: const YId(40, 0),
    ));
    expect(text.toDelta(), [
      {'insert': 'a'},
      {
        'insert': 'b',
        'attributes': {'bold': true}
      }
    ]);
  });

  test('remote YFormatContent closes a format at the next causal marker', () {
    final doc = YDoc();
    final text = doc.getText('text');
    text.applyRemote('a', id: const YId(50, 0));
    text.applyRemote('b', id: const YId(50, 1), origin: const YId(50, 0));
    text.applyRemote('c', id: const YId(50, 2), origin: const YId(50, 1));
    doc.applyRemoteItem(YItem(
      const YId(51, 0),
      1,
      const YFormatContent('bold', true),
      parent: 'text',
      origin: const YId(50, 0),
    ));
    doc.applyRemoteItem(YItem(
      const YId(51, 1),
      1,
      const YFormatContent('bold', null),
      parent: 'text',
      origin: const YId(50, 1),
    ));
    expect(text.toDelta(), [
      {'insert': 'a'},
      {
        'insert': 'b',
        'attributes': {'bold': true}
      },
      {'insert': 'c'},
    ]);
  });

  test('remote YFormatContent falls back to right anchor after origin deletion',
      () {
    final doc = YDoc();
    final text = doc.getText('text');
    text.applyRemote('abc', id: const YId(52, 0));
    text.applyRemoteDelete(const YId(52, 0), 1);
    doc.applyRemoteItem(YItem(
      const YId(53, 0),
      1,
      const YFormatContent('italic', true),
      parent: 'text',
      origin: const YId(52, 0),
      rightOrigin: const YId(52, 1),
    ));
    expect(text.toDelta(), [
      {
        'insert': 'bc',
        'attributes': {'italic': true}
      }
    ]);
  });

  test('YText tombstone rejects stale remote string resurrection', () {
    final text = YDoc().getText('text');
    text.applyRemote('old', id: const YId(8, 1));
    text.applyRemoteDelete(const YId(8, 1), 3);
    text.applyRemote('stale', id: const YId(8, 1));
    expect(text.toString(), isEmpty);
    text.applyRemote('new', id: const YId(8, 2));
    expect(text.toString(), 'new');
  });

  test('YText remembers remote deletes delivered before the item', () {
    final text = YDoc().getText('text');
    text.applyRemoteDelete(const YId(7, 3), 2);
    text.applyRemote('stale', id: const YId(7, 3));
    expect(text.text, isEmpty);
    text.applyRemote('new', id: const YId(7, 5));
    expect(text.text, 'new');
  });

  test('YText partial deletes preserve surviving clock fragments', () {
    final text = YDoc().getText('text');
    text.applyRemote('abcd', id: const YId(9, 10));
    text.applyRemoteDeleteRange(const YId(9, 10), 1, 2);
    expect(text.toString(), 'ad');
    // Replaying the original item must not duplicate the surviving fragments.
    text.applyRemote('abcd', id: const YId(9, 10));
    expect(text.toString(), 'ad');
    text.applyRemote('x', id: const YId(9, 14));
    expect(text.toString(), 'adx');
  });
}
