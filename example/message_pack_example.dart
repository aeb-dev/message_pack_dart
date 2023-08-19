import "dart:typed_data";

import "package:msg_pck/msg_pck.dart";

void main() {
  MyClass mc = MyClass()
    ..id = 1
    ..name = "aeb"
    ..time = DateTime.now();

  Uint8List data = mc.toMessagePack();

  MyClass mc2 = fromMessagePack(data, MyClass.fromMessagePack);
}

class MyClass with MessagePackObject {
  late int id;
  late String name;
  late DateTime time;

  MyClass();

  @override
  List<dynamic> get messagePackFields => <dynamic>[id, name, time];

  MyClass.fromMessagePack(List<dynamic> items) {
    id = items[0] as int;
    name = items[1] as String;
    time = items[2] as DateTime;
  }
}
