import "dart:convert";
import "dart:typed_data";

import "buffer_reader.dart";
import "date_time_constants.dart";
import "end_of_stream_exception.dart";
import "extension_header.dart";
import "extension_result.dart";
import "message_pack_code.dart";
import "message_pack_serialization_exception.dart";
import "message_pack_type.dart";
import "nil.dart";
import "reserved_message_pack_extension_type_code.dart";

class MessagePackReader {
  final BufferReader _reader;

  int get position => _reader.position;

  int get remaining => _reader.remaining;

  bool get end => _reader.remaining == 0;

  bool get isNil => nextCode == MessagePackCode.nil;

  MessagePackType get nextMessagePackType =>
      MessagePackCode.toMessagePackType(nextCode);

  /// Gets the next value in the buffer without advancing
  int get nextCode {
    int? value = _reader.tryPeekUint8();
    _throwInsufficientBufferUnless(value != null);

    return value!;
  }

  MessagePackReader(ByteBuffer data)
      : _reader = BufferReader(data.asByteData());

  MessagePackReader.fromList(List<int> buffer)
      : this.fromTypedData(Uint8List.fromList(buffer));

  MessagePackReader.fromTypedData(TypedData data)
      : _reader = BufferReader(
          ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
        );

  // Reader(
  //   this.data, [
  //   int start = 0,
  //   int? end,
  // ]) : _reader = BufferReader(ByteData.sublistView(
  //         data,
  //         start,
  //         end,
  //       ));

  // Reader.fromBuffer(
  //   ByteBuffer buffer, [
  //   int offsetInBytes = 0,
  //   int? length,
  // ]) : _reader = BufferReader(ByteData.view(
  //         buffer,
  //         offsetInBytes,
  //         length,
  //       ));

  void skip() {
    _throwInsufficientBufferUnless(trySkip());
  }

  bool trySkip() {
    if (_reader.remaining == 0) {
      return false;
    }

    int code = nextCode;
    switch (code) {
      case MessagePackCode.nil:
      case MessagePackCode.true_:
      case MessagePackCode.false_:
        return _reader.tryAdvance(1);
      case MessagePackCode.int8:
      case MessagePackCode.uint8:
        return _reader.tryAdvance(2);
      case MessagePackCode.int16:
      case MessagePackCode.uint16:
        return _reader.tryAdvance(3);
      case MessagePackCode.int32:
      case MessagePackCode.uint32:
      case MessagePackCode.float32:
        return _reader.tryAdvance(5);
      case MessagePackCode.int64:
      case MessagePackCode.uint64:
      case MessagePackCode.float64:
        return _reader.tryAdvance(9);
      case MessagePackCode.map16:
      case MessagePackCode.map32:
        return _trySkipNextMap();
      case MessagePackCode.array16:
      case MessagePackCode.array32:
        return _trySkipNextArray();
      case MessagePackCode.str8:
      case MessagePackCode.str16:
      case MessagePackCode.str32:
        int? length = _tryGetStringLengthInBytes();
        return length != null && _reader.tryAdvance(length);
      case MessagePackCode.bin8:
      case MessagePackCode.bin16:
      case MessagePackCode.bin32:
        int? length = _tryGetBytesLength();
        return length != null && _reader.tryAdvance(length);
      case MessagePackCode.fixExt1:
      case MessagePackCode.fixExt2:
      case MessagePackCode.fixExt4:
      case MessagePackCode.fixExt8:
      case MessagePackCode.fixExt16:
      case MessagePackCode.ext8:
      case MessagePackCode.ext16:
      case MessagePackCode.ext32:
        ExtensionHeader? header = tryReadExtensionFormatHeader();
        return header != null && _reader.tryAdvance(header.length);
      default:
        if ((code >= MessagePackCode.minNegativeFixInt &&
                code <= MessagePackCode.maxNegativeFixInt) ||
            (code >= MessagePackCode.minFixInt &&
                code <= MessagePackCode.maxFixInt)) {
          return _reader.tryAdvance(1);
        }

        if (code >= MessagePackCode.minFixMap &&
            code <= MessagePackCode.maxFixMap) {
          return _trySkipNextMap();
        }

        if (code >= MessagePackCode.minFixArray &&
            code <= MessagePackCode.maxFixArray) {
          return _trySkipNextArray();
        }

        if (code >= MessagePackCode.minFixStr &&
            code <= MessagePackCode.maxFixStr) {
          int? length = _tryGetStringLengthInBytes();
          return length != null && _reader.tryAdvance(length);
        }

        // We don't actually expect to ever hit this point, since every code is supported.
        throw _throwInvalidCode(code);
    }
  }

