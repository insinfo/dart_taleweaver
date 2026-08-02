library;

import 'doc.dart';
import 'id.dart';
import 'structs.dart';
import 'update_codec.dart';

typedef YUpdateSend = void Function(List<int> update);

/// Host transport adapter for YDoc updates. The provider keeps a state-vector
/// frontier so only newly-created structs are sent after the first emission.
class YDocProvider {
  final YDoc doc;
  final YUpdateSend send;
  final bool v2;
  final Object origin;
  YStateVector _sent = YStateVector(const {});

  YDocProvider(
      {required this.doc,
      required this.send,
      this.v2 = false,
      this.origin = 'remote'}) {
    doc.onUpdate(_onUpdate);
  }

  List<int> encodeSync() {
    final current = doc.store.stateVector;
    if (current == _sent) return const [];
    final update = v2
        ? encodeStateAsUpdateV2(doc, _sent)
        : encodeStateAsUpdate(doc, _sent);
    _sent = current;
    return update;
  }

  List<int> encodeFull() =>
      v2 ? encodeStateAsUpdateV2(doc) : encodeStateAsUpdate(doc);

  void sync() {
    final update = encodeSync();
    if (update.isNotEmpty) send(update);
  }

  void receive(List<int> update) {
    if (v2) {
      applyUpdateV2(doc, update, origin);
    } else {
      applyUpdate(doc, update, origin);
    }
    _sent = doc.store.stateVector;
  }

  void dispose() => doc.offUpdate(_onUpdate);

  void _onUpdate(List<YStruct> structs, Object? transactionOrigin) {
    final update = encodeSync();
    if (update.isNotEmpty) send(update);
  }
}

/// Deterministic in-memory update transport, useful for tests and local
/// multi-document collaboration. Newly connected peers receive full sync.
class InMemoryYDocHub {
  final Set<YDocProvider> _providers = {};

  void connect(YDocProvider provider) {
    if (!_providers.add(provider)) return;
    for (final other in List<YDocProvider>.of(_providers)) {
      if (identical(other, provider)) continue;
      // Capture the new peer's local frontier before applying the existing
      // peer's full state. Otherwise encodeFull() would echo the just-
      // received structs back to the old peer during the same handshake.
      final toOther = provider.encodeFull();
      final toNew = other.encodeFull();
      if (toNew.isNotEmpty) provider.receive(toNew);
      if (toOther.isNotEmpty) other.receive(toOther);
    }
  }

  void disconnect(YDocProvider provider) => _providers.remove(provider);

  void broadcast(YDocProvider source, List<int> update) {
    for (final provider in List<YDocProvider>.of(_providers)) {
      if (!identical(provider, source)) provider.receive(update);
    }
  }
}
