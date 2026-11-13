import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/authentication/auth_screens.dart';
import '../state/providers.dart';
import 'home_shell.dart';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Finance Tracker',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const AppRoot(),
      );
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});
  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final has = await ref.read(keyStoreProvider).hasPin();
    ref.read(authStageProvider.notifier).state =
        has ? AuthStage.locked : AuthStage.setupPin;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away > const Duration(seconds: 60) &&
          ref.read(authStageProvider) == AuthStage.unlocked) {
        lockApp(context, ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (ref.watch(authStageProvider)) {
      case AuthStage.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStage.setupPin:
        return const SetupPinScreen();
      case AuthStage.locked:
        return const LockScreen();
      case AuthStage.unlocked:
        return const HomeShell();
    }
  }
}
