// ignore_for_file: avoid_classes_with_only_static_members, public_member_api_docs

import "message_pack_type.dart";

class MessagePackCode {
  static const int minFixInt = 0x00; // 0
  static const int maxFixInt = 0x7f; // 127
  static const int minFixMap = 0x80; // 128
  static const int maxFixMap = 0x8f; // 143
  static const int minFixArray = 0x90; // 144
  static const int maxFixArray = 0x9f; // 159
  static const int minFixStr = 0xa0; // 160
  static const int maxFixStr = 0xbf; // 191
  static const int nil = 0xc0;
  static const int neverUsed = 0xc1;
  static const int false_ = 0xc2;
  static const int true_ = 0xc3;
  static const int bin8 = 0xc4;
  static const int bin16 = 0xc5;
  static const int bin32 = 0xc6;
  static const int ext8 = 0xc7;
  static const int ext16 = 0xc8;
  static const int ext32 = 0xc9;
  static const int float32 = 0xca;
  static const int float64 = 0xcb;
  static const int uint8 = 0xcc;
  static const int uint16 = 0xcd;
  static const int uint32 = 0xce;
  static const int uint64 = 0xcf;
  static const int int8 = 0xd0;
  static const int int16 = 0xd1;
  static const int int32 = 0xd2;
  static const int int64 = 0xd3;
  static const int fixExt1 = 0xd4;
  static const int fixExt2 = 0xd5;
  static const int fixExt4 = 0xd6;
  static const int fixExt8 = 0xd7;
  static const int fixExt16 = 0xd8;
  static const int str8 = 0xd9;
  static const int str16 = 0xda;
  static const int str32 = 0xdb;
  static const int array16 = 0xdc;
  static const int array32 = 0xdd;
  static const int map16 = 0xde;
  static const int map32 = 0xdf;
  static const int minNegativeFixInt = 0xe0; // 224
  static const int maxNegativeFixInt = 0xff; // 255

  static final List<MessagePackType> _typeLookupTable = _initTypeLookupTable();
  static final List<String> _formatNameTable = _initTypeNameTable();

  static List<MessagePackType> _initTypeLookupTable() {
    List<MessagePackType> typeLookupTable =
        List<MessagePackType>.filled(256, MessagePackType.unknown);
    for (int i = minFixInt; i <= maxFixInt; i++) {
      typeLookupTable[i] = MessagePackType.integer;
    }

    for (int i = minFixMap; i <= maxFixMap; i++) {
      typeLookupTable[i] = MessagePackType.map;
    }

    for (int i = minFixArray; i <= maxFixArray; i++) {
      typeLookupTable[i] = MessagePackType.array;
    }

    for (int i = minFixStr; i <= maxFixStr; i++) {
      typeLookupTable[i] = MessagePackType.string;
    }

    typeLookupTable[nil] = MessagePackType.nil;
    typeLookupTable[neverUsed] = MessagePackType.unknown;
    typeLookupTable[false_] = MessagePackType.boolean;
    typeLookupTable[true_] = MessagePackType.boolean;
    typeLookupTable[bin8] = MessagePackType.binary;
    typeLookupTable[bin16] = MessagePackType.binary;
    typeLookupTable[bin32] = MessagePackType.binary;
    typeLookupTable[ext8] = MessagePackType.extension;
    typeLookupTable[ext16] = MessagePackType.extension;
    typeLookupTable[ext32] = MessagePackType.extension;
    typeLookupTable[float32] = MessagePackType.float;
    typeLookupTable[float64] = MessagePackType.float;
    typeLookupTable[uint8] = MessagePackType.integer;
    typeLookupTable[uint16] = MessagePackType.integer;
    typeLookupTable[uint32] = MessagePackType.integer;
    typeLookupTable[uint64] = MessagePackType.integer;
    typeLookupTable[int8] = MessagePackType.integer;
    typeLookupTable[int16] = MessagePackType.integer;
    typeLookupTable[int32] = MessagePackType.integer;
    typeLookupTable[int64] = MessagePackType.integer;
    typeLookupTable[fixExt1] = MessagePackType.extension;
    typeLookupTable[fixExt2] = MessagePackType.extension;
    typeLookupTable[fixExt4] = MessagePackType.extension;
    typeLookupTable[fixExt8] = MessagePackType.extension;
    typeLookupTable[fixExt16] = MessagePackType.extension;
    typeLookupTable[str8] = MessagePackType.string;
    typeLookupTable[str16] = MessagePackType.string;
    typeLookupTable[str32] = MessagePackType.string;
    typeLookupTable[array16] = MessagePackType.array;
    typeLookupTable[array32] = MessagePackType.array;
    typeLookupTable[map16] = MessagePackType.map;
    typeLookupTable[map32] = MessagePackType.map;

    for (int i = minNegativeFixInt; i <= maxNegativeFixInt; i++) {
      typeLookupTable[i] = MessagePackType.integer;
    }

    return typeLookupTable;
  }

  static List<String> _initTypeNameTable() {
    List<String> formatNameTable = List<String>.filled(256, "");
    for (int i = minFixInt; i <= maxFixInt; i++) {
      formatNameTable[i] = "positive fixint";
    }

    for (int i = minFixMap; i <= maxFixMap; i++) {
      formatNameTable[i] = "fixmap";
    }

    for (int i = minFixArray; i <= maxFixArray; i++) {
      formatNameTable[i] = "fixarray";
    }

    for (int i = minFixStr; i <= maxFixStr; i++) {
      formatNameTable[i] = "fixstr";
    }

    formatNameTable[nil] = "nil";
    formatNameTable[neverUsed] = "(never used)";
    formatNameTable[false_] = "false";
    formatNameTable[true_] = "true";
    formatNameTable[bin8] = "bin 8";
    formatNameTable[bin16] = "bin 16";
    formatNameTable[bin32] = "bin 32";
    formatNameTable[ext8] = "ext 8";
    formatNameTable[ext16] = "ext 16";
    formatNameTable[ext32] = "ext 32";
    formatNameTable[float32] = "float 32";
    formatNameTable[float64] = "float 64";
    formatNameTable[uint8] = "uint 8";
    formatNameTable[uint16] = "uint 16";
    formatNameTable[uint32] = "uint 32";
    formatNameTable[uint64] = "uint 64";
    formatNameTable[int8] = "int 8";
    formatNameTable[int16] = "int 16";
    formatNameTable[int32] = "int 32";
    formatNameTable[int64] = "int 64";
    formatNameTable[fixExt1] = "fixext 1";
    formatNameTable[fixExt2] = "fixext 2";
    formatNameTable[fixExt4] = "fixext 4";
    formatNameTable[fixExt8] = "fixext 8";
    formatNameTable[fixExt16] = "fixext 16";
    formatNameTable[str8] = "str 8";
    formatNameTable[str16] = "str 16";
    formatNameTable[str32] = "str 32";
    formatNameTable[array16] = "array 16";
    formatNameTable[array32] = "array 32";
    formatNameTable[map16] = "map 16";
    formatNameTable[map32] = "map 32";

    for (int i = minNegativeFixInt; i <= maxNegativeFixInt; i++) {
      formatNameTable[i] = "negative fixint";
    }

    return formatNameTable;
  }

  static MessagePackType toMessagePackType(int code) => _typeLookupTable[code];

  static String toFormatName(int code) => _formatNameTable[code];
}
