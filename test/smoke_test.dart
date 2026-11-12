import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/app/app.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinanceApp()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
