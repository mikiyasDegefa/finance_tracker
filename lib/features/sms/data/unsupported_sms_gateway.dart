import '../domain/sms_gateway.dart';

class UnsupportedSmsGateway implements SmsGateway {
  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<RawSms>> fetchFrom(Set<String> senders, {DateTime? since}) {
    return Future.value(const <RawSms>[]);
  }
}
