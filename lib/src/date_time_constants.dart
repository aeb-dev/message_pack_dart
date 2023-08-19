// ignore_for_file: public_member_api_docs, avoid_classes_with_only_static_members

class DateTimeConstants {
  static const int bclSecondsAtUnixEpoch = 62135596800;
  static const int nanosecondsPerTick = 100;
  static const int nanosecondsPerMicrosecond = 1000;
  static final DateTime unixEpoch = DateTime(1970).toUtc();
}
