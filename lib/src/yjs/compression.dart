library;

import 'encoding.dart';

class YRleByteEncoder {
  final YEncoder _encoder = YEncoder();
  int? _state;
  int _count = 0;

  void write(int value) {
    if (_state == value) {
      _count++;
      return;
    }
    if (_count > 0) _encoder.writeVarUint(_count - 1);
    _state = value;
    _count = 1;
    _encoder.writeUint8(value);
  }

  List<int> toBytes() => _encoder.toBytes();
}

class YRleByteDecoder {
  final YDecoder _decoder;
  int _state = 0;
  int _count = 0;

  YRleByteDecoder(Iterable<int> bytes) : _decoder = YDecoder(bytes);

  int read() {
    if (_count == 0) {
      _state = _decoder.readUint8();
      _count = _decoder.isDone ? -1 : _decoder.readVarUint() + 1;
    }
    _count--;
    return _state;
  }
}

class YUintOptRleEncoder {
  final YEncoder _encoder = YEncoder();
  int _state = 0;
  int _count = 0;

  void write(int value) {
    if (_state == value) {
      _count++;
    } else {
      _flush();
      _state = value;
      _count = 1;
    }
  }

  void _flush() {
    if (_count == 0) return;
    _encoder.writeVarIntWithSign(_state, negative: _count > 1);
    if (_count > 1) _encoder.writeVarUint(_count - 2);
  }

  List<int> toBytes() {
    _flush();
    return _encoder.toBytes();
  }
}

class YUintOptRleDecoder {
  final YDecoder _decoder;
  int _state = 0;
  int _count = 0;

  YUintOptRleDecoder(Iterable<int> bytes) : _decoder = YDecoder(bytes);

  int read() {
    if (_count == 0) {
      final encoded = _decoder.readVarIntWithSign();
      _state = encoded.value.abs();
      _count = encoded.negative ? _decoder.readVarUint() + 2 : 1;
    }
    _count--;
    return _state;
  }
}

class YIntDiffOptRleEncoder {
  final YEncoder _encoder = YEncoder();
  int _state = 0;
  int _count = 0;
  int _diff = 0;

  void write(int value) {
    if (_diff == value - _state) {
      _state = value;
      _count++;
    } else {
      _flush();
      _count = 1;
      _diff = value - _state;
      _state = value;
    }
  }

  void _flush() {
    if (_count == 0) return;
    _encoder.writeVarInt(_diff * 2 + (_count == 1 ? 0 : 1));
    if (_count > 1) _encoder.writeVarUint(_count - 2);
  }

  List<int> toBytes() {
    _flush();
    return _encoder.toBytes();
  }
}

class YIntDiffOptRleDecoder {
  final YDecoder _decoder;
  int _state = 0;
  int _count = 0;
  int _diff = 0;

  YIntDiffOptRleDecoder(Iterable<int> bytes) : _decoder = YDecoder(bytes);

  int read() {
    if (_count == 0) {
      final encoded = _decoder.readVarInt();
      final hasCount = (encoded & 1) != 0;
      _diff = (encoded / 2).floor();
      _count = hasCount ? _decoder.readVarUint() + 2 : 1;
    }
    _state += _diff;
    _count--;
    return _state;
  }
}

class YStringEncoder {
  final StringBuffer _strings = StringBuffer();
  final YUintOptRleEncoder _lengths = YUintOptRleEncoder();

  void write(String value) {
    _strings.write(value);
    _lengths.write(value.length);
  }

  List<int> toBytes() => (YEncoder()
        ..writeString(_strings.toString())
        ..writeBytes(_lengths.toBytes()))
      .toBytes();
}

class YStringDecoder {
  late final YUintOptRleDecoder _lengths;
  late final String _value;
  int _offset = 0;

  YStringDecoder(Iterable<int> bytes) {
    final decoder = YDecoder(bytes);
    _value = decoder.readString();
    _lengths = YUintOptRleDecoder(decoder.readTail());
  }

  String read() {
    final end = _offset + _lengths.read();
    final result = _value.substring(_offset, end);
    _offset = end;
    return result;
  }
}