  dynamic read() {
    switch (nextMessagePackType) {
      case MessagePackType.array:
        return readArray();
      case MessagePackType.binary:
        return readBytes();
      case MessagePackType.boolean:
        return readBoolean();
      case MessagePackType.extension:
        ExtensionHeader header = readExtensionFormatHeader();
        if (header.typeCode == ReservedMessagePackExtensionTypeCode.dateTime) {
          return readDateTimeWithHeader(header);
        }

        return _readExtensionFormat(header);
      case MessagePackType.float:
        return readDouble();
      case MessagePackType.integer:
        return readInt();
      case MessagePackType.map:
        return readMap();
      case MessagePackType.nil:
        readNil();
        return null;
      case MessagePackType.string:
        return readString();
      case MessagePackType.unknown:
      default:
        throw _throwInvalidCode(nextCode);
    }
  }

  dynamic readMessage(dynamic Function(List<dynamic>) creator) {
    List<dynamic> items = <dynamic>[];
    int length = readArrayHeader();
    for (int index = 0; index < length; ++index) {
      items.add(read());
    }

    return creator(items);
  }

  Nil readNil() {
    int? code = _reader.tryReadUint8();
    return _readNil(code);
  }

  Nil? tryReadNil() {
    if (nextCode == MessagePackCode.nil) {
      _reader.advance(1);
      return Nil.instance;
    }

    return null;
  }

  Nil _readNil(int? code) {
    _throwInsufficientBufferUnless(code != null);

    return code == MessagePackCode.nil
        ? Nil.instance
        : throw _throwInvalidCode(code!);
  }

  Uint8List readRawWithLength(int length) {
    try {
      Uint8List data = _reader.slice(length);
      _reader.advance(length);
      return data;
    } on RangeError catch (_) {
      throw _throwNotEnoughBytesException();
    }
  }

  Uint8List readRaw() {
    int initialPosition = _reader.position;
    skip();
    return _reader.slice(_reader.position - initialPosition, initialPosition);
  }

  List<dynamic> readArray() {
    List<dynamic> array = <dynamic>[];
    int length = readArrayHeader();
    for (int index = 0; index < length; ++index) {
      dynamic value = read();
      array.add(value);
    }

    return array;
  }

  int readArrayHeader() {
    int? count = tryReadArrayHeader();
    _throwInsufficientBufferUnless(count != null);

    // Protect against corrupted or mischievious data that may lead to allocating way too much memory.
    // We allow for each primitive to be the minimal 1 byte in size.
    // Formatters that know each element is larger can optionally add a stronger check.
    _throwInsufficientBufferUnless(_reader.remaining >= count!);

    return count;
  }

  int? tryReadArrayHeader() {
    int? code = _reader.tryReadUint8();
    if (code == null) {
      return null;
    }

    switch (code) {
      case MessagePackCode.array16:
        return _reader.tryReadUint16();
      case MessagePackCode.array32:
        return _reader.tryReadInt32();
      default:
        if (code >= MessagePackCode.minFixArray &&
            code <= MessagePackCode.maxFixArray) {
          return code & 0xF;
        }

        throw _throwInvalidCode(code);
    }
  }

  Map<dynamic, dynamic> readMap() {
    Map<dynamic, dynamic> map = <dynamic, dynamic>{};
    int length = readMapHeader();
    for (int index = 0; index < length; ++index) {
      dynamic key = read();
      map[key] = read();
    }

    return map;
  }

