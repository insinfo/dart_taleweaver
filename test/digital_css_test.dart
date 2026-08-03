import 'package:test/test.dart';
import 'package:taleweaver/src/core/cascade/cascade_pass.dart';
import 'package:taleweaver/src/core/digital/computed_style_to_css.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/styles/style.dart';

void main() {
  test('computed style emits only non-default CSS declarations', () {
    final css = computedStyleToInlineStyle(initialComputedStyle);
    expect(css, isEmpty);
  });

  test('manual page boundaries keep screen and print CSS declarations', () {
    final box = cascadePass(createElementBox(
      'manual-page-break',
      const Style(display: Display.block, breakBefore: BreakBefore.page),
      const [],
    )) as ElementBox;

    final css = computedStyleToInlineStyle(box.computedStyle!);
    expect(css, contains('break-before: page'));
    expect(css, contains('page-break-before: always'));
  });
}
