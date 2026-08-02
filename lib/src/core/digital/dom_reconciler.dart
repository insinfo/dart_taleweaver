/// Keyed, DOM-free reconciliation plan used by browser adapters.
library;

class DomReconcilePatch {
  final String key;
  final int? fromIndex;
  final int? toIndex;
  final bool inserted;
  final bool removed;

  const DomReconcilePatch({
    required this.key,
    this.fromIndex,
    this.toIndex,
    this.inserted = false,
    this.removed = false,
  });
}

/// Computes a stable keyed child patch without touching browser APIs.
///
/// The browser adapter can apply these patches to actual `Element.children`;
/// keeping the diff pure makes selection/reconciler behavior deterministic in
/// Dart tests and mirrors the key-based strategy of the TypeScript backend.
List<DomReconcilePatch> reconcileKeys(
    List<String> previous, List<String> next) {
  final oldPositions = <String, int>{};
  for (var i = 0; i < previous.length; i++) {
    oldPositions[previous[i]] = i;
  }
  final nextSet = next.toSet();
  final patches = <DomReconcilePatch>[];
  for (var i = 0; i < previous.length; i++) {
    final key = previous[i];
    if (!nextSet.contains(key)) {
      patches.add(DomReconcilePatch(key: key, fromIndex: i, removed: true));
    }
  }
  for (var i = 0; i < next.length; i++) {
    final key = next[i];
    final from = oldPositions[key];
    if (from == null) {
      patches.add(DomReconcilePatch(key: key, toIndex: i, inserted: true));
    } else if (from != i) {
      patches.add(DomReconcilePatch(key: key, fromIndex: from, toIndex: i));
    }
  }
  return patches;
}