  int readMapHeader() {
    int? count = tryReadMapHeader();
    _throwInsufficientBufferUnless(count != null);

    // Protect against corrupted or mischievious data that may lead to allocating way too much memory.
    // We allow for each primitive to be the minimal 1 byte in size, and we have a key=value map, so that's 2 bytes.
    // Formatters that know each element is larger can optionally add a stronger check.
    _throwInsufficientBufferUnless(_reader.remaining >= count! * 2);

    return count;
  }

  int? tryReadMapHeader() {
    int? code = _reader.tryReadUint8();
    if (code == null) {
      return null;
    }

    switch (code) {
      case MessagePackCode.map16:
        return _reader.tryReadUint16();
      case MessagePackCode.map32:
        return _reader.tryReadInt32();
      default:
        if (code >= MessagePackCode.minFixMap &&
            code <= MessagePackCode.maxFixMap) {
          return code & 0xF;
        }

        throw _throwInvalidCode(code);
    }
  }

  bool readBoolean() {
    int? code = _reader.tryReadUint8();

    _throwInsufficientBufferUnless(code != null);

    switch (code) {
      case MessagePackCode.true_:
        return true;
      case MessagePackCode.false_:
        return false;
      default:
        throw _throwInvalidCode(code!);
    }
  }

  int readChar() => readInt();

  int readInt() => readNum().toInt();

  double readDouble() => readNum().toDouble();

  num readNum() {
    int? code = _reader.tryReadUint8();

    return _readNum(code);
  }

  num _readNum(int? code) {
    _throwInsufficientBufferUnless(code != null);

    switch (code) {
      case MessagePackCode.float64:
        double? doubleValue = _reader.tryReadFloat64();
        _throwInsufficientBufferUnless(doubleValue != null);
        return doubleValue!;
      case MessagePackCode.float32:
        double? floatValue = _reader.tryReadFloat32();
        _throwInsufficientBufferUnless(floatValue != null);
        return floatValue!;
      case MessagePackCode.int8:
        int? byteValue = _reader.tryReadInt8();
        _throwInsufficientBufferUnless(byteValue != null);
        return byteValue!;
      case MessagePackCode.int16:
        int? shortValue = _reader.tryReadInt16();
        _throwInsufficientBufferUnless(shortValue != null);
        return shortValue!;
      case MessagePackCode.int32:
        int? intValue = _reader.tryReadInt32();
        _throwInsufficientBufferUnless(intValue != null);
        return intValue!;
      case MessagePackCode.int64:
        int? longValue = _reader.tryReadInt64();
        _throwInsufficientBufferUnless(longValue != null);
        return longValue!;
      case MessagePackCode.uint8:
        int? byteValue = _reader.tryReadUint8();
        _throwInsufficientBufferUnless(byteValue != null);
        return byteValue!;
      case MessagePackCode.uint16:
        int? shortValue = _reader.tryReadUint16();
        _throwInsufficientBufferUnless(shortValue != null);
        return shortValue!;
      case MessagePackCode.uint32:
        int? intValue = _reader.tryReadUint32();
        _throwInsufficientBufferUnless(intValue != null);
        return intValue!;
      case MessagePackCode.uint64:
        int? longValue = _reader.tryReadUint64();
        _throwInsufficientBufferUnless(longValue != null);
        return longValue!;
      default:
        if (code! >= MessagePackCode.minNegativeFixInt &&
            code <= MessagePackCode.maxNegativeFixInt) {
          return code.toSigned(8);
        } else if (code >= MessagePackCode.minFixInt &&
            code <= MessagePackCode.maxFixInt) {
          return code;
        }

        throw _throwInvalidCode(code);
    }
  }

  DateTime readDateTime() {
    ExtensionHeader extensionHeader = readExtensionFormatHeader();
    return readDateTimeWithHeader(extensionHeader);
  }

