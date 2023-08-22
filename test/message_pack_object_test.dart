import "dart:typed_data";

import "package:msg_pck/msg_pck.dart";
import "package:test/test.dart";

class DummyClass with MessagePackObject {
  late int f1;
  late String f2;
  late Map<dynamic, dynamic> f3;
  late List<dynamic> f4;
  late Uint8List f5;
  late double f6;

  @override
  List<dynamic> get messagePackFields => <dynamic>[f1, f2, f3, f4, f5, f6];

  DummyClass();

  DummyClass.fromMessagePack(List<dynamic> items) {
    f1 = items[0] as int;
    f2 = items[1] as String;
    f3 = items[2] as Map<dynamic, dynamic>;
    f4 = items[3] as List<dynamic>;
    f5 = items[4] as Uint8List;
    f6 = items[5] as double;
  }
}

void main() {
  group("message mixin", () {
    late MessagePackWriter writer;
    setUp(() {
      writer = MessagePackWriter();
    });

    test("toMessagePack", () {
      DummyClass myObject = DummyClass()
        ..f1 = 4
        ..f2 = "Yo"
        ..f3 = <dynamic, dynamic>{"Hi": -3}
        ..f4 = <dynamic>["Hi", 11111, "Yo", 4]
        ..f5 = Uint8List.fromList(<int>[1, 2, 3])
        ..f6 = 1.23;

      writer.writeMessage(myObject);

      Uint8List data = writer.takeBytes();

      expect(
        data,
        equals(
          Uint8List.fromList(<int>[
            150,
            4,
            162,
            89,
            111,
            129,
            162,
            72,
            105,
            253,
            148,
            162,
            72,
            105,
            205,
            43,
            103,
            162,
            89,
            111,
            4,
            196,
            3,
            1,
            2,
            3,
            202,
            63,
            157,
            112,
            164,
          ]),
        ),
      );
    });

    test("fromMessagePack", () {
      writer
        ..writeArrayHeader(6)
        ..writeInt(4)
        ..writeString("Yo")
        ..writeMap(<dynamic, dynamic>{"Hi": -3})
        ..writeArray(<dynamic>["Hi", 11111, "Yo", 4])
        ..writeBinary(Uint8List.fromList(<int>[1, 2, 3]))
        ..writeFloat(1.23);

      Uint8List data = writer.takeBytes();

      DummyClass myObject = fromMessagePack(
        data,
        DummyClass.fromMessagePack,
      );

      expect(myObject.f1, equals(4));
      expect(myObject.f2, equals("Yo"));
      expect(myObject.f3, equals(<dynamic, dynamic>{"Hi": -3}));
      expect(myObject.f4, equals(<dynamic>["Hi", 11111, "Yo", 4]));
      expect(myObject.f5, equals(Uint8List.fromList(<int>[1, 2, 3])));
      expect((myObject.f6 - 1.23).abs(), lessThan(0.0001));
    });
  });
}
