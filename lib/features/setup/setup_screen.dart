import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../authentication/auth_screens.dart';
import '../parsing/template_screens.dart';
import 'setup_dialogs.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SetupScreen> {
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    ref.read(keyStoreProvider).biometricEnabled().then((v) {
      if (mounted) setState(() => _bio = v);
    });
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  Future<void> _toggleBio(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      if (!await biometricAvailable()) {
        messenger.showSnackBar(const SnackBar(content: Text('Biometrics not available on this device')));
        return;
      }
      if (!await biometricAuth('Enable biometric unlock')) return;
    }
    await ref.read(keyStoreProvider).setBiometric(on);
    if (mounted) setState(() => _bio = on);
  }

  Future<void> _deleteAllSms() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all SMS?'),
        content: const Text(
            'Removes all stored original SMS in this workspace. Saved transactions are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(repoProvider)!.deleteAllSms(ref.read(workspaceIdProvider)!);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(children: [
        ListTile(
          leading: const Icon(Icons.workspaces_outline),
          title: const Text('Workspaces'),
          onTap: () => _push(const WorkspacesScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_outlined),
          title: const Text('Accounts'),
          onTap: () => _push(const AccountsScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.sms_outlined),
          title: const Text('SMS senders'),
          onTap: () => _push(const SendersScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: const Text('Parsing templates'),
          onTap: () => _push(const TemplatesScreen()),
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Biometric unlock'),
          value: _bio,
          onChanged: _toggleBio,
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete all stored SMS'),
          onTap: _deleteAllSms,
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Lock now'),
          onTap: () => lockApp(context, ref),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Not built yet'),
          subtitle: Text(
              'Backup/restore, cloud sync, budgets, double-entry ledger, transfers, '
              'background SMS receiver, PIN change.'),
        ),
      ]);
}

class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(workspacesProvider);
    final current = ref.watch(workspaceIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workspaces')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showNewWorkspaceDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(children: [
        for (final w in list)
          ListTile(
            leading: Icon(w.id == current ? Icons.check_circle : Icons.circle_outlined),
            title: Text(w.name),
            subtitle: Text(w.type),
            onTap: () => switchWorkspace(ref, w.id),
          ),
      ]),
    );
  }
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAccountDialog(context),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? const Center(child: Text('No accounts. Tap + to add one.'))
          : ListView(children: [
              for (final a in list)
                ListTile(
                  onTap: () => showAccountDialog(context, edit: a),
                  title: Text(a.label),
                  subtitle: Text(
                      '${a.currency} · ${a.type} · balance ${formatMinor(a.balanceMinor)}\nTap to edit'),
                  isThreeLine: true,
                  trailing: Switch(
                    value: a.active,
                    onChanged: (v) => ref.read(repoProvider)!.setAccountActive(a.id, v),
                  ),
                ),
            ]),
    );
  }
}

class SendersScreen extends ConsumerWidget {
  const SendersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(sourcesProvider);
    final accs = {for (final a in ref.watch(accountsProvider)) a.id: a.label};
    final tpls = {for (final t in ref.watch(templatesProvider)) t.id: t.name};
    return Scaffold(
      appBar: AppBar(title: const Text('SMS senders')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddSenderDialog(context),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                    'Only senders listed here are ever read.\nCreate an account first, then add the bank\'s SMS sender.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(children: [
              for (final s in list)
                ListTile(
                  title: Text(s.sender),
                  subtitle: Text(
                      '${accs[s.accountId] ?? '?'} · template: ${tpls[s.templateId] ?? 'none'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: s.active,
                      onChanged: (v) => ref.read(repoProvider)!.setSourceActive(s.id, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(repoProvider)!.deleteSource(s.id),
                    ),
                  ]),
                ),
            ]),
    );
  }
}