  DateTime readDateTimeWithHeader(
    ExtensionHeader header, {
    bool suppressPrecisionError = true,
  }) {
    if (header.typeCode != ReservedMessagePackExtensionTypeCode.dateTime) {
      throw MessagePackSerializationException(
        "Extension TypeCode is invalid. typeCode: ${header.typeCode}",
      );
    }

    switch (header.length) {
      case 4:
        int? intValue = _reader.tryReadUint32();
        _throwInsufficientBufferUnless(intValue != null);
        return DateTimeConstants.unixEpoch.add(Duration(seconds: intValue!));
      case 8:
        int? firstPart = _reader.tryReadUint32();
        int? secondPart = _reader.tryReadUint32();
        _throwInsufficientBufferUnless(firstPart != null && secondPart != null);
        int nanoseconds = (firstPart! & 0xFFFFFFF3) >> 2;
        int seconds = ((firstPart & 0x00000003) << 33) | secondPart!;
        int remainder =
            nanoseconds % DateTimeConstants.nanosecondsPerMicrosecond;
        if (remainder != 0 && !suppressPrecisionError) {
          throw const FormatException(
            "Dart does not support nano second precision",
          );
        }

        int microseconds =
            nanoseconds ~/ DateTimeConstants.nanosecondsPerMicrosecond;

        return DateTimeConstants.unixEpoch.add(
          Duration(
            seconds: seconds,
            microseconds: microseconds,
          ),
        );
      case 12:
        int? intValue = _reader.tryReadUint32();
        _throwInsufficientBufferUnless(intValue != null);
        int? longValue = _reader.tryReadInt64();
        _throwInsufficientBufferUnless(longValue != null);
        int remainder =
            longValue! % DateTimeConstants.nanosecondsPerMicrosecond;
        if (remainder != 0 && !suppressPrecisionError) {
          throw const FormatException(
            "Dart does not support nano second precision",
          );
        }

        return DateTimeConstants.unixEpoch.add(
          Duration(
            seconds: longValue,
            microseconds:
                intValue! ~/ DateTimeConstants.nanosecondsPerMicrosecond,
          ),
        );
      default:
        throw MessagePackSerializationException(
          "Length of extension was ${header.length}. Either 4 or 8 were expected.",
        );
    }
  }

  // Uint8List? tryReadBytes() {
  //   Nil? nil = tryReadNil();
  //   if (nil == Nil.instance) {
  //     return null;
  //   }

  //   int initialPosition = _reader.position;
  //   int? length = _tryGetBytesLength();
  //   if (length == null) {
  //     _reader.advanceTo(initialPosition);
  //     return null;
  //   }

  //   Uint8List result = _reader.slice(length);
  //   _reader.advance(length);
  //   return result;
  // }

  Uint8List? readBytes() {
    Nil? nil = tryReadNil();
    if (nil == Nil.instance) {
      return null;
    }

    int length = _getBytesLength();
    _throwInsufficientBufferUnless(_reader.remaining >= length);
    Uint8List result = _reader.slice(length);
    _reader.advance(length);
    return result;
  }

  Uint8List? readRawString() {
    Nil? nil = tryReadNil();
    if (nil == Nil.instance) {
      return null;
    }

    int byteLength = _getStringLengthInBytes();

    _throwInsufficientBufferUnless(_reader.remaining >= byteLength);

    Uint8List data = _reader.slice(byteLength);
    _reader.advance(byteLength);
    return data;
  }

  String? readString({Encoding encoding = utf8}) {
    Nil? nil = tryReadNil();
    if (nil == Nil.instance) {
      return null;
    }

    int length = _getStringLengthInBytes();

    _throwInsufficientBufferUnless(_reader.remaining >= length);

    Uint8List data = _reader.slice(length);
    String value = encoding.decode(data);
    _reader.advance(length);
    return value;
  }

  ExtensionHeader readExtensionFormatHeader() {
    ExtensionHeader? header = tryReadExtensionFormatHeader();
    _throwInsufficientBufferUnless(header != null);

    // Protect against corrupted or mischievious data that may lead to allocating way too much memory.
    _throwInsufficientBufferUnless(_reader.remaining >= header!.length);

    return header;
  }

