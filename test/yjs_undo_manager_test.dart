import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/undo_manager.dart';

void main() {
  test('undo manager restores store snapshots and supports redo', () {
    final doc = YDoc(clientId: 31);
    final manager = YUndoManager(doc);
    manager.beginCapture();
    doc.recordStruct(length: 1, content: 'a');
    manager.endCapture();
    expect(doc.store.getClock(31), 1);
    manager.undo();
    expect(doc.store.getClock(31), 0);
    manager.redo();
    expect(doc.store.getClock(31), 1);
  });

  test('undo manager ignores untracked origins', () {
    final doc = YDoc(clientId: 32);
    final manager = YUndoManager(doc, trackedOrigins: {'local'});
    manager.beginCapture();
    doc.recordStruct(length: 1, content: 'remote');
    manager.endCapture(origin: 'remote');
    expect(manager.canUndo, isFalse);
  });
}
