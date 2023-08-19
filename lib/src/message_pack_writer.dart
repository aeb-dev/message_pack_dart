import "dart:convert";
import "dart:typed_data";

import "date_time_constants.dart";
import "extension_header.dart";
import "extension_result.dart";
import "message_pack_code.dart";
import "message_pack_range.dart";
import "mixins/message.dart";
import "reserved_message_pack_extension_type_code.dart";

class MessagePackWriter {
  final BytesBuilder _bytesBuilder;

  static const int _maxUint8 = 255;
  static const int _maxUint16 = 65535;
  static const int _maxUint32 = 4294967295;
  static const int _maxUint64 =
      9007199254740991; // js value. Normally, 9223372036854775807;
  static const int _minInt8 = -127;
  static const int _minInt16 = -32768;
  static const int _minInt32 = -2147483648;

  MessagePackWriter([BytesBuilder? builder, List<int>? initialData])
      : _bytesBuilder = builder ?? BytesBuilder() {
    if (initialData != null) {
      _bytesBuilder.add(initialData);
    }
  }

  void write(dynamic value) {
    if (value == null) {
      writeNil();
    }

    switch (value) {
      case bool v:
        writeBoolean(v);
      case num v:
        writeNum(v);
      case String v:
        writeString(v);
      case DateTime v:
        writeDateTime(v);
      case ByteData v:
        writeByteData(v);
      case TypedData v:
        writeTypedData(v);
      case ByteBuffer v:
        writeByteBuffer(v);
      case List<dynamic> v:
        writeArray(v);
      case Map<dynamic, dynamic> v:
        writeMap(v);
      case Message v:
        writeMessage(v);
      default:
        throw const FormatException("Unexpected type while packing");
    }
  }

  void writeMessage(Message message) {
    for (dynamic field in message.messagePackFields) {
      write(field);
    }
  }

  void writeNil() {
    _bytesBuilder.addByte(MessagePackCode.nil);
  }

  void writeByteData(ByteData data) {
    writeBinary(data.buffer.asUint8List(data.offsetInBytes));
  }

  void writeTypedData(TypedData data) {
    writeBinary(data.buffer.asUint8List(data.offsetInBytes));
  }

  void writeByteBuffer(ByteBuffer buffer) {
    writeBinary(buffer.asUint8List());
  }

  void writeRaw(Uint8List rawMessagePackBlock) {
    _bytesBuilder.add(rawMessagePackBlock);
  }

  void writeArray(List<dynamic>? array) {
    if (array == null) {
      writeNil();
      return;
    }

    writeArrayHeader(array.length);
    for (dynamic item in array) {
      write(item);
    }
  }

  void writeArrayHeader(int count) {
    if (count <= MessagePackRange.maxFixArrayCount) {
      _bytesBuilder.addByte(MessagePackCode.minFixArray | count);
    } else if (count <= _maxUint16) {
      _bytesBuilder.addByte(MessagePackCode.array16);
      _writeBigEndianShort(count);
    } else {
      _bytesBuilder.addByte(MessagePackCode.array32);
      _writeBigEndianInt(count);
    }
  }

