import 'package:test/test.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/state/collab.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/tw_doc.dart';

void main() {
  test('subscribeForeignChanges reports dirty blocks from foreign origins', () {
    final state = createInitialEditorState().state;
    final seen = <Set<BlockId>>[];
    final unsubscribe = subscribeForeignChanges(state, 'self', seen.add);

    applyOperation(state, (doc) {
      doc.setBlockField(state.rootId.value, 'attrs', {'remote': true});
    }, origin: 'peer');

    expect(seen, hasLength(1));
    expect(seen.single, contains(state.rootId));
    unsubscribe();
  });

  test('subscribeForeignChanges ignores self and stops after unsubscribe', () {
    final state = createInitialEditorState().state;
    var calls = 0;
    final unsubscribe = subscribeForeignChanges(state, 'self', (_) => calls++);

    applyOperation(state, (doc) {
      doc.setBlockField(state.rootId.value, 'attrs', {'self': true});
    }, origin: 'self');
    expect(calls, 0);

    unsubscribe();
    applyOperation(state, (doc) {
      doc.setBlockField(state.rootId.value, 'attrs', {'after': true});
    }, origin: 'peer');
    expect(calls, 0);
  });

  test('ambient transaction origin filters matching observers', () {
    final state = createInitialEditorState().state;
    var calls = 0;
    final unsubscribe =
        subscribeForeignChanges(state, 'peer-a', (_) => calls++);

    runWithTransactionOrigin('peer-a', () {
      applyOperation(state, (doc) {
        doc.setBlockField(state.rootId.value, 'attrs', {'ambient': true});
      });
    });
    expect(calls, 0);

    runWithTransactionOrigin('peer-b', () {
      applyOperation(state, (doc) {
        doc.setBlockField(state.rootId.value, 'attrs', {'foreign': true});
      });
    });
    expect(calls, 1);
    unsubscribe();
  });
}
