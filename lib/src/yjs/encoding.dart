library;

class YEncoder {
  final List<int> _bytes = [];

  void writeVarUint(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    var remaining = value;
    while (remaining > 0x7f) {
      _bytes.add((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    _bytes.add(remaining);
  }

  void writeVarInt(int value) {
    final zigzag = value >= 0 ? value * 2 : (-value * 2) - 1;
    writeVarUint(zigzag);
  }

  void writeBytes(List<int> bytes) => _bytes.addAll(bytes);
  List<int> toBytes() => List<int>.unmodifiable(_bytes);
}

class YDecoder {
  final List<int> _bytes;
  int _offset = 0;
  YDecoder(Iterable<int> bytes) : _bytes = List<int>.of(bytes);

  int readVarUint() {
    var value = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _bytes.length || shift > 63)
        throw FormatException('Invalid varuint');
      final byte = _bytes[_offset++];
      value |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return value;
      shift += 7;
    }
  }

  int readVarInt() {
    final value = readVarUint();
    return (value & 1) == 0 ? value ~/ 2 : -((value + 1) ~/ 2);
  }

  List<int> readBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw FormatException('Unexpected end of input');
    }
    final result = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }

  bool get isDone => _offset == _bytes.length;
}
