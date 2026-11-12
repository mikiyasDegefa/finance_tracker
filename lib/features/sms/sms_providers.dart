import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/android_sms_gateway.dart';
import 'data/unsupported_sms_gateway.dart';
import 'domain/sms_gateway.dart';

final smsGatewayProvider = Provider<SmsGateway>(
  (_) => Platform.isAndroid ? AndroidSmsGateway() : UnsupportedSmsGateway(),
);
