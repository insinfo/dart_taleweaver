import 'package:test/test.dart';
import 'package:taleweaver/src/yjs/encoding.dart';
import 'package:taleweaver/src/yjs/ids.dart';

void main() {
  test('IdSet merges ranges and answers coverage queries', () {
    final ids = YIdSet();
    ids.add(7, 10, 2);
    ids.add(7, 12, 3);
    ids.add(7, 5, 2);
    expect(ids.clients[7]!.map((range) => [range.clock, range.length]), [
      [5, 2],
      [10, 5],
    ]);
    expect(ids.has(7, 11), isTrue);
    expect(ids.intersects(7, 9, 3), isTrue);
    expect(ids.covers(7, 10, 5), isTrue);
    expect(ids.coveredLength(7, 8, 6), 4);
  });

  test('IdSet deletion splits and slice reports gaps', () {
    final ids = YIdSet()..add(1, 0, 10);
    ids.remove(1, 3, 4);
    expect(ids.slice(1, 0, 10).map((r) => [r.clock, r.length, r.exists]), [
      [0, 3, true],
      [3, 4, false],
      [7, 3, true],
    ]);
    expect(ids.coveredLength(1, 0, 10), 6);
  });

  test('varint codec round-trips signed and unsigned clocks', () {
    final encoder = YEncoder();
    for (final value in [0, 1, 127, 128, 16384, 1 << 31]) {
      encoder.writeVarUint(value);
    }
    for (final value in [-1000, -1, 0, 1, 1000]) {
      encoder.writeVarInt(value);
    }
    final decoder = YDecoder(encoder.toBytes());
    for (final value in [0, 1, 127, 128, 16384, 1 << 31]) {
      expect(decoder.readVarUint(), value);
    }
    for (final value in [-1000, -1, 0, 1, 1000]) {
      expect(decoder.readVarInt(), value);
    }
    expect(decoder.isDone, isTrue);
  });
}
