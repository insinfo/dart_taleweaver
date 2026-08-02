import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/id.dart';

void main() {
  test('YId uses client and clock as its identity', () {
    expect(const YId(4, 8), const YId(4, 8));
    expect(const YId(4, 8), isNot(const YId(5, 8)));
  });

  test('state vectors round-trip sorted client clocks', () {
    final vector = YStateVector()
      ..[99] = 4
      ..[2] = 17
      ..[7] = 1;
    final decoded = YStateVector.decode(vector.encode());

    expect(decoded, vector);
    expect(decoded.clocks.keys, [2, 7, 99]);
  });

  test('zero clock removes a state-vector entry', () {
    final vector = YStateVector({1: 3});
    vector[1] = 0;
    expect(vector.clocks, isEmpty);
  });
}
