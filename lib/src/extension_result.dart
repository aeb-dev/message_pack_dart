import "dart:typed_data";

import "extension_header.dart";

class ExtensionResult {
  final int typeCode;
  final Uint8List data;
  final ExtensionHeader header;

  ExtensionResult(
    this.typeCode,
    this.data,
  ) : header = ExtensionHeader(typeCode, data.length);
}
