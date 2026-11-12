class RawSms {
  const RawSms({
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.providerId,
  });
  final String sender;
  final String body;
  final DateTime receivedAt;
  final String providerId; // Android SMS _id, used for duplicate detection
}

/// Platform boundary for SMS collection. iOS cannot read the inbox,
/// so it uses UnsupportedSmsGateway and relies on manual entry/import.
abstract class SmsGateway {
  bool get isSupported;
  Future<bool> requestPermission();
  Future<List<RawSms>> fetchFrom(Set<String> senders, {DateTime? since});
}
