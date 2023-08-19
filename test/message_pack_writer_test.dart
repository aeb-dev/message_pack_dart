import "dart:convert";
import "dart:typed_data";

import "package:msg_pck/msg_pck.dart";
import "package:test/test.dart";

import "test_constants.dart";

void main() {
  group("writer", () {
    late MessagePackWriter writer;
    setUp(() {
      writer = MessagePackWriter();
    });

    test("Write_ByteArray_null", () {
      writer.writeBinary(null);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);
      Nil? nil = reader.tryReadNil();
      expect(nil, equals(Nil.instance));
    });

    test("Write_ByteArray", () {
      List<int> initialData = <int>[1, 2, 3];
      writer.writeBinary(Uint8List.fromList(initialData));

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);
      Uint8List? readData = reader.readBytes();
      expect(initialData, equals(readData));
    });

    test("Write_String_null", () {
      writer.writeString(null);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);
      Nil? nil = reader.tryReadNil();
      expect(nil, equals(Nil.instance));
    });

    test("Write_String", () {
      String expected = "hello";
      writer.writeString(expected);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);
      String? readData = reader.readString();
      expect(expected, equals(readData));
    });

    test("Write_String_MultibyteChars", () {
      writer.writeString(TestContants.multiByteCharString);

      Uint8List asByte = TestContants.msgPackEncodedMultiByteCharString;

      Uint8List data = writer.takeBytes();

      expect(asByte, equals(data));
    });

    test("WriteStringHeader", () {
      String str = "hello";
      Uint8List strBytes = utf8.encoder.convert(str);
      writer
        ..writeStringHeader(strBytes.length)
        ..writeRaw(strBytes);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);

      expect(str, equals(reader.readString()));
    });

    test("WriteBinHeader", () {
      Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      writer
        ..writeBinHeader(bytes.length)
        ..writeRaw(bytes);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);

      expect(bytes, equals(reader.readBytes()));
    });

    test("WriteExtensionFormatHeader_NegativeExtension", () {
      ExtensionHeader header = const ExtensionHeader(-1, 10);
      writer
        ..writeExtensionFormatHeader(header)
        ..writeRaw(Uint8List(10));

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);

      ExtensionHeader readHeader = reader.readExtensionFormatHeader();

      expect(header, equals(readHeader));
    });

    test("WriteExtensionFormatHeader_NegativeExtension", () {
      ExtensionHeader header = const ExtensionHeader(-1, 10);
      writer
        ..writeExtensionFormatHeader(header)
        ..writeRaw(Uint8List(10));

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);

      ExtensionHeader readHeader = reader.readExtensionFormatHeader();

      expect(header, equals(readHeader));
    });

    test("DateTime", () {
      DateTime now = DateTime.now().toUtc();

      writer.writeDateTime(now);

      Uint8List data = writer.takeBytes();

      MessagePackReader reader = MessagePackReader.fromTypedData(data);

      DateTime readDateTime = reader.readDateTime();

      expect(now, equals(readDateTime));
    });
  });
}
