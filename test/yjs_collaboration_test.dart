import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/collaboration.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/undo_manager.dart';
import 'package:taleweaver/src/yjs/types.dart';

void main() {
  test('in-memory update hub converges peers and syncs late joins', () {
    final hub = InMemoryYDocHub();
    final left = YDoc(clientId: 501);
    final right = YDoc(clientId: 502);
    late YDocProvider leftProvider;
    late YDocProvider rightProvider;
    leftProvider = YDocProvider(
      doc: left,
      send: (update) => hub.broadcast(leftProvider, update),
      origin: 'left-peer',
    );
    rightProvider = YDocProvider(
      doc: right,
      send: (update) => hub.broadcast(rightProvider, update),
      origin: 'right-peer',
    );
    hub.connect(leftProvider);
    left.getText('body').insert(0, 'hello');
    hub.connect(rightProvider);
    expect(right.getText('body').text, 'hello');

    right.getText('body').insert(5, '!');
    expect(left.getText('body').text, 'hello!');
    leftProvider.dispose();
    rightProvider.dispose();
  });

  test('in-memory update hub transports V2 updates', () {
    final hub = InMemoryYDocHub();
    final left = YDoc(clientId: 503);
    final right = YDoc(clientId: 504);
    late YDocProvider leftProvider;
    late YDocProvider rightProvider;
    leftProvider = YDocProvider(
      doc: left,
      v2: true,
      send: (update) => hub.broadcast(leftProvider, update),
    );
    rightProvider = YDocProvider(
      doc: right,
      v2: true,
      send: (update) => hub.broadcast(rightProvider, update),
    );
    hub.connect(leftProvider);
    hub.connect(rightProvider);
    left.getArray('items').push(['v2']);
    expect(right.getArray('items').toArray(), ['v2']);
    leftProvider.dispose();
    rightProvider.dispose();
  });

  test('peer updates do not enter the receiving undo history', () {
    final hub = InMemoryYDocHub();
    final source = YDoc(clientId: 505);
    final target = YDoc(clientId: 506);
    final targetUndo = YUndoManager(target);
    late YDocProvider sourceProvider;
    late YDocProvider targetProvider;
    sourceProvider = YDocProvider(
      doc: source,
      send: (update) => hub.broadcast(sourceProvider, update),
    );
    targetProvider = YDocProvider(
      doc: target,
      origin: 'peer-505',
      send: (update) => hub.broadcast(targetProvider, update),
    );
    hub.connect(sourceProvider);
    hub.connect(targetProvider);
    source.getText('body').insert(0, 'remote');
    expect(target.getText('body').text, 'remote');
    expect(targetUndo.canUndo, isFalse);
    sourceProvider.dispose();
    targetProvider.dispose();
  });

  test('provider sync is a no-op when the state vector did not change', () {
    final doc = YDoc(clientId: 507);
    final sent = <List<int>>[];
    final provider = YDocProvider(doc: doc, send: sent.add);
    expect(provider.encodeSync(), isEmpty);
    doc.getText('body').insert(0, 'x');
    expect(provider.encodeSync(), isEmpty);
    expect(provider.encodeSync(), isEmpty);
    provider.dispose();
  });

  test('nested shared types converge across peers and late joins', () {
    final hub = InMemoryYDocHub();
    final source = YDoc(clientId: 508);
    final target = YDoc(clientId: 509);
    late YDocProvider sourceProvider;
    late YDocProvider targetProvider;
    sourceProvider = YDocProvider(
      doc: source,
      send: (update) => hub.broadcast(sourceProvider, update),
    );
    targetProvider = YDocProvider(
      doc: target,
      send: (update) => hub.broadcast(targetProvider, update),
    );
    hub.connect(sourceProvider);
    // As in Yjs, the receiving application declares the root shared type
    // before applying updates; this supplies the root container kind for a
    // nested ContentType item whose parent is only the root name.
    target.getArray('items');
    final shared = source.getArray('items');
    final child = YMap();
    child.set('value', 'initial');
    shared.push([child]);
    hub.connect(targetProvider);
    expect(
        (target.getArray('items').get(0) as dynamic).get('value'), 'initial');
    child.set('value', 'one');
    child.set('value', 'two');
    expect((target.getArray('items').get(0) as dynamic).get('value'), 'two');
    sourceProvider.dispose();
    targetProvider.dispose();
  });

  test('prefilled nested text converges across peers', () {
    final hub = InMemoryYDocHub();
    final source = YDoc(clientId: 510);
    final target = YDoc(clientId: 511);
    late YDocProvider sourceProvider;
    late YDocProvider targetProvider;
    sourceProvider = YDocProvider(
      doc: source,
      send: (update) => hub.broadcast(sourceProvider, update),
    );
    targetProvider = YDocProvider(
      doc: target,
      send: (update) => hub.broadcast(targetProvider, update),
    );
    hub.connect(sourceProvider);
    target.getArray('items');
    final nested = YText()..insert(0, 'prefilled');
    final nestedMap = YMap()..set('value', 'initial');
    source.getArray('items').push([nestedMap, nested]);
    hub.connect(targetProvider);
    expect((target.getArray('items').get(0) as YMap).get('value'), 'initial');
    expect((target.getArray('items').get(1) as YText).text, 'prefilled');
    sourceProvider.dispose();
    targetProvider.dispose();
  });

  test('prefilled nested types converge through the V2 provider handshake', () {
    final hub = InMemoryYDocHub();
    final source = YDoc(clientId: 512);
    final target = YDoc(clientId: 513);
    late YDocProvider sourceProvider;
    late YDocProvider targetProvider;
    sourceProvider = YDocProvider(
      doc: source,
      v2: true,
      send: (update) => hub.broadcast(sourceProvider, update),
    );
    targetProvider = YDocProvider(
      doc: target,
      v2: true,
      send: (update) => hub.broadcast(targetProvider, update),
    );
    hub.connect(sourceProvider);
    target.getArray('items');
    final nestedMap = YMap()..set('value', 'v2');
    final nestedText = YText()..insert(0, 'text-v2');
    source.getArray('items').push([nestedMap, nestedText]);
    hub.connect(targetProvider);
    expect((target.getArray('items').get(0) as YMap).get('value'), 'v2');
    expect((target.getArray('items').get(1) as YText).text, 'text-v2');
    sourceProvider.dispose();
    targetProvider.dispose();
  });
}
