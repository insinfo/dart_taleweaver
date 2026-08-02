library;

import 'dart:convert';
import 'dart:typed_data';

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
    writeVarIntWithSign(value.abs(), negative: value < 0);
  }

  void writeVarIntWithSign(int value, {required bool negative}) {
    var remaining = value;
    _bytes.add((remaining > 0x3f ? 0x80 : 0) |
        (negative ? 0x40 : 0) |
        (remaining & 0x3f));
    remaining ~/= 64;
    while (remaining > 0) {
      _bytes.add((remaining > 0x7f ? 0x80 : 0) | (remaining & 0x7f));
      remaining ~/= 128;
    }
  }

  void writeUint8(int value) => _bytes.add(value & 0xff);

  void writeString(String value) {
    final bytes = utf8.encode(value);
    writeVarUint(bytes.length);
    writeBytes(bytes);
  }

  void writeAny(dynamic value) {
    if (value == null) {
      writeUint8(126);
    } else if (value == false) {
      writeUint8(121);
    } else if (value == true) {
      writeUint8(120);
    } else if (value is int && value.abs() <= 0x7fffffff) {
      writeUint8(125);
      writeVarInt(value);
    } else if (value is num) {
      final number = value.toDouble();
      final float = ByteData(4)..setFloat32(0, number, Endian.big);
      if (float.getFloat32(0, Endian.big) == number) {
        writeUint8(124);
        writeBytes(float.buffer.asUint8List());
      } else {
        writeUint8(123);
        writeBytes((ByteData(8)..setFloat64(0, number, Endian.big))
            .buffer
            .asUint8List());
      }
    } else if (value is String) {
      writeUint8(119);
      writeString(value);
    } else if (value is Uint8List) {
      writeUint8(116);
      writeVarUint(value.length);
      writeBytes(value);
    } else if (value is List) {
      writeUint8(117);
      writeVarUint(value.length);
      for (final item in value) writeAny(item);
    } else if (value is Map) {
      writeUint8(118);
      writeVarUint(value.length);
      for (final entry in value.entries) {
        writeString(entry.key.toString());
        writeAny(entry.value);
      }
    } else {
      throw ArgumentError.value(value, 'value', 'Unsupported lib0 value');
    }
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
    return readVarIntWithSign().value;
  }

  ({int value, bool negative}) readVarIntWithSign() {
    if (_offset >= _bytes.length) throw FormatException('Invalid varint');
    var byte = _bytes[_offset++];
    final negative = (byte & 0x40) != 0;
    var value = byte & 0x3f;
    var shift = 6;
    while ((byte & 0x80) != 0) {
      if (_offset >= _bytes.length || shift > 63) {
        throw FormatException('Invalid varint');
      }
      byte = _bytes[_offset++];
      value |= (byte & 0x7f) << shift;
      shift += 7;
    }
    return (value: negative ? -value : value, negative: negative);
  }

  int readUint8() {
    if (_offset >= _bytes.length) throw FormatException('Unexpected end');
    return _bytes[_offset++];
  }

  String readString() {
    final length = readVarUint();
    return utf8.decode(readBytes(length));
  }

  dynamic readAny() {
    final tag = readUint8();
    return switch (tag) {
      126 => null,
      121 => false,
      120 => true,
      125 => readVarInt(),
      124 => ByteData.sublistView(Uint8List.fromList(readBytes(4)))
          .getFloat32(0, Endian.big),
      123 => ByteData.sublistView(Uint8List.fromList(readBytes(8)))
          .getFloat64(0, Endian.big),
      119 => readString(),
      116 => Uint8List.fromList(readBytes(readVarUint())),
      117 => List<dynamic>.generate(readVarUint(), (_) => readAny()),
      118 => _readObject(),
      _ => throw FormatException('Unsupported lib0 any tag $tag'),
    };
  }

  Map<String, dynamic> _readObject() {
    final result = <String, dynamic>{};
    final length = readVarUint();
    for (var i = 0; i < length; i++) result[readString()] = readAny();
    return result;
  }

  List<int> readBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw FormatException('Unexpected end of input');
    }
    final result = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }

  int get remaining => _bytes.length - _offset;
  List<int> readTail() => readBytes(remaining);
  bool get isDone => _offset == _bytes.length;
}
