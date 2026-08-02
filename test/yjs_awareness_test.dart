import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/awareness.dart';

void main() {
  test('awareness clocks reject stale remote state and clone payloads', () {
    final local = YAwareness(clientId: 1);
    final remote = YAwareness(clientId: 2);
    final update = local.setLocalState({
      'user': {'name': 'A'}
    });
    final received = <AwarenessChange>[];
    remote.observe(received.add);
    remote.applyUpdate(update);
    expect(remote.states[1], {
      'user': {'name': 'A'}
    });
    final state = local.localState!;
    (state['user'] as Map)['name'] = 'mutated-copy';
    expect(remote.states[1]!['user'], {'name': 'A'});
    remote.applyUpdate(update);
    expect(received, hasLength(1));
  });

  test('awareness removal is a clocked tombstone and round-trips', () {
    final local = YAwareness(clientId: 3);
    final remote = YAwareness(clientId: 4);
    local.setLocalState({'cursor': 4});
    remote.applyUpdate(local.encodeUpdate());
    final removal = local.removeLocalState();
    final change = remote.applyUpdate(removal);
    expect(change.removed, {3});
    expect(remote.states, isEmpty);
    expect(YAwareness(clientId: 5)..applyUpdate(removal), isA<YAwareness>());
  });

  test('awareness binary updates round-trip through lib0 varuint framing', () {
    final source = YAwareness(clientId: 6)
      ..setLocalState({
        'cursor': {'block': 'p', 'offset': 3}
      });
    final target = YAwareness(clientId: 7);
    final change = target.applyBinaryUpdate(source.encodeBinaryUpdate());
    expect(change.added, {6});
    expect(target.states[6], {
      'cursor': {'block': 'p', 'offset': 3}
    });
    expect(target.encodeBinaryUpdate(), source.encodeBinaryUpdate());
  });

  test('awareness provider delegates delivery to the host transport', () {
    Uint8List? sent;
    final source = YAwarenessProvider(
      awareness: YAwareness(clientId: 8),
      send: (update) => sent = update,
    );
    final target = YAwareness(clientId: 9);
    source.setLocalState({'user': 'B'});
    expect(sent, isNotNull);
    final change = target.applyBinaryUpdate(sent!);
    expect(change.added, {8});
    expect(target.states[8], {'user': 'B'});
  });

  test('in-memory awareness hub converges two connected peers', () {
    final hub = InMemoryAwarenessHub();
    late YAwarenessProvider first;
    late YAwarenessProvider second;
    first = YAwarenessProvider(
      awareness: YAwareness(clientId: 10),
      send: (update) => hub.broadcast(first, update),
    );
    second = YAwarenessProvider(
      awareness: YAwareness(clientId: 11),
      send: (update) => hub.broadcast(second, update),
    );
    hub
      ..connect(first)
      ..connect(second);
    first.setLocalState({'cursor': 1});
    second.setLocalState({'cursor': 2});
    expect(first.awareness.states[11], {'cursor': 2});
    expect(second.awareness.states[10], {'cursor': 1});
    first.removeLocalState();
    expect(second.awareness.states.containsKey(10), isFalse);
  });

  test('in-memory awareness hub syncs presence for a late peer', () {
    final hub = InMemoryAwarenessHub();
    late YAwarenessProvider first;
    first = YAwarenessProvider(
      awareness: YAwareness(clientId: 12),
      send: (update) => hub.broadcast(first, update),
    );
    hub.connect(first);
    first.setLocalState({'cursor': 8});

    late YAwarenessProvider late;
    late = YAwarenessProvider(
      awareness: YAwareness(clientId: 13),
      send: (update) => hub.broadcast(late, update),
    );
    hub.connect(late);
    expect(late.awareness.states[12], {'cursor': 8});
    late.setLocalState({'cursor': 9});
    expect(first.awareness.states[13], {'cursor': 9});
  });

  test('awareness disconnect broadcasts a removal tombstone', () {
    final hub = InMemoryAwarenessHub();
    late YAwarenessProvider first;
    late YAwarenessProvider second;
    first = YAwarenessProvider(
      awareness: YAwareness(clientId: 14),
      send: (update) => hub.broadcast(first, update),
    );
    second = YAwarenessProvider(
      awareness: YAwareness(clientId: 15),
      send: (update) => hub.broadcast(second, update),
    );
    hub.connect(first);
    hub.connect(second);
    first.setLocalState({'cursor': 1});
    expect(second.awareness.states[14], {'cursor': 1});
    hub.disconnect(first);
    expect(second.awareness.states.containsKey(14), isFalse);
  });
}
