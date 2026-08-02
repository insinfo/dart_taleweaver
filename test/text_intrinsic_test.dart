import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/layout/text_intrinsic.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';

void main() {
  test('intrinsic widths expose widest word and unwrapped width', () {
    final result = measureIntrinsicText(
        'hi taleweaver', createMockShaper(10, 20), initialComputedStyle);
    expect(result.minContent, 10);
    expect(result.maxContent, 100);
  });
}
