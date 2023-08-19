// ignore_for_file: avoid_classes_with_only_static_members

import "dart:convert";
import "dart:typed_data";

import "package:msg_pck/src/message_pack_code.dart";

class TestContants {
  static const String multiByteCharString = "にほんごにほんごにほんごにほんごにほんご";
  static Uint8List get msgPackEncodedMultiByteCharString {
    Uint8List encodedString = utf8.encoder.convert(multiByteCharString);
    Uint8List msgPackData = Uint8List(encodedString.length + 2);
    msgPackData[0] = MessagePackCode.str8;
    msgPackData[1] = encodedString.length;
    msgPackData.setRange(2, msgPackData.length, encodedString);
    return msgPackData;
  }
}
