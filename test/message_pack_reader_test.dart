import "dart:convert";
import "dart:typed_data";

import "package:msg_pck/msg_pck.dart";
import "package:test/test.dart";

import "test_constants.dart";

Uint8List encode(void Function(MessagePackWriter writer) cb) {
  MessagePackWriter writer = MessagePackWriter();
  cb(writer);

  return writer.takeBytes();
}

dynamic decode(
  Uint8List sequence,
  dynamic Function(MessagePackReader reader) readOperation,
) {
  MessagePackReader reader = MessagePackReader.fromTypedData(sequence);
  return readOperation(reader);
}

void main() {
  const int minNegativeFixInt = MessagePackRange.minFixNegativeInt;
  const int maxNegativeFixInt = MessagePackRange.maxFixNegativeInt;
  List<(BigInt value, Uint8List encoded)> integersOfInterest =
      <(BigInt value, Uint8List encoded)>[
    // * FixInt
    // ** non-boundary
    (BigInt.from(3), encode((MessagePackWriter w) => w.writeInt(3))),

    (BigInt.from(-3), encode((MessagePackWriter w) => w.writeInt(-3))),

    // ** Boundary conditions
    /* MaxFixInt */
    (
      BigInt.from(MessagePackCode.maxFixInt),
      encode((MessagePackWriter w) => w.writeInt(MessagePackCode.maxFixInt))
    ),
    /* MinFixInt */
    (
      BigInt.from(MessagePackCode.minFixInt),
      encode((MessagePackWriter w) => w.writeInt(MessagePackCode.minFixInt))
    ),
    /* minNegativeFixInt */
    (
      BigInt.from(minNegativeFixInt),
      encode((MessagePackWriter w) => w.writeInt(minNegativeFixInt))
    ),
    /* maxNegativeFixInt */
    (
      BigInt.from(maxNegativeFixInt),
      encode((MessagePackWriter w) => w.writeInt(maxNegativeFixInt))
    ),

    // * encoded as each type of at least 8 bits
    // ** Small positive value
    (BigInt.from(3), encode((MessagePackWriter w) => w.writeInt(3))),

    // ** Small negative value
    (BigInt.from(-3), encode((MessagePackWriter w) => w.writeInt(-3))),

    // ** Max values
    /* Positive */
    (BigInt.from(0x0ff), encode((MessagePackWriter w) => w.writeInt(255))),
    (BigInt.from(0x0ffff), encode((MessagePackWriter w) => w.writeInt(65535))),
    (
      BigInt.from(0x0ffffffff),
      encode((MessagePackWriter w) => w.writeInt(4294967295))
    ),
    // (
    //   BigInt.from(0x0ffffffffffffffff),
    //   encode((MessagePackWriter w) => w.writeInt(18446744073709551615))
    // ),
    (BigInt.from(0x7f), encode((MessagePackWriter w) => w.writeInt(127))),
    (BigInt.from(0x7fff), encode((MessagePackWriter w) => w.writeInt(32767))),
    (
      BigInt.from(0x7fffffff),
      encode((MessagePackWriter w) => w.writeInt(2147483647))
    ),
    (
      BigInt.from(0x7fffffffffffffff),
      encode((MessagePackWriter w) => w.writeInt(9223372036854775807))
    ),
    /* Negative */
    (BigInt.from(-0x80), encode((MessagePackWriter w) => w.writeInt(-128))),
    (BigInt.from(-0x8000), encode((MessagePackWriter w) => w.writeInt(-32768))),
    (
      BigInt.from(-0x80000000),
      encode((MessagePackWriter w) => w.writeInt(-2147483648))
    ),
    (
      BigInt.from(-0x8000000000000000),
      encode((MessagePackWriter w) => w.writeInt(-9223372036854775808))
    ),
  ];

  Uint8List stringEncodedAsFixStr =
      encode((MessagePackWriter w) => w.writeString("hi"));

  group("reader", () {
    setUp(() {
      // Additional setup goes here.
    });

    group(" ", () {
      test("Read", () {
        List<dynamic> array = <dynamic>[
          2,
          "Hi",
          -1,
          <int>[5],
        ];
        Map<dynamic, dynamic> map = <dynamic, dynamic>{
          2: 5,
          "Hi": -4,
          -4: "Hi",
        };
        MessagePackWriter writer = MessagePackWriter()
          ..writeArray(array)
          ..writeInt(1)
          ..writeString("Hi")
          ..writeMap(map)
          ..writeInt(5);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);
        expect(array, equals(reader.read()));
        expect(1, equals(reader.read()));
        expect("Hi", equals(reader.read()));
        expect(map, equals(reader.read()));
        expect(5, equals(reader.read()));
      });

      test("ReadArray", () {
        List<dynamic> array = <dynamic>[
          2,
          "Hi",
          -1,
          <int>[5],
        ];
        MessagePackWriter writer = MessagePackWriter()..writeArray(array);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);
        expect(array, equals(reader.readArray()));
      });

      test("ReadMap", () {
        Map<dynamic, dynamic> map = <dynamic, dynamic>{
          2: 5,
          "Hi": -4,
          -4: "Hi",
        };
        MessagePackWriter writer = MessagePackWriter()..writeMap(map);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);
        expect(map, equals(reader.readMap()));
      });

      test("ReadSingle_ReadIntegersOfVariousLengthsAndMagnitudes", () {
        for (var (BigInt value, Uint8List encoded) in integersOfInterest) {
          expect(
            value.toDouble(),
            MessagePackReader.fromTypedData(encoded).readDouble(),
          );
        }
      });

      // TODO: https://github.com/dart-lang/sdk/issues/53284
      // test("ReadSingle_CanReadDouble", () {
      //   MessagePackReader reader = MessagePackReader.fromTypedData(
      //       encode((MessagePackWriter w) => w.writeFloat(1.23)));
      //   expect(1.23, equals(reader.readDouble()));
      // });

      test("ReadArrayHeader_MitigatesLargeAllocations", () {
        MessagePackWriter writer = MessagePackWriter()..writeArrayHeader(9999);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        expect(
          () => reader.readArrayHeader(),
          throwsA(isA<EndOfStreamException>()),
        );
      });

      test("TryReadArrayHeader", () {
        MessagePackWriter writer = MessagePackWriter();
        const int expectedCount = 100;
        writer.writeArrayHeader(expectedCount);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader =
            MessagePackReader.fromTypedData(data.sublist(0, data.length - 1));

        expect(reader.tryReadArrayHeader(), isNull);

        reader = MessagePackReader.fromTypedData(data);

        expect(reader.tryReadArrayHeader(), expectedCount);
      });

      test("ReadMapHeader_MitigatesLargeAllocations", () {
        MessagePackWriter writer = MessagePackWriter()..writeMapHeader(9999);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        expect(
          () => reader.readMapHeader(),
          throwsA(isA<EndOfStreamException>()),
        );
      });

      test("TryReadMapHeader", () {
        MessagePackWriter writer = MessagePackWriter();
        const int expectedCount = 100;
        writer.writeMapHeader(expectedCount);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader =
            MessagePackReader.fromTypedData(data.sublist(0, data.length - 1));

        expect(reader.tryReadMapHeader(), isNull);

        reader = MessagePackReader.fromTypedData(data);

        expect(reader.tryReadMapHeader(), expectedCount);
      });

      test("ReadExtensionFormatHeader_MitigatesLargeAllocations", () {
        MessagePackWriter writer = MessagePackWriter();
        ExtensionHeader extensionHeader = const ExtensionHeader(3, 1);
        writer
          ..writeExtensionFormatHeader(extensionHeader)
          ..writeRaw(Uint8List.fromList(<int>[1]));

        Uint8List data = writer.takeBytes();

        MessagePackReader reader =
            MessagePackReader.fromTypedData(data.sublist(0, data.length - 1));

        expect(
          () => reader.readExtensionFormatHeader(),
          throwsA(isA<EndOfStreamException>()),
        );

        reader = MessagePackReader.fromTypedData(data);

        expect(reader.readExtensionFormatHeader(), equals(extensionHeader));
      });

      test("TryReadExtensionFormatHeader", () {
        MessagePackWriter writer = MessagePackWriter();
        ExtensionHeader extensionHeader = const ExtensionHeader(4, 100);
        writer.writeExtensionFormatHeader(extensionHeader);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader =
            MessagePackReader.fromTypedData(data.sublist(0, data.length - 1));

        expect(reader.tryReadExtensionFormatHeader(), isNull);

        reader = MessagePackReader.fromTypedData(data);

        expect(reader.tryReadExtensionFormatHeader(), equals(extensionHeader));
      });

      test("TryReadStringSpan_Contiguous", () {
        MessagePackWriter writer = MessagePackWriter();
        Uint8List expected = Uint8List.fromList(<int>[1, 2, 3]);
        writer.writeRawString(expected);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        Uint8List? readData = reader.readRawString();

        expect(readData, isNotNull);
        expect(readData, equals(expected));
        expect(reader.end, isTrue);
      });

      test("TryReadStringSpan_Nil", () {
        MessagePackWriter writer = MessagePackWriter()..writeNil();

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        Uint8List? readData = reader.readRawString();

        expect(readData, isNull);
      });

      test("ReadString_MultibyteChars", () {
        MessagePackReader reader = MessagePackReader.fromTypedData(
          TestContants.msgPackEncodedMultiByteCharString,
        );

        String? readData = reader.readString();

        expect(readData, isNotNull);
        expect(readData, TestContants.multiByteCharString);
      });

      test("ReadRaw", () {
        MessagePackWriter writer = MessagePackWriter()
          ..writeInt(3)
          ..writeArrayHeader(2)
          ..writeInt(1)
          ..writeString("Hi")
          ..writeInt(5);

        Uint8List data = writer.takeBytes();

        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        Uint8List first = reader.readRaw();
        expect(first.length, equals(1));
        expect(MessagePackReader.fromTypedData(first).readInt(), equals(3));

        Uint8List second = reader.readRaw();
        expect(second.length, equals(5));

        MessagePackReader secondsReader =
            MessagePackReader.fromTypedData(second);

        int value = secondsReader.readArrayHeader();
        expect(value, equals(2));

        value = secondsReader.readInt();
        expect(value, equals(1));

        String? sValue = secondsReader.readString();
        expect(sValue, isNotNull);
        expect(sValue, "Hi");

        Uint8List third = reader.readRaw();
        expect(third.length, equals(1));

        expect(reader.end, isTrue);
      });

      test("Read_CheckOperations_WithNoBytesLeft", () {
        Uint8List data = Uint8List(0);
        MessagePackReader reader = MessagePackReader.fromTypedData(data);

        expect(() => reader.nextCode, throwsA(isA<EndOfStreamException>()));
        expect(
          () => reader.nextMessagePackType,
          throwsA(isA<EndOfStreamException>()),
        );
        expect(() => reader.tryReadNil(), throwsA(isA<EndOfStreamException>()));
        expect(
          () => reader.readRawString(),
          throwsA(isA<EndOfStreamException>()),
        );
        expect(() => reader.isNil, throwsA(isA<EndOfStreamException>()));
      });

      test("Read_WithInsufficientBytesLeft", () {
        void assertIncomplete(
          void Function(MessagePackWriter writer) encoder,
          dynamic Function(MessagePackReader reader) decoder, {
          bool validMsgPack = true,
        }) {
          Uint8List data = encode(encoder);

          // Test with every possible truncated length.
          for (int len = data.length - 1; len >= 0; len--) {
            Uint8List truncated = data.sublist(0, len);
            expect(
              () => decode(truncated, decoder),
              throwsA(isA<EndOfStreamException>()),
            );

            if (validMsgPack) {
              expect(
                () => MessagePackReader.fromTypedData(truncated)..skip(),
                throwsA(isA<EndOfStreamException>()),
              );
            }
          }
        }

        assertIncomplete(
          (MessagePackWriter writer) => writer.writeArrayHeader(0xfffffff),
          (MessagePackReader reader) => reader.readArrayHeader(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeBoolean(true),
          (MessagePackReader reader) => reader.readChar(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeInt(0xff),
          (MessagePackReader reader) => reader.readInt(),
        );
        assertIncomplete(
          (MessagePackWriter writer) =>
              writer.writeRawString(utf8.encoder.convert("hi")),
          (MessagePackReader reader) => reader.readBytes(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeInt("c".codeUnitAt(0)),
          (MessagePackReader reader) => reader.readInt(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeDateTime(DateTime.now()),
          (MessagePackReader reader) => reader.readDateTime(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeDouble(double.maxFinite),
          (MessagePackReader reader) => reader.readDouble(),
        );
        assertIncomplete(
          (MessagePackWriter writer) =>
              writer.writeExtensionFormat(ExtensionResult(5, Uint8List(3))),
          (MessagePackReader reader) => reader.readExtensionFormat(),
        );
        assertIncomplete(
          (MessagePackWriter writer) =>
              writer.writeExtensionFormatHeader(const ExtensionHeader(5, 3)),
          (MessagePackReader reader) => reader.readExtensionFormatHeader(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeMapHeader(0xfffffff),
          (MessagePackReader reader) => reader.readMapHeader(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeNil(),
          (MessagePackReader reader) => reader.readNil(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeString("hi"),
          (MessagePackReader reader) => reader.readRaw(),
        );
        assertIncomplete(
          (MessagePackWriter writer) => writer.writeRaw(Uint8List(10)),
          (MessagePackReader reader) => reader.readRawWithLength(10),
          validMsgPack: false,
        );
        assertIncomplete(
          (MessagePackWriter writer) =>
              writer.writeRawString(utf8.encoder.convert("hi")),
          (MessagePackReader reader) => reader.readString(),
        );
        assertIncomplete(
          (MessagePackWriter writer) =>
              writer.writeRawString(utf8.encoder.convert("hi")),
          (MessagePackReader reader) => reader.readRawString(),
        );
      });
    });

    group("read string", () {
      test("ReadString_HandlesSingleSegment", () {
        Uint8List data = Uint8List(3);
        data[0] = MessagePackCode.minFixStr + 2;
        data[1] = "A".codeUnitAt(0);
        data[2] = "B".codeUnitAt(0);

        MessagePackReader reader = MessagePackReader.fromTypedData(data);
        String? string = reader.readString();
        expect("AB", equals(string));
      });
    });

    group("read int", () {
      test("ReadByte_ReadVariousLengthsAndMagnitudes", () {
        for (var (BigInt value, Uint8List encoded) in integersOfInterest) {
          expect(
            value.toInt(),
            MessagePackReader.fromTypedData(encoded).readInt(),
          );
        }
      });

      test("ReadByte_ThrowsOnUnexpectedCode", () {
        expect(
          () =>
              MessagePackReader.fromTypedData(stringEncodedAsFixStr).readInt(),
          throwsA(isA<MessagePackSerializationException>()),
        );
      });

      test("ReadUInt16_ReadVariousLengthsAndMagnitudes", () {
        expect(
          () =>
              MessagePackReader.fromTypedData(stringEncodedAsFixStr).readInt(),
          throwsA(isA<MessagePackSerializationException>()),
        );
      });
    });
  });
}
