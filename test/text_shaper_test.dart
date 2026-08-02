import 'package:test/test.dart';
import 'package:taleweaver/src/core/layout/mock_shaper.dart';
import 'package:taleweaver/src/core/layout/text_measurer.dart';
import 'package:taleweaver/src/core/styles/property_meta.dart';
import 'package:taleweaver/src/core/styles/writing_mode.dart';

void main() {
  test('mock shaper produces grapheme clusters and break opportunities', () {
    final shaper = createMockShaper(10, 20);
    final run = shaper.shape('a😀 b', initialComputedStyle, Direction.ltr);
    expect(run.clusters.map((cluster) => [cluster.start, cluster.end]), [
      [0, 1],
      [1, 3],
      [3, 4],
      [4, 5],
    ]);
    expect(run.unbreakableRunInlineSize, 40);
    expect(run.breakOpportunities.single.clusterIndex, 4);
    expect(run.ascent + run.descent + run.lineGap, 20);
  });

  test('text measurer adapts shaper metrics', () {
    final measurer = createMockMeasurer(8, 16);
    expect(measurer.measureWidth('abc', initialComputedStyle), 24);
    expect(measurer.measureHeight(initialComputedStyle), 16);
  });
}
