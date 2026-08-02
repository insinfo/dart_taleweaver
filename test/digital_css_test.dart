import 'package:test/test.dart';
import 'package:taleweaver/src/core/digital/computed_style_to_css.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';

void main() {
  test('computed style emits only non-default CSS declarations', () {
    final css = computedStyleToInlineStyle(initialComputedStyle);
    expect(css, isEmpty);
  });
}
