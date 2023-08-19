import "dart:typed_data";

import "../../msg_pck.dart";

///
mixin Message {
  /// fields to be written
  List<dynamic> get messagePackFields;

  Uint8List toMessagePack() {
    MessagePackWriter writer = MessagePackWriter()..writeMessage(this);

    return writer.takeBytes();
  }
}
