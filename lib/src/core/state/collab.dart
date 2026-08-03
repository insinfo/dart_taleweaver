/// Collaboration observers over the shared document transaction stream.
library;

import 'block_id.dart';
import 'state.dart';
import 'tw_doc.dart';

typedef ForeignChangeCallback = void Function(Set<BlockId> dirtyIds);

/// Observes only transactions whose origin differs from [selfOrigin].
///
/// The observer ignores transactions without dirty blocks and returns an
/// idempotent unsubscribe callback. Origins are strings in the Dart document
/// model; hosts should allocate one stable value per editor instance.
VoidCallback subscribeForeignChanges(
  State state,
  String? selfOrigin,
  ForeignChangeCallback onForeignChange,
) {
  late final AfterTransactionCallback listener;
  listener = (dirtyIds, origin) {
    if (origin == selfOrigin || dirtyIds.isEmpty) return;
    onForeignChange(dirtyIds.map(BlockId.new).toSet());
  };
  state.doc.onAfterTransaction(listener);
  var subscribed = true;
  return () {
    if (!subscribed) return;
    subscribed = false;
    state.doc.offAfterTransaction(listener);
  };
}

typedef VoidCallback = void Function();
