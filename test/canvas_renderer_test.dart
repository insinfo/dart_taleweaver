import 'package:test/test.dart';
import 'package:taleweaver/src/core/print/canvas_export.dart';

void main() {
  test('canvas export accepts the supported browser image formats', () {
    expect(isSupportedCanvasImageFormat('image/png'), isTrue);
    expect(isSupportedCanvasImageFormat('image/jpeg'), isTrue);
    expect(isSupportedCanvasImageFormat('image/webp'), isTrue);
    expect(isSupportedCanvasImageFormat('image/gif'), isFalse);
    expect(() => validateCanvasImageFormat('image/gif'), throwsArgumentError);
  });
}
