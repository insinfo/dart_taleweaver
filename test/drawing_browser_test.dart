@TestOn('browser')

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:taleweaver/taleweaver.dart';

void main() {
  test('browser renderer projects editable boxes and simple shape presentation',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertTextBoxAction(
        text: 'Texto da caixa',
        width: 220,
        height: 88,
        alignment: DrawingAlignment.center,
        fill: '#fff2cc',
        outline: '#b45f06',
        outlineWidth: 2,
      ),
    );
    final textBox = iterateBlocksInDocumentOrder(editor.state)
        .firstWhere((block) => block.type == 'text-box');
    editor = reduceEditor(
      editor,
      const InsertShapeAction(
        DrawingShapeKind.ellipse,
        text: 'Elipse',
        width: 140,
        height: 90,
      ),
    );
    editor = reduceEditor(
      editor,
      const InsertShapeAction(
        DrawingShapeKind.line,
        width: 160,
        height: 20,
        outline: '#ff0000',
        outlineWidth: 3,
      ),
    );
    final shapes = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.type == 'shape')
        .toList();
    final ellipse = shapes.first;
    final line = shapes.last;

    final dom = renderDocumentToDom(
      editor.state,
      createDefaultComponentRegistry(),
      createDefaultAttrRegistry(),
      web.document,
    );
    final box = dom.querySelector('[data-block-id="${textBox.id.value}"]')
        as web.HTMLElement;
    final ellipseElement =
        dom.querySelector('[data-block-id="${ellipse.id.value}"]')
            as web.HTMLElement;
    final lineElement = dom.querySelector('[data-block-id="${line.id.value}"]')
        as web.HTMLElement;

    expect(box.getAttribute('data-tw-drawing'), 'text-box');
    expect(box.getAttribute('data-tw-drawing-align'), 'center');
    expect(box.getAttribute('data-tw-drawing-fill'), '#fff2cc');
    expect(box.textContent, contains('Texto da caixa'));
    expect(box.getAttribute('style'), contains('inline-size: 220px'));

    expect(ellipseElement.getAttribute('data-tw-drawing'), 'ellipse');
    expect(ellipseElement.textContent, contains('Elipse'));
    expect(
        ellipseElement.getAttribute('style'), contains('border-radius: 50%'));

    expect(lineElement.getAttribute('data-tw-drawing'), 'line');
    expect(lineElement.getAttribute('contenteditable'), 'false');
    expect(lineElement.getAttribute('style'), contains('linear-gradient'));
    expect(lineElement.getAttribute('style'), contains('#ff0000'));
  });
}
