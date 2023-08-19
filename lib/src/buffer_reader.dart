// ignore_for_file: public_member_api_docs

import "dart:typed_data";

class BufferReader {
  final ByteData _byteData;
  int _position = 0;

  int get position => _position;

  int get remaining => _byteData.lengthInBytes - _position;

  BufferReader(this._byteData);

  void advance(int count) {
    _position += count;
  }

  bool tryAdvance(int count) {
    if (!_hasEnoughBuffer(count)) {
      return false;
    }

    advance(count);
    return true;
  }

  // ignore: use_setters_to_change_properties
  void advanceTo(int position) {
    _position = position;
  }

  int? tryPeekInt8() {
    if (!_hasEnoughBuffer(1)) {
      return null;
    }

    return _byteData.getInt8(_position);
  }

  int? tryPeekInt16([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(2)) {
      return null;
    }

    return _byteData.getInt16(_position, endian);
  }

  int? tryPeekInt32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    return _byteData.getInt32(_position, endian);
  }

  int? tryPeekInt64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    return _byteData.getInt64(_position, endian);
  }

  int? tryPeekUint8() {
    if (!_hasEnoughBuffer(1)) {
      return null;
    }

    return _byteData.getUint8(_position);
  }

  int? tryPeekUint16([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(2)) {
      return null;
    }

    return _byteData.getUint16(_position, endian);
  }

  int? tryPeekUint32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    return _byteData.getUint32(_position, endian);
  }

  int? tryPeekUint64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    return _byteData.getUint64(_position, endian);
  }

  double? tryPeekFloat32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    return _byteData.getFloat32(_position, endian);
  }

  double? tryPeekFloat64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    return _byteData.getFloat64(_position, endian);
  }

  int? tryReadInt8() {
    if (!_hasEnoughBuffer(1)) {
      return null;
    }

    int value = _byteData.getInt8(_position);
    advance(1);

    return value;
  }

  int? tryReadInt16([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(2)) {
      return null;
    }

    int value = _byteData.getInt16(_position, endian);
    advance(2);

    return value;
  }

  int? tryReadInt32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    int value = _byteData.getInt32(_position, endian);
    advance(4);

    return value;
  }

  int? tryReadInt64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    int value = _byteData.getInt64(_position, endian);
    advance(8);

    return value;
  }

  int? tryReadUint8() {
    if (!_hasEnoughBuffer(1)) {
      return null;
    }

    int value = _byteData.getUint8(_position);
    advance(1);

    return value;
  }

  int? tryReadUint16([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(2)) {
      return null;
    }

    int value = _byteData.getUint16(_position, endian);
    advance(2);

    return value;
  }

  int? tryReadUint32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    int value = _byteData.getUint32(_position, endian);
    advance(4);

    return value;
  }

  int? tryReadUint64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    int value = _byteData.getUint64(_position, endian);
    advance(8);

    return value;
  }

  double? tryReadFloat32([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(4)) {
      return null;
    }

    double value = _byteData.getFloat32(_position, endian);
    advance(4);

    return value;
  }

  double? tryReadFloat64([Endian endian = Endian.big]) {
    if (!_hasEnoughBuffer(8)) {
      return null;
    }

    double value = _byteData.getFloat64(_position, endian);
    advance(8);

    return value;
  }

  Uint8List slice(int length, [int? position]) => _byteData.buffer.asUint8List(
        (position ?? _position) + _byteData.offsetInBytes,
        length,
      );

  bool _hasEnoughBuffer(int size) =>
      _position + size <= _byteData.lengthInBytes;
}
