import 'package:flutter/services.dart';
import '../domain/sms_gateway.dart';

class AndroidSmsGateway implements SmsGateway {
  static const _ch = MethodChannel('app/sms');

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async =>
      (await _ch.invokeMethod<bool>('requestPermission')) ?? false;

  @override
  Future<List<RawSms>> fetchFrom(Set<String> senders, {DateTime? since}) async {
    final rows = await _ch.invokeListMethod<Map>('fetch', {
      'senders': senders.toList(),
      'since': since?.millisecondsSinceEpoch,
    });
    return (rows ?? [])
        .map((m) => RawSms(
              sender: m['sender'] as String,
              body: m['body'] as String,
              receivedAt: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
              providerId: m['id'].toString(),
            ))
        .toList();
  }
}
