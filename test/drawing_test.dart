import 'dart:convert';

import 'package:test/test.dart';

import 'package:taleweaver/src/core/components/component_registry.dart';
import 'package:taleweaver/src/core/editor/editor_action.dart';
import 'package:taleweaver/src/core/editor/editor_state.dart';
import 'package:taleweaver/src/core/render/render.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/state/block.dart';
import 'package:taleweaver/src/core/state/block_id.dart';
import 'package:taleweaver/src/core/state/block_position.dart';
import 'package:taleweaver/src/core/state/block_traversal.dart';
import 'package:taleweaver/src/core/state/drawing.dart';
import 'package:taleweaver/src/core/state/inline_content.dart';
import 'package:taleweaver/src/core/state/serialize/json_serializer.dart';
import 'package:taleweaver/src/core/state/state.dart';
import 'package:taleweaver/src/core/styles/length.dart';

void main() {
  Block findBlock(State state, String type) =>
      iterateBlocksInDocumentOrder(state)
          .firstWhere((block) => block.type == type);

  String plainText(Block block) => block.inlineContent!.items
      .whereType<TextItem>()
      .map((item) => item.text)
      .join();

  test('text boxes persist JSON-safe geometry and editable text', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertTextBoxAction(
        text: 'Nota editável',
        width: 240,
        height: 96,
        alignment: DrawingAlignment.center,
        fill: '#fff2cc',
        outline: '#b45f06',
        outlineWidth: 2,
      ),
    );
    final textBox = findBlock(editor.state, 'text-box');
    expect(plainText(textBox), 'Nota editável');
    expect(textBox.attrs, {
      'width': 240.0,
      'height': 96.0,
      'alignment': 'center',
      'fill': '#fff2cc',
      'outline': '#b45f06',
      'outlineWidth': 2.0,
    });
    expect(editor.selection.focus.blockId, textBox.id);
    expect(editor.selection.focus.offset, 'Nota editável'.length);

    editor = reduceEditor(
      editor,
      UpdateDrawingAction(
        textBox.id.value,
        text: 'Rótulo atualizado',
        width: 300,
        alignment: DrawingAlignment.inlineEnd,
        fill: 'transparent',
        outlineWidth: 0,
      ),
    );
    final updated = findBlock(editor.state, 'text-box');
    expect(plainText(updated), 'Rótulo atualizado');
    expect(updated.attrs['width'], 300.0);
    expect(updated.attrs['height'], 96.0);
    expect(updated.attrs['alignment'], 'inline-end');
    expect(updated.attrs['fill'], 'transparent');
    expect(updated.attrs['outlineWidth'], 0.0);
    expect(editor.selection.focus,
        Position(blockId: updated.id, offset: 'Rótulo atualizado'.length));

    final serializer = createJsonDocumentSerializer(
      allocator: createTestAllocator('drawing-json'),
      blockBlockKindResolver: createDefaultComponentRegistry(),
    );
    final encoded = serializer.encode(editor.state);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final root = decoded['root'] as Map<String, dynamic>;
    final boxNode = (root['children'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((node) => node['type'] == 'text-box');
    final attrs = boxNode['attrs'] as Map<String, dynamic>;
    expect(attrs['width'], isA<num>());
    expect(attrs['alignment'], 'inline-end');
    expect(attrs.values.any((value) => value is DrawingProperties), isFalse);

    final roundTrip = serializer.decode(encoded);
    final restored = findBlock(roundTrip, 'text-box');
    expect(plainText(restored), 'Rótulo atualizado');
    expect(restored.attrs['width'], 300.0);
  });

  test(
      'shape reducer accepts labels, rejects unsafe properties, and keeps lines atomic',
      () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertShapeAction(
        DrawingShapeKind.ellipse,
        text: 'Decisão',
        width: 150,
        height: 100,
        fill: '#e7def7',
      ),
    );
    final ellipse = findBlock(editor.state, 'shape');
    expect(ellipse.attrs['shapeKind'], 'ellipse');
    expect(plainText(ellipse), 'Decisão');

    final invalidColor = reduceEditor(
      editor,
      UpdateDrawingAction(ellipse.id.value, fill: 'red; color: black'),
    );
    expect(identical(invalidColor.state, editor.state), isTrue);
    final invalidSize = reduceEditor(
      editor,
      UpdateDrawingAction(ellipse.id.value, width: double.infinity),
    );
    expect(identical(invalidSize.state, editor.state), isTrue);

    editor = reduceEditor(
      editor,
      const InsertShapeAction(DrawingShapeKind.line, text: 'não exibido'),
    );
    final line = iterateBlocksInDocumentOrder(editor.state)
        .where((block) => block.type == 'shape')
        .last;
    expect(line.attrs['shapeKind'], 'line');
    expect(line.inlineContent!.items, isEmpty);
    expect(editor.selection.focus.blockId, isNot(line.id));
    final rejectedText = reduceEditor(
      editor,
      UpdateDrawingAction(line.id.value, text: 'também não'),
    );
    expect(identical(rejectedText.state, editor.state), isTrue);
  });

  test('drawing components produce typed render metadata and styled boxes', () {
    var editor = createInitialEditorState();
    editor = reduceEditor(
      editor,
      const InsertTextBoxAction(text: 'Conteúdo', width: 210, height: 80),
    );
    editor = reduceEditor(
      editor,
      const InsertShapeAction(
        DrawingShapeKind.rectangle,
        text: 'Rótulo',
        outlineWidth: 3,
      ),
    );
    final root = renderState(editor.state, createDefaultComponentRegistry())
        .root as ElementBox;
    final drawings = root.children
        .whereType<ElementBox>()
        .where((box) => box.metadata?.drawing != null)
        .toList();
    expect(drawings, hasLength(2));

    final textBox = drawings.first;
    final textBoxDrawing = textBox.metadata!.drawing!;
    expect(textBoxDrawing.kind, 'text-box');
    expect(textBoxDrawing.acceptsText, isTrue);
    expect(textBoxDrawing.properties.width, 210.0);
    expect(textBox.style.inlineSize, const PxLength(210));
    expect(textBox.style.borderBlockStartWidth, 1.0);
    expect((textBox.children.single as TextBox).text, 'Conteúdo');

    final rectangle = drawings.last;
    final rectangleDrawing = rectangle.metadata!.drawing!;
    expect(rectangleDrawing.kind, 'rectangle');
    expect(rectangleDrawing.properties.outlineWidth, 3.0);
    expect(rectangle.style.backgroundColor, '#d9eaf7');
    expect((rectangle.children.single as TextBox).text, 'Rótulo');
  });
}
