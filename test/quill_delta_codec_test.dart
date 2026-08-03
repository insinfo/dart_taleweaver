import 'package:taleweaver/taleweaver.dart';
import 'package:test/test.dart';

void main() {
  group('QuillDeltaCodec', () {
    test('round-trips the supported formatted document subset', () {
      final state = decodeQuillDelta({
        'ops': [
          {
            'insert': 'Título',
            'attributes': {'bold': true, 'font': 'Calibri', 'size': 18},
          },
          {
            'insert': '\n',
            'attributes': {'header': 2, 'align': 'center'},
          },
          {'insert': 'Item'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'Normal'},
          {'insert': '\n'},
        ],
      });

      final leaves = iterateLeafBlocksInDocumentOrder(state).toList();
      expect(leaves.map((block) => block.type),
          ['heading', 'list-item', 'paragraph']);
      expect(leaves.first.attrs['level'], 2);
      expect(leaves.first.attrs['textAlign'], 'center');
      final title = leaves.first.inlineContent!.items.single as TextItem;
      expect(title.text, 'Título');
      expect(title.attrs['bold'], isTrue);
      expect(title.attrs['fontFamily'], 'Calibri');
      expect(title.attrs['fontSize'], 18);

      final exported = encodeQuillDelta(state);
      expect(exported[0], {
        'insert': 'Título',
        'attributes': {'bold': true, 'font': 'Calibri', 'size': 18},
      });
      expect(exported[1], {
        'insert': '\n',
        'attributes': {'align': 'center', 'header': 2},
      });
      expect(exported[3], {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      });
    });

    test('rejects document features that Delta cannot preserve', () {
      expect(
        () => decodeQuillDelta([
          {
            'insert': {'image': 'https://example.test/image.png'},
          },
        ]),
        throwsA(isA<UnsupportedQuillDeltaError>()),
      );
      expect(
        () => decodeQuillDelta([
          {'retain': 3},
        ]),
        throwsA(isA<UnsupportedQuillDeltaError>()),
      );
    });
  });
}
