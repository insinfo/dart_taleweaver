import 'package:test/test.dart';
import 'package:taleweaver/src/core/print/layout/field_convergence.dart';
import 'package:taleweaver/src/core/render/layout_metadata.dart';
import 'package:taleweaver/src/core/render/render_node.dart';
import 'package:taleweaver/src/core/styles/style.dart';

void main() {
  test('grows reservations until every resolved value fits', () {
    final passes = <Map<String, double>>[];
    final outcome = runFieldConvergence(
      const [ConvergenceField('field', 2)],
      (widths) {
        passes.add(Map.of(widths));
        final reserved = widths['field'] ?? 2;
        return ConvergenceIteration(
            reserved < 6 ? 2 : 3, {'field': reserved < 6 ? 6 : 6});
      },
    );
    expect(passes, [
      <String, double>{},
      {'field': 6}
    ]);
    expect(outcome.grownWidths['field'], 6);
    expect(outcome.iterations, 2);
    expect(outcome.converged, isTrue);
  });

  test('bounds continuously growing measurements at the iteration cap', () {
    var calls = 0;
    final outcome = runFieldConvergence(
      const [ConvergenceField('field', 1)],
      (widths) {
        calls++;
        return ConvergenceIteration(
            calls.isOdd ? 2 : 3, {'field': 3 + calls.toDouble()});
      },
      maxIterations: 4,
    );
    expect(calls, 4);
    expect(outcome.iterations, 4);
    expect(outcome.converged, isFalse);
    expect(outcome.grownWidths['field'], 6);
  });

  test('no fields execute exactly one pass', () {
    var calls = 0;
    final outcome = runFieldConvergence<ConvergenceIteration>(const [], (_) {
      calls++;
      return ConvergenceIteration(1, const {});
    });
    expect(calls, 1);
    expect(outcome.converged, isTrue);
  });

  test('collects page-field placeholders by stable render key', () {
    final tree = ElementBox(
      key: 'template',
      style: const Style(),
      metadata: null,
      children: [
        ElementBox(
          key: 'header/inline/0',
          style: const Style(),
          metadata: const LayoutBoxMetadata(
              embedType: 'page-field', fieldKind: 'page-number'),
          children: const [],
        ),
      ],
    );
    final fields = collectPageFields(tree, reservedWidth: 12);
    expect(fields, hasLength(1));
    expect(fields.single.embedKey, 'header/inline/0');
    expect(fields.single.reservedWidth, 12);
  });
}
