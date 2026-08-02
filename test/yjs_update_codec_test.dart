import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/id.dart';
import 'package:taleweaver/src/yjs/ids.dart';
import 'package:taleweaver/src/yjs/structs.dart';
import 'package:taleweaver/src/yjs/snapshot.dart';
import 'package:taleweaver/src/yjs/types.dart';
import 'package:taleweaver/src/yjs/update_codec.dart';

void main() {
  test('format markers round-trip through V1 and V2 updates', () {
    final source = YDoc(clientId: 61);
    final text = source.getText('text');
    text.insert(0, 'abc');
    text.format(1, 1, {'bold': true});
    final v1Target = YDoc();
    final v2Target = YDoc();
    applyUpdate(v1Target, encodeStateAsUpdate(source));
    applyUpdateV2(v2Target, encodeStateAsUpdateV2(source));
    expect(v1Target.getText('text').toDelta(), [
      {'insert': 'a'},
      {
        'insert': 'b',
        'attributes': {'bold': true}
      },
      {'insert': 'c'},
    ]);
    expect(
        v2Target.getText('text').toDelta(), v1Target.getText('text').toDelta());
  });

  test('surrogate-splitting format markers round-trip through V1 and V2', () {
    final source = YDoc(clientId: 62);
    final text = source.getText('text');
    text.insert(0, '👾👾');
    text.format(1, 2, {'bold': true});
    final v1Target = YDoc();
    final v2Target = YDoc();
    applyUpdate(v1Target, encodeStateAsUpdate(source));
    applyUpdateV2(v2Target, encodeStateAsUpdateV2(source));
    expect(v1Target.getText('text').toDelta(), text.toDelta());
    expect(v2Target.getText('text').toDelta(), text.toDelta());
  });

  test('concurrent YText formats converge when marker updates interleave', () {
    final base = YDoc(clientId: 70);
    base.getText('text').insert(0, 'abc');
    final baseUpdate = encodeStateAsUpdate(base);
    final left = YDoc(clientId: 71);
    final right = YDoc(clientId: 72);
    applyUpdate(left, baseUpdate);
    applyUpdate(right, baseUpdate);
    left.getText('text').format(0, 2, {'bold': true});
    right.getText('text').format(1, 2, {'italic': true});
    final leftDelta = encodeStateAsUpdate(left, base.store.stateVector);
    final rightDelta = encodeStateAsUpdate(right, base.store.stateVector);

    final target = YDoc();
    applyUpdate(target, baseUpdate);
    applyUpdate(target, rightDelta);
    applyUpdate(target, leftDelta);
    expect(target.getText('text').toDelta(), [
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
    ]);
  });

  test('snapshot cloning preserves materialized YText attributes', () {
    final source = YDoc(clientId: 73);
    final nested = YText();
    nested.insert(0, 'abc');
    nested.format(1, 1, {'code': true});
    source.getMap('root').set('text', nested);
    final snapshot = createSnapshot(source);
    final restored = createDocFromSnapshot(source, snapshot);
    final value = restored.getMap('root').get('text');
    expect(value, isA<YText>());
    expect((value as YText).toDelta(), [
      {'insert': 'a'},
      {
        'insert': 'b',
        'attributes': {'code': true}
      },
      {'insert': 'c'},
    ]);
  });

  test('V1 text update is byte-compatible with Yjs 13.6.18', () {
    final doc = YDoc(clientId: 17);
    doc.getText('text').insert(0, 'hi');

    expect(encodeStateAsUpdate(doc), [
      1,
      1,
      17,
      0,
      4,
      1,
      4,
      116,
      101,
      120,
      116,
      2,
      104,
      105,
      0,
    ]);
  });

  test('state-vector diff emits only clocks after the requested frontier', () {
    final source = YDoc(clientId: 18);
    source.getText('text').insert(0, 'abc');
    final update = encodeStateAsUpdate(source, YStateVector({18: 1}));
    final decoded = YStructUpdateCodec.decode(update);
    final item = decoded.structs.single as YItem;
    expect(item.id, const YId(18, 1));
    expect(item.content, 'bc');
  });

  test('remote keyed map ContentAny materializes through V1 and V2', () {
    final source = YDoc(clientId: 19);
    source.getMap('meta').set('title', 'Taleweaver');
    final targetV1 = YDoc(clientId: 20);
    applyUpdate(targetV1, encodeStateAsUpdate(source));
    expect(targetV1.getMap('meta').get('title'), 'Taleweaver');
    final targetV2 = YDoc(clientId: 21);
    applyUpdateV2(targetV2, encodeStateAsUpdateV2(source));
    expect(targetV2.getMap('meta').get('title'), 'Taleweaver');
  });

  test('V1 ContentAny update is byte-compatible with Yjs 13.6.18', () {
    final doc = YDoc(clientId: 17);
    doc.getArray('items').push(['a', 2, true, null]);

    expect(encodeStateAsUpdate(doc), [
      1,
      1,
      17,
      0,
      8,
      1,
      5,
      105,
      116,
      101,
      109,
      115,
      4,
      119,
      1,
      97,
      125,
      2,
      120,
      126,
      0,
    ]);
  });

  test('V2 text update is byte-compatible with Yjs 13.6.18', () {
    final doc = YDoc(clientId: 17);
    doc.getText('text').insert(0, 'hi');

    expect(encodeStateAsUpdateV2(doc), [
      0,
      0,
      1,
      17,
      0,
      0,
      1,
      4,
      9,
      6,
      116,
      101,
      120,
      116,
      104,
      105,
      4,
      2,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      0,
    ]);
  });

  test('V2 ContentAny update is byte-compatible with Yjs 13.6.18', () {
    final doc = YDoc(clientId: 17);
    doc.getArray('items').push(['a', 2, true, null, 1.5]);

    final bytes = encodeStateAsUpdateV2(doc);
    expect(bytes, [
      0,
      0,
      1,
      17,
      0,
      0,
      1,
      8,
      7,
      5,
      105,
      116,
      101,
      109,
      115,
      5,
      1,
      1,
      0,
      1,
      5,
      1,
      1,
      0,
      119,
      1,
      97,
      125,
      2,
      120,
      126,
      124,
      63,
      192,
      0,
      0,
      0,
    ]);
    final decoded = YStructUpdateCodec.decodeV2(bytes);
    expect(
        (decoded.structs.single as YItem).content, ['a', 2, true, null, 1.5]);
  });

  test('V2 apply shares the same store convergence contract', () {
    final source = YDoc(clientId: 33);
    source.getText('body').insert(0, 'compressed');
    final target = YDoc(clientId: 34);

    applyUpdateV2(target, encodeStateAsUpdateV2(source), 'remote');

    expect(target.store.stateVector[33], 10);
    expect(encodeStateAsUpdateV2(target), encodeStateAsUpdateV2(source));
  });

  test('V2 split item and DeleteSet match Yjs 13.6.18 bytes', () {
    final deletes = YIdSet()..add(17, 0, 1);
    final update = YStructUpdate(structs: [
      YItem(const YId(17, 0), 1, const YDeletedContent(1),
          isDeleted: true, parent: 'text'),
      YItem(const YId(17, 1), 1, 'i', origin: const YId(17, 0), parent: 'text'),
    ], deleteSet: deletes);

    final bytes = YStructUpdateCodec.encodeV2(update);
    expect(bytes, [
      0,
      0,
      2,
      81,
      0,
      1,
      0,
      0,
      3,
      1,
      0,
      132,
      8,
      5,
      116,
      101,
      120,
      116,
      105,
      4,
      1,
      1,
      1,
      0,
      1,
      1,
      1,
      2,
      0,
      1,
      17,
      1,
      0,
      0,
    ]);
    final decoded = YStructUpdateCodec.decodeV2(bytes);
    expect(decoded.structs.first.deleted, isTrue);
    expect((decoded.structs.last as YItem).origin, const YId(17, 0));
    expect(decoded.deleteSet.covers(17, 0, 1), isTrue);
  });

  test('remote V1 and V2 updates materialize shared text and arrays', () {
    final source = YDoc(clientId: 41);
    source.getText('body').insert(0, 'remote');
    source.getArray('items').push(['a', 2]);
    final target = YDoc(clientId: 42);

    applyUpdate(target, encodeStateAsUpdate(source), 'peer-1');
    expect(target.getText('body').text, 'remote');
    expect(target.getArray('items').toArray(), ['a', 2]);

    applyUpdateV2(target, encodeStateAsUpdateV2(source), 'peer-1');
    expect(target.getText('body').text, 'remote');
    expect(target.getArray('items').toArray(), ['a', 2]);
  });

  test('apply update preserves the caller origin for V1 and V2 transactions',
      () {
    final source = YDoc(clientId: 43);
    source.getText('body').insert(0, 'origin');
    final target = YDoc(clientId: 44);
    final origins = <Object?>[];
    target.onAfterTransaction((transaction) => origins.add(transaction.origin));

    applyUpdate(target, encodeStateAsUpdate(source), 'peer-v1');
    applyUpdateV2(target, encodeStateAsUpdateV2(source), 'peer-v2');

    expect(origins, ['peer-v1', 'peer-v2']);
  });

  test('nested shared map values converge through updates', () {
    final source = YDoc(clientId: 81);
    final root = source.getMap('root');
    final nested = YMap();
    root.set('nested', nested);
    nested.set('value', 'before');
    final target = YDoc(clientId: 82);

    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    final restored = target.getMap('root').get('nested');
    expect(restored, isA<YMap>());
    expect((restored as YMap).get('value'), 'before');
    nested.set('value', 'after');
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    expect((target.getMap('root').get('nested') as YMap).get('value'), 'after');
  });

  test('nested shared array values converge through updates', () {
    final source = YDoc(clientId: 83);
    final root = source.getMap('root');
    final nested = YArray();
    root.set('items', nested);
    nested.push(['before']);
    final target = YDoc(clientId: 84);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    final restored = target.getMap('root').get('items');
    expect(restored, isA<YArray>());
    expect((restored as YArray).toArray(), ['before']);
    nested.push(['after']);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    expect((target.getMap('root').get('items') as YArray).toArray(),
        ['before', 'after']);
  });

  test('nested shared text values converge through updates', () {
    final source = YDoc(clientId: 85);
    final root = source.getMap('root');
    final nested = YText();
    root.set('text', nested);
    nested.insert(0, 'before');
    final target = YDoc(clientId: 86);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    final restored = target.getMap('root').get('text');
    expect(restored, isA<YText>());
    expect((restored as YText).text, 'before');
    nested.insert(nested.length, ' after');
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    expect((target.getMap('root').get('text') as YText).text, 'before after');
  });

  test('mixed array runs preserve causal order around nested types', () {
    final source = YDoc(clientId: 87);
    final array = source.getArray('items');
    final nested = YMap();
    array.insert(0, ['before', nested, 'after']);
    nested.set('value', 'nested');
    final target = YDoc(clientId: 88);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    final values = target.getArray('items').toArray();
    expect(values.first, 'before');
    expect(values[1], isA<YMap>());
    expect((values[1] as YMap).get('value'), 'nested');
    expect(values.last, 'after');
  });

  test('nested text and array deletes converge through updates', () {
    final source = YDoc(clientId: 84);
    final root = source.getMap('root');
    final nestedText = YText();
    final nestedArray = YArray();
    root.set('text', nestedText);
    root.set('array', nestedArray);
    nestedText.insert(0, 'remove');
    nestedArray.push(['remove']);
    final target = YDoc(clientId: 85);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    expect((target.getMap('root').get('text') as YText).text, 'remove');
    expect(
        (target.getMap('root').get('array') as YArray).toArray(), ['remove']);

    nestedText.delete(0, nestedText.length);
    nestedArray.delete(0);
    applyUpdateV2(target, encodeStateAsUpdateV2(source));
    expect((target.getMap('root').get('text') as YText).text, isEmpty);
    expect((target.getMap('root').get('array') as YArray).toArray(), isEmpty);
  });

  test('remote text origin preserves insertion order', () {
    final source = YDoc(clientId: 51);
    final text = source.getText('body');
    text.insert(0, 'a');
    text.insert(0, 'b');
    final target = YDoc(clientId: 52);

    applyUpdateV2(target, encodeStateAsUpdateV2(source));

    expect(text.text, 'ba');
    expect(target.getText('body').text, 'ba');
  });

  test('concurrent root text inserts converge by YId order', () {
    final left = YDoc(clientId: 60);
    final right = YDoc(clientId: 61);
    left.getText('text').insert(0, 'A');
    right.getText('text').insert(0, 'B');
    final target = YDoc(clientId: 62);
    applyUpdate(target, encodeStateAsUpdate(right));
    applyUpdate(target, encodeStateAsUpdate(left));
    expect(target.getText('text').text, 'AB');
  });

  test('remote structs wait for causal predecessors and drain pending queue',
      () {
    final first = YItem(const YId(61, 0), 1, 'a', parent: 'body');
    final second = YItem(const YId(61, 1), 1, 'b',
        origin: const YId(61, 0), parent: 'body');
    final target = YDoc(clientId: 62);

    applyUpdateV2(
        target, YStructUpdateCodec.encodeV2(YStructUpdate(structs: [second])));
    expect(target.store.pending[61], hasLength(1));
    expect(target.getText('body').text, '');

    applyUpdateV2(
        target, YStructUpdateCodec.encodeV2(YStructUpdate(structs: [first])));
    expect(target.store.pending, isEmpty);
    expect(target.getText('body').text, 'ab');
  });

  test('remaining Yjs content refs round-trip in V1 and V2', () {
    final structs = <YStruct>[
      YItem(const YId(71, 0), 1, const YBinaryContent([1, 2]), parent: 'root'),
      YItem(const YId(71, 1), 1, const YEmbedContent({'kind': 'image'}),
          parent: 'root'),
      YItem(const YId(71, 2), 1, const YFormatContent('bold', true),
          parent: 'root'),
      YItem(const YId(71, 3), 1, const YTypeContent(3, key: 'xml'),
          parent: 'root'),
      YItem(const YId(71, 4), 1, const YDocContent('subdoc', {'gc': false}),
          parent: 'root'),
    ];

    for (final bytes in [
      YStructUpdateCodec.encode(YStructUpdate(structs: structs)),
      YStructUpdateCodec.encodeV2(YStructUpdate(structs: structs)),
    ]) {
      final decoded = bytes.first == 0
          ? YStructUpdateCodec.decodeV2(bytes)
          : YStructUpdateCodec.decode(bytes);
      expect(decoded.structs.map((value) => (value as YItem).content), [
        isA<YBinaryContent>(),
        isA<YEmbedContent>(),
        isA<YFormatContent>(),
        isA<YTypeContent>(),
        isA<YDocContent>(),
      ]);
    }
  });

  test('remote overlapping ranges converge without false conflicts', () {
    final target = YDoc(clientId: 72);
    final first = YItem(const YId(73, 0), 1, 'a', parent: 'body');
    applyUpdate(
        target, YStructUpdateCodec.encode(YStructUpdate(structs: [first])));
    expect(target.getText('body').text, 'a');

    final expanded = YItem(const YId(73, 0), 2, 'ab', parent: 'body');
    applyUpdate(
        target, YStructUpdateCodec.encode(YStructUpdate(structs: [expanded])));
    expect(target.getText('body').text, 'ab');
    expect(target.store.stateVector[73], 2);

    final suffix = YItem(const YId(73, 1), 1, 'b', parent: 'body');
    applyUpdate(
        target, YStructUpdateCodec.encode(YStructUpdate(structs: [suffix])));
    expect(target.getText('body').text, 'ab');
  });

  test('remote same-clock divergent payloads are rejected', () {
    final target = YDoc(clientId: 71);
    target.getText('text').insert(0, 'a');
    final update = YStructUpdateCodec.encode(YStructUpdate(structs: [
      YItem(const YId(71, 0), 1, 'b', parent: 'text'),
    ]));
    expect(() => applyUpdate(target, update), throwsStateError);
  });

  test('remote DeleteSet removes materialized text', () {
    final source = YDoc(clientId: 72);
    source.getText('text').insert(0, 'abc');
    final target = YDoc(clientId: 73);
    applyUpdate(target, encodeStateAsUpdate(source));
    source.getText('text').delete(1, 1);
    applyUpdate(target, encodeStateAsUpdate(source));
    expect(target.getText('text').text, 'ac');
  });

  test('DeleteSet arriving before its struct remains pending', () {
    for (final v2 in [false, true]) {
      final source = YDoc(clientId: v2 ? 620 : 619);
      source.getText('body').insert(0, 'x');
      final struct = source.store.clients[source.clientId]!.single;
      final deletes = YIdSet()..add(source.clientId, struct.id.clock, 1);
      final deleteOnly = YStructUpdate(deleteSet: deletes);
      final target = YDoc(clientId: v2 ? 622 : 621);
      final encode =
          v2 ? YStructUpdateCodec.encodeV2 : YStructUpdateCodec.encode;
      if (v2) {
        applyUpdateV2(target, encode(deleteOnly), null);
        expect(
            YStructUpdateCodec.decodeV2(encodeStateAsUpdateV2(target))
                .deleteSet
                .covers(source.clientId, struct.id.clock, 1),
            isTrue);
      } else {
        applyUpdate(target, encode(deleteOnly), null);
        expect(
            YStructUpdateCodec.decode(encodeStateAsUpdate(target))
                .deleteSet
                .covers(source.clientId, struct.id.clock, 1),
            isTrue);
      }
      final structOnly = YStructUpdate(structs: [struct]);
      if (v2) {
        applyUpdateV2(target, encode(structOnly), null);
      } else {
        applyUpdate(target, encode(structOnly), null);
      }
      expect(target.getText('body').text, isEmpty,
          reason: 'pending delete must survive V${v2 ? 2 : 1} reordering');
    }
  });

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

  test('public V2 merge and apply update functions preserve the V2 framing',
      () {
    final source = YDoc(clientId: 91);
    source.getText('body').insert(0, 'v2 merge');
    final update = encodeStateAsUpdateV2(source);
    final merged = mergeUpdatesV2([update, update]);
    final decoded = YStructUpdateCodec.decodeV2(merged);
    expect(decoded.structs, hasLength(1));

    final target = YDoc(clientId: 92);
    applyUpdateV2(target, merged, 'merged-v2');
    expect(target.getText('body').text, 'v2 merge');
    expect(mergeUpdatesV2([merged]), merged);
  });

  test('state-vector-from-update and diff-update work for V1 and V2', () {
    final source = YDoc(clientId: 93);
    source.getText('body').insert(0, 'abcdef');
    final v1 = encodeStateAsUpdate(source);
    final v2 = encodeStateAsUpdateV2(source);
    final frontier = YStateVector({93: 3});

    expect(YStateVector.decode(encodeStateVectorFromUpdate(v1))[93], 6);
    expect(YStateVector.decode(encodeStateVectorFromUpdateV2(v2))[93], 6);
    expect(
        (YStructUpdateCodec.decode(diffUpdate(v1, frontier)).structs.single
                as YItem)
            .content,
        'def');
    expect(
        (YStructUpdateCodec.decodeV2(diffUpdateV2(v2, frontier)).structs.single
                as YItem)
            .content,
        'def');
  });

  test('YDoc emits one update event for structs created in a transaction', () {
    final doc = YDoc(clientId: 21);
    final updates = <List<YStruct>>[];
    Object? origin;
    doc.onUpdate((structs, value) {
      updates.add(structs);
      origin = value;
    });
    doc.transact(() {
      doc.recordStruct(length: 1, content: 'a');
      doc.recordStruct(length: 1, content: 'b');
    }, origin: 'local');

    expect(updates, hasLength(1));
    expect(updates.single.map((value) => value.id.clock), [0, 1]);
    expect(origin, 'local');
  });
}
