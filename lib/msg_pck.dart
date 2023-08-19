import "dart:typed_data";

import "msg_pck.dart";

export "src/end_of_stream_exception.dart";
export "src/extension_header.dart";
export "src/extension_result.dart";
export "src/message_pack_code.dart";
export "src/message_pack_range.dart";
export "src/message_pack_reader.dart";
export "src/message_pack_serialization_exception.dart";
export "src/message_pack_type.dart";
export "src/message_pack_writer.dart";
export "src/mixins/message.dart";
export "src/nil.dart";

T fromMessagePack<T>(
  TypedData data,
  T Function(List<dynamic>) creator,
) {
  MessagePackReader reader = MessagePackReader.fromTypedData(data);
  List<dynamic> items = <dynamic>[];
  while (!reader.end) {
    items.add(reader.read());
  }

  return creator(items);
}
