import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sms/sms_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sms = ref.watch(smsGatewayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Tracker')),
      body: Center(
        child: Text(sms.isSupported
            ? 'SMS collection available'
            : 'SMS collection unavailable on this platform.\nUse manual entry or import.'),
      ),
    );
  }
}
