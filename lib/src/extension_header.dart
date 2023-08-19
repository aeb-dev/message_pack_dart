import "package:meta/meta.dart";

@immutable
class ExtensionHeader {
  final int typeCode;
  final int length;

  const ExtensionHeader(this.typeCode, this.length);

  @override
  bool operator ==(Object other) =>
      other is ExtensionHeader &&
      other.typeCode == typeCode &&
      other.length == other.length;

  @override
  int get hashCode => Object.hash(typeCode, length);
}
