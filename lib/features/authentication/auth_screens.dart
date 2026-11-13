import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/database/app_database.dart';
import '../../state/providers.dart';

Future<bool> biometricAvailable() async {
  try {
    final a = LocalAuthentication();
    return await a.isDeviceSupported() && await a.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAuth(String reason) async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}

/// Opens the encrypted database and enters the app.
Future<void> completeUnlock(WidgetRef ref) async {
  if (ref.read(dbProvider) == null) {
    final key = await ref.read(keyStoreProvider).dbKeyHex();
    final db = await AppDatabase.openEncrypted(key);
    ref.read(dbProvider.notifier).state = db;
  }
  final repo = ref.read(repoProvider)!;
  var list = repo.workspaces();
  if (list.isEmpty) {
    repo.createWorkspace('Personal', 'personal');
    list = repo.workspaces();
  }
  final saved = int.tryParse(repo.setting('current_workspace') ?? '');
  final id = list.any((w) => w.id == saved) ? saved! : list.first.id;
  ref.read(workspaceIdProvider.notifier).state = id;
  ref.read(authStageProvider.notifier).state = AuthStage.unlocked;
}

void lockApp(BuildContext context, WidgetRef ref) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ref.read(authStageProvider.notifier).state = AuthStage.locked;
}

class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});
  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinState();
}

class _SetupPinState extends ConsumerState<SetupPinScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _bio = false;
  bool _bioAvail = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    biometricAvailable().then((v) {
      if (mounted) setState(() => _bioAvail = v);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 4 to 8 digits');
      return;
    }
    if (pin != _confirm.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    setState(() => _busy = true);
    final ks = ref.read(keyStoreProvider);
    await ks.setPin(pin);
    if (_bio && await biometricAuth('Enable biometric unlock')) {
      await ks.setBiometric(true);
    }
    try {
      await completeUnlock(ref);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not open database: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create your PIN')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('This PIN protects your financial data on this device.'),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN (4-8 digits)'),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
          ),
          if (_bioAvail)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unlock with fingerprint / face'),
              value: _bio,
              onChanged: (v) => setState(() => _bio = v),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Continue'),
          ),
        ]),
      );
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockState();
}

class _LockState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _bio() async {
    if (!await ref.read(keyStoreProvider).biometricEnabled()) return;
    if (!mounted) return;
    if (await biometricAuth('Unlock Finance Tracker') && mounted) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    try {
      await completeUnlock(ref);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open database: $e');
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await ref.read(keyStoreProvider).verifyPin(_pin.text);
    if (!mounted) return;
    if (res.ok) {
      await _finish();
      if (mounted) setState(() => _busy = false);
      return;
    }
    _pin.clear();
    setState(() {
      _busy = false;
      _error = res.lockedSeconds > 0
          ? 'Too many attempts. Try again in ${res.lockedSeconds}s'
          : 'Wrong PIN (${res.attemptsLeft} attempts left before lockout)';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 12),
                  const Text('Finance Tracker', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Enter PIN'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _submit, child: const Text('Unlock')),
                  TextButton.icon(
                    onPressed: _bio,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