  void writeMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      writeNil();
      return;
    }

    writeMapHeader(map.length);
    for (MapEntry<dynamic, dynamic> me in map.entries) {
      write(me.key);
      write(me.value);
    }
  }

  void writeMapHeader(int count) {
    if (count <= MessagePackRange.maxFixMapCount) {
      _bytesBuilder.addByte(MessagePackCode.minFixMap | count);
    } else if (count <= _maxUint16) {
      _bytesBuilder.addByte(MessagePackCode.map16);
      _writeBigEndianShort(count);
    } else {
      _bytesBuilder.addByte(MessagePackCode.map32);
      _writeBigEndianInt(count);
    }
  }

  void writeNum(num? value) {
    if (value == null) {
      writeNil();
      return;
    }

    switch (value) {
      case int v:
        writeInt(v);
      case double v:
        _writeFloatOrDouble(v);
    }
  }

  void writeInt(int? value) {
    if (value == null) {
      writeNil();
      return;
    }

    switch (value) {
      case >= 0:
        switch (value) {
          case <= MessagePackCode.maxFixInt:
            _bytesBuilder.addByte(value);
          case <= _maxUint8:
            _bytesBuilder.add(<int>[MessagePackCode.uint8, value]);
          case <= _maxUint16:
            _bytesBuilder.addByte(MessagePackCode.uint16);
            _writeBigEndianShort(value);
          case <= _maxUint32:
            _bytesBuilder.addByte(MessagePackCode.uint32);
            _writeBigEndianInt(value);
          default:
            _bytesBuilder.addByte(MessagePackCode.uint64);
            _writeBigEndianLong(value);
        }
      default:
        switch (value) {
          case >= MessagePackRange.minFixNegativeInt:
            _bytesBuilder.addByte(value);
          case >= _minInt8:
            _bytesBuilder.add(<int>[MessagePackCode.int8, value]);
          case >= _minInt16:
            _bytesBuilder.addByte(MessagePackCode.int16);
            _writeBigEndianShort(value);
          case >= _minInt32:
            _bytesBuilder.addByte(MessagePackCode.int32);
            _writeBigEndianInt(value);
          default:
            _bytesBuilder.addByte(MessagePackCode.int64);
            _writeBigEndianLong(value);
        }
    }
  }

  // ignore: avoid_positional_boolean_parameters
  void writeBoolean(bool? value) {
    if (value == null) {
      writeNil();
      return;
    }

    _bytesBuilder
        .addByte(value ? MessagePackCode.true_ : MessagePackCode.false_);
  }

  void writeFloat(double? value) {
    if (value == null) {
      writeNil();
      return;
    }

    _bytesBuilder.addByte(MessagePackCode.float32);
    _writeBigEndianFloat(value);
  }

  void writeDouble(double? value) {
    if (value == null) {
      writeNil();
      return;
    }

    _bytesBuilder.addByte(MessagePackCode.float64);
    _writeBigEndianDouble(value);
  }

  void writeDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      writeNil();
      return;
    }

    // Timestamp spec
    // https://github.com/msgpack/msgpack/pull/209
    // FixExt4(-1) => seconds |  [1970-01-01 00:00:00 UTC, 2106-02-07 06:28:16 UTC) range
    // FixExt8(-1) => nanoseconds + seconds | [1970-01-01 00:00:00.000000000 UTC, 2514-05-30 01:53:04.000000000 UTC) range
    // Ext8(12,-1) => nanoseconds + seconds | [-584554047284-02-23 16:59:44 UTC, 584554051223-11-09 07:00:16.000000000 UTC) range

    // The spec requires UTC. Convert to UTC if we're sure the value was expressed as Local time.
    // If it's Unspecified, we want to leave it alone since .NET will change the value when we convert
    // and we simply don't know, so we should leave it as-is.
    if (!dateTime.isUtc) {
      // ignore: parameter_assignments
      dateTime = dateTime.toUtc();
    }

    Duration diff = dateTime.difference(DateTimeConstants.unixEpoch);
    int seconds = diff.inSeconds;
    int nanoseconds = (diff - Duration(seconds: seconds)).inMicroseconds * 1000;

    if ((seconds >> 34) == 0) {
      int data64 = (nanoseconds << 34) | seconds;
      if ((data64 & 0xffffffff00000000) == 0) {
        // timestamp 32(seconds in 32-bit unsigned int)
        _bytesBuilder.add(<int>[
          MessagePackCode.fixExt4,
          ReservedMessagePackExtensionTypeCode.dateTime,
        ]);
        _writeBigEndianInt(data64);
      } else {
        // timestamp 64(nanoseconds in 30-bit unsigned int | seconds in 34-bit unsigned int)
        _bytesBuilder.add(
          <int>[
            MessagePackCode.fixExt8,
            ReservedMessagePackExtensionTypeCode.dateTime,
          ],
        );
        _writeBigEndianLong(data64);
      }
    } else {
      // timestamp 96( nanoseconds in 32-bit unsigned int | seconds in 64-bit signed int )
      _bytesBuilder.add(
        <int>[
          MessagePackCode.ext8,
          12,
          ReservedMessagePackExtensionTypeCode.dateTime,
        ],
      );
      _writeBigEndianInt(nanoseconds);
      _writeBigEndianLong(seconds);
    }
  }

  void writeBinary(Uint8List? value) {
    if (value == null) {
      writeNil();
      return;
    }

    // int length = (int)src.Length;
    writeBinHeader(value.length);
    _bytesBuilder.add(value);
  }

  void writeBinHeader(int length) {
    // When we write the header, we'll ask for all the space we need for the payload as well
    // as that may help ensure we only allocate a buffer once.
    if (length <= _maxUint8) {
      _bytesBuilder.add(<int>[MessagePackCode.bin8, length]);
    } else if (length <= _maxUint16) {
      _bytesBuilder.addByte(MessagePackCode.bin16);
      _writeBigEndianShort(length);
    } else {
      _bytesBuilder.addByte(MessagePackCode.bin32);
      _writeBigEndianInt(length);
    }
  }

  void writeRawString(Uint8List rawString) {
    writeStringHeader(rawString.length);
    _bytesBuilder.add(rawString);
  }

  void writeString(String? string, {Encoding encoding = utf8}) {
    if (string == null) {
      writeNil();
      return;
    }

    Uint8List encodedString = encoding.encode(string) as Uint8List;
    writeStringHeader(encodedString.length);
    _bytesBuilder.add(encodedString);
  }

  void writeStringHeader(int byteCount) {
    // When we write the header, we'll ask for all the space we need for the payload as well
    // as that may help ensure we only allocate a buffer once.
    if (byteCount <= MessagePackRange.maxFixStringLength) {
      _bytesBuilder.addByte(MessagePackCode.minFixStr | byteCount);
    } else if (byteCount <= _maxUint8) {
      _bytesBuilder.add(<int>[MessagePackCode.str8, byteCount]);
    } else if (byteCount <= _maxUint16) {
      _bytesBuilder.addByte(MessagePackCode.str16);
      _writeBigEndianShort(byteCount);
    } else {
      _bytesBuilder.addByte(MessagePackCode.str32);
      _writeBigEndianInt(byteCount);
    }
  }

  void writeExtensionFormatHeader(ExtensionHeader extensionHeader) {
    int dataLength = extensionHeader.length;
    int typeCode = extensionHeader.typeCode;
    switch (dataLength) {
      case 1:
        _bytesBuilder.add(<int>[MessagePackCode.fixExt1, typeCode]);
        return;
      case 2:
        _bytesBuilder.add(<int>[MessagePackCode.fixExt2, typeCode]);
        return;
      case 4:
        _bytesBuilder.add(<int>[MessagePackCode.fixExt4, typeCode]);
        return;
      case 8:
        _bytesBuilder.add(<int>[MessagePackCode.fixExt8, typeCode]);
        return;
      case 16:
        _bytesBuilder.add(<int>[MessagePackCode.fixExt16, typeCode]);
        return;
      default:
        if (dataLength <= _maxUint8) {
          _bytesBuilder.add(<int>[MessagePackCode.ext8, dataLength, typeCode]);
        } else if (dataLength <= _maxUint16) {
          _bytesBuilder.addByte(MessagePackCode.ext16);
          _writeBigEndianShort(dataLength);
          _bytesBuilder.addByte(typeCode);
        } else {
          _bytesBuilder.addByte(MessagePackCode.ext32);
          _writeBigEndianInt(dataLength);
          _bytesBuilder.addByte(typeCode);
        }

        break;
    }
  }

  void writeExtensionFormat(ExtensionResult extensionData) {
    writeExtensionFormatHeader(extensionData.header);
    writeRaw(extensionData.data);
  }

  Uint8List takeBytes() => _bytesBuilder.takeBytes();

  void _writeBigEndianShort(int value) {
    ByteData bd = ByteData(2)..setUint16(0, value);
    _bytesBuilder.add(bd.buffer.asUint8List());
  }

  void _writeBigEndianInt(int value) {
    ByteData bd = ByteData(4)..setUint32(0, value);
    _bytesBuilder.add(bd.buffer.asUint8List());
  }

  void _writeBigEndianLong(int value) {
    ByteData bd = ByteData(8)..setUint64(0, value);
    _bytesBuilder.add(bd.buffer.asUint8List());
  }

  void _writeBigEndianFloat(double value) {
    ByteData bd = ByteData(4)..setFloat32(0, value);
    _bytesBuilder.add(bd.buffer.asUint8List());
  }

  void _writeBigEndianDouble(double value) {
    ByteData bd = ByteData(8)..setFloat64(0, value);
    _bytesBuilder.add(bd.buffer.asUint8List());
  }

  void _writeFloatOrDouble(double value) {
    if (value <= 3.402823E+38 && value >= -3.40282347E+38) {
      writeFloat(value);
    } else {
      writeDouble(value);
    }
  }

  static int getEncodedLength(int value) => switch (value) {
        int v when v > _maxUint64 => 9,
        _ => switch (value) {
            int v when v >= 0 => switch (value) {
                int v when v <= MessagePackRange.maxFixPositiveInt => 1,
                int v when v <= _maxUint8 => 2,
                int v when v <= _maxUint16 => 3,
                int v when v <= _maxUint32 => 5,
                _ => 9,
              },
            _ => switch (value) {
                int v when v >= MessagePackRange.minFixNegativeInt => 1,
                int v when v >= _minInt8 => 2,
                int v when v >= _minInt16 => 3,
                int v when v >= _minInt32 => 5,
                _ => 9
              }
          }
      };
}