  ExtensionHeader? tryReadExtensionFormatHeader() {
    int? code = _reader.tryReadUint8();
    if (code == null) {
      return null;
    }

    int length;
    switch (code) {
      case MessagePackCode.fixExt1:
        length = 1;
      case MessagePackCode.fixExt2:
        length = 2;
      case MessagePackCode.fixExt4:
        length = 4;
      case MessagePackCode.fixExt8:
        length = 8;
      case MessagePackCode.fixExt16:
        length = 16;
      case MessagePackCode.ext8:
        int? code = _reader.tryReadUint8();
        if (code == null) {
          return null;
        }

        length = code;
      case MessagePackCode.ext16:
        int? code = _reader.tryReadUint16();
        if (code == null) {
          return null;
        }

        length = code;
      case MessagePackCode.ext32:
        int? code = _reader.tryReadUint32();
        if (code == null) {
          return null;
        }

        length = code;
      default:
        throw _throwInvalidCode(code);
    }

    int? typeCode = _reader.tryReadInt8();
    if (typeCode == null) {
      return null;
    }

    return ExtensionHeader(typeCode, length);
  }

  ExtensionResult readExtensionFormat() {
    ExtensionHeader header = readExtensionFormatHeader();
    return _readExtensionFormat(header);
  }

  ExtensionResult _readExtensionFormat(ExtensionHeader header) {
    try {
      Uint8List data = _reader.slice(header.length);
      _reader.advance(header.length);
      return ExtensionResult(header.typeCode, data);
    } on RangeError catch (_) {
      throw _throwNotEnoughBytesException();
    }
  }

  static Never _throwNotEnoughBytesException() =>
      throw const EndOfStreamException();

  static Never _throwInvalidCode(int code) {
    throw MessagePackSerializationException(
      "Unexpected msgpack code $code (${MessagePackCode.toFormatName(code)}) encountered.",
    );
  }

  static void _throwInsufficientBufferUnless(bool condition) {
    if (!condition) {
      _throwNotEnoughBytesException();
    }
  }

  int _getBytesLength() {
    int? length = _tryGetBytesLength();
    _throwInsufficientBufferUnless(length != null);

    return length!;
  }

  int? _tryGetBytesLength() {
    int? code = _reader.tryReadUint8();
    if (code == null) {
      return null;
    }

    // In OldSpec mode, Bin didn't exist, so Str was used. Str8 didn't exist either.
    switch (code) {
      case MessagePackCode.bin8:
        return _reader.tryReadUint8();
      case MessagePackCode.bin16:
      case MessagePackCode.str16: // OldSpec compatibility
        return _reader.tryReadUint16();
      case MessagePackCode.bin32:
      case MessagePackCode.str32: // OldSpec compatibility
        return _reader.tryReadInt32();
      default:
        // OldSpec compatibility
        if (code >= MessagePackCode.minFixStr &&
            code <= MessagePackCode.maxFixStr) {
          return code & 0x1F;
        }

        throw _throwInvalidCode(code);
    }
  }

  int? _tryGetStringLengthInBytes() {
    int? length = _reader.tryReadUint8();
    if (length == null) {
      return null;
    }

    if (length >= MessagePackCode.minFixStr &&
        length <= MessagePackCode.maxFixStr) {
      return length & 0x1F;
    }

    return _tryGetStringLengthInBytesSlow(length);
  }

  int _getStringLengthInBytes() {
    int? length = _tryGetStringLengthInBytes();
    _throwInsufficientBufferUnless(length != null);
    return length!;
  }

  int? _tryGetStringLengthInBytesSlow(int code) {
    int? length;
    switch (code) {
      case MessagePackCode.str8:
        int? value = _reader.tryReadUint8();
        if (value != null) {
          length = value;
        }

      case MessagePackCode.str16:
        int? value = _reader.tryReadUint16();
        if (value != null) {
          length = value;
        }

      case MessagePackCode.str32:
        int? value = _reader.tryReadInt32();
        if (value != null) {
          length = value;
        }

      default:
        if (code >= MessagePackCode.minFixStr &&
            code <= MessagePackCode.maxFixStr) {
          length = code & 0x1F;
        }

        throw _throwInvalidCode(code);
    }

    return length;
  }

  bool _trySkipNextArray() {
    int? count = tryReadArrayHeader();
    return count != null && _trySkipCount(count);
  }

  bool _trySkipNextMap() {
    int? count = tryReadMapHeader();
    return count != null && _trySkipCount(count * 2);
  }

  bool _trySkipCount(int count) {
    for (int i = 0; i < count; i++) {
      if (!trySkip()) {
        return false;
      }
    }

    return true;
  }
}
