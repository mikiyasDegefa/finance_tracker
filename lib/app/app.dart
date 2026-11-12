import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/presentation/home_screen.dart';

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (_, __) => const HomeScreen())],
);

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Finance Tracker',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        routerConfig: _router,
      );
}
