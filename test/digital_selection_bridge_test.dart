import 'package:test/test.dart';
import 'package:taleweaver/src/core/digital/selection_bridge.dart';
import 'package:taleweaver/src/core/digital/dom_reconciler.dart';

void main() {
  test('selection bridge preserves block ids and UTF-16 offsets', () {
    final selection = selectionFromDomPoints(
        const DomSelectionPoint('p-1', 2), const DomSelectionPoint('p-1', 5));
    expect(selection, isNotNull);
    final points = selectionToDomPoints(selection!);
    expect(points.anchor.blockId, 'p-1');
    expect(points.focus.offset, 5);
  });

  test('selection bridge rejects negative DOM offsets', () {
    expect(
        selectionFromDomPoints(
            const DomSelectionPoint('p', -1), const DomSelectionPoint('p', 0)),
        isNull);
  });

  test('keyed reconciler emits removals, insertions and moves', () {
    final patches = reconcileKeys(['a', 'b', 'c'], ['c', 'a', 'd']);
    expect(patches.where((p) => p.removed).map((p) => p.key), ['b']);
    expect(patches.where((p) => p.inserted).map((p) => p.key), ['d']);
    final moved = patches.firstWhere((p) => p.key == 'c');
    expect(moved.fromIndex, 2);
    expect(moved.toIndex, 0);
  });
}
