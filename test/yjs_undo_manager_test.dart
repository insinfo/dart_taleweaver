import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/doc.dart';
import 'package:taleweaver/src/yjs/undo_manager.dart';
import 'package:taleweaver/src/yjs/types.dart';

void main() {
  test('undo snapshots preserve YText attributes', () {
    final doc = YDoc(clientId: 74);
    final text = doc.getText('text');
    final undo = YUndoManager(doc);
    undo.transact(() {
      text.insert(0, 'abc');
      text.format(1, 1, {'bold': true});
    });
    undo.stopCapturing();
    text.insert(3, '!');
    undo.undo();
    expect(text.toDelta(), [
      {'insert': 'a'},
      {
        'insert': 'b',
        'attributes': {'bold': true}
      },
      {'insert': 'c'},
    ]);
    undo.redo();
    expect(text.text, 'abc!');
  });

  test('nested formatted YText survives undo restore index rebuild', () {
    final doc = YDoc(clientId: 75);
    final map = doc.getMap('root');
    final nested = YText()..insert(0, 'xy');
    nested.format(0, 1, {'underline': true});
    map.set('text', nested);
    final undo = YUndoManager(doc);
    undo.stopCapturing();
    nested.insert(2, '!');
    undo.undo();
    final restored = map.get('text') as YText;
    expect(restored.toDelta(), [
      {
        'insert': 'x',
        'attributes': {'underline': true}
      },
      {'insert': 'y'},
    ]);
  });
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

  test('default undo manager ignores remote origins', () {
    final doc = YDoc(clientId: 34);
    final manager = YUndoManager(doc);
    manager.beginCapture();
    doc.recordStruct(length: 1, content: 'remote');
    manager.endCapture(origin: 'peer-2');
    expect(manager.canUndo, isFalse);
    manager.beginCapture();
    doc.recordStruct(length: 1, content: 'local');
    manager.endCapture();
    expect(manager.canUndo, isTrue);
  });

  test('undo manager restores materialized shared values', () {
    final doc = YDoc(clientId: 33);
    final text = doc.getText('body');
    final manager = YUndoManager(doc);
    manager.beginCapture();
    text.insert(0, 'hello');
    manager.endCapture();
    expect(text.text, 'hello');
    manager.undo();
    expect(text.text, isEmpty);
    manager.redo();
    expect(text.text, 'hello');
  });

  test('undo manager restores pending delete ranges', () {
    final doc = YDoc(clientId: 35);
    final manager = YUndoManager(doc);
    manager.beginCapture();
    doc.store.pendingDeletes.add(700, 4, 2);
    doc.store.skips.add(701, 8, 3);
    doc.recordStruct(length: 1, content: 'x');
    manager.endCapture();
    expect(doc.store.pendingDeletes.covers(700, 4, 2), isTrue);
    manager.undo();
    expect(doc.store.pendingDeletes.isEmpty, isTrue);
    expect(doc.store.skips.isEmpty, isTrue);
    manager.redo();
    expect(doc.store.pendingDeletes.covers(700, 4, 2), isTrue);
    expect(doc.store.skips.covers(701, 8, 3), isTrue);
  });

  test('undo manager records interval-only causal changes', () {
    final doc = YDoc(clientId: 36);
    final manager = YUndoManager(doc);
    manager.beginCapture();
    doc.store.pendingDeletes.add(702, 10, 1);
    doc.store.skips.add(703, 11, 1);
    manager.endCapture();
    expect(manager.canUndo, isTrue);
    manager.undo();
    expect(doc.store.pendingDeletes.isEmpty, isTrue);
    expect(doc.store.skips.isEmpty, isTrue);
    manager.redo();
    expect(doc.store.pendingDeletes.covers(702, 10, 1), isTrue);
    expect(doc.store.skips.covers(703, 11, 1), isTrue);
  });

  test('undo manager merges captures inside timeout and stopCapturing splits',
      () {
    final doc = YDoc(clientId: 901);
    final text = doc.getText('text');
    final manager = YUndoManager(doc, captureTimeout: 100);
    manager.beginCapture(timestampMs: 0);
    text.insert(0, 'a');
    manager.endCapture(timestampMs: 10);
    manager.beginCapture(timestampMs: 20);
    text.insert(1, 'b');
    manager.endCapture(timestampMs: 30);
    expect(manager.undoStack, hasLength(1));
    manager.stopCapturing();
    manager.beginCapture(timestampMs: 200);
    text.insert(2, 'c');
    manager.endCapture(timestampMs: 210);
    expect(manager.undoStack, hasLength(2));
  });

  test('nested captures commit one outer transaction', () {
    final doc = YDoc(clientId: 902);
    final text = doc.getText('text');
    final manager = YUndoManager(doc);
    manager.beginCapture(timestampMs: 0);
    text.insert(0, 'a');
    manager.beginCapture(timestampMs: 1);
    text.insert(1, 'b');
    manager.endCapture(timestampMs: 2);
    expect(manager.canUndo, isFalse);
    manager.endCapture(timestampMs: 3);
    expect(manager.undoStack, hasLength(1));
    manager.undo();
    expect(text.text, isEmpty);
  });

  test('transact closes capture when operation throws', () {
    final doc = YDoc(clientId: 903);
    final text = doc.getText('text');
    final manager = YUndoManager(doc);
    expect(
        () => manager.transact(() {
              text.insert(0, 'x');
              throw StateError('stop');
            }),
        throwsStateError);
    expect(manager.undoStack, hasLength(1));
    manager.undo();
    expect(text.text, isEmpty);
  });

  test('undo manager captures explicit YDoc transactions automatically', () {
    final doc = YDoc(clientId: 908);
    final text = doc.getText('text');
    final manager = YUndoManager(doc);
    doc.transact(() {
      text.insert(0, 'automatic');
    });
    expect(manager.canUndo, isTrue);
    manager.undo();
    expect(text.text, isEmpty);
  });

  test('undo manager captures direct YText mutations automatically', () {
    final doc = YDoc(clientId: 909);
    final text = doc.getText('text');
    final manager = YUndoManager(doc);
    text.insert(0, 'direct');
    expect(manager.canUndo, isTrue);
    manager.undo();
    expect(text.text, isEmpty);
  });

  test('undo manager captures direct YMap and YArray mutations automatically',
      () {
    final doc = YDoc(clientId: 910);
    final map = doc.getMap('meta');
    final array = doc.getArray('items');
    final manager = YUndoManager(doc);
    map.set('title', 'value');
    manager.stopCapturing();
    array.push([1, 2]);
    expect(manager.undoStack, hasLength(2));
    manager.undo();
    expect(array.toArray(), isEmpty);
    manager.undo();
    expect(map.containsKey('title'), isFalse);
  });

  test('undo manager dispose detaches transaction observers', () {
    final doc = YDoc(clientId: 913);
    final manager = YUndoManager(doc);
    manager.dispose();
    doc.getText('text').insert(0, 'after-dispose');
    expect(manager.canUndo, isFalse);
    expect(manager.canRedo, isFalse);
  });

  test('undo manager preserves nested shared types in typed snapshots', () {
    final doc = YDoc(clientId: 911);
    final root = doc.getMap('root');
    final nested = YMap();
    root.set('nested', nested);
    final manager = YUndoManager(doc);
    manager.stopCapturing();
    nested.set('value', 'before');
    manager.stopCapturing();
    nested.set('value', 'after');
    expect((root.get('nested') as YMap).get('value'), 'after');
    manager.undo();
    expect((root.get('nested') as YMap).get('value'), 'before');
    manager.redo();
    expect((root.get('nested') as YMap).get('value'), 'after');
  });

  test('undo manager restores edits inside shared types embedded in arrays',
      () {
    final doc = YDoc(clientId: 912);
    final items = doc.getArray('items');
    final nested = YText();
    nested.insert(0, 'initial text');
    items.push([nested]);
    final manager = YUndoManager(doc);

    manager.stopCapturing();
    nested.delete(0, nested.length);
    nested.insert(0, 'other text');
    expect((items.get(0) as YText).text, 'other text');

    manager.undo();
    expect(items.get(0), isA<YText>());
    expect((items.get(0) as YText).text, 'initial text');
    manager.redo();
    expect((items.get(0) as YText).text, 'other text');
  });
}
