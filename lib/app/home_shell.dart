import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/authentication/auth_screens.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/setup/setup_dialogs.dart';
import '../features/sms/presentation/sms_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../state/providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  void _pickWorkspace() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final list = ref.watch(workspacesProvider);
        final current = ref.watch(workspaceIdProvider);
        return SafeArea(
          child: ListView(shrinkWrap: true, children: [
            for (final w in list)
              ListTile(
                leading: Icon(w.id == current
                    ? Icons.check_circle
                    : Icons.circle_outlined),
                title: Text(w.name),
                subtitle: Text(w.type),
                onTap: () {
                  switchWorkspace(ref, w.id);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New workspace'),
              onTap: () {
                Navigator.pop(ctx);
                showNewWorkspaceDialog(context);
              },
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(workspacesProvider);
    final id = ref.watch(workspaceIdProvider);
    final name = list.isEmpty
        ? ''
        : list.firstWhere((w) => w.id == id, orElse: () => list.first).name;
    const pages = <Widget>[
      DashboardScreen(),
      TransactionsScreen(),
      SmsScreen(),
      SetupScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pickWorkspace,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
        actions: [
          IconButton(
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => lockApp(context, ref),
          ),
        ],
      ),
      body: pages[_tab],
      floatingActionButton: _tab == 1
          ? FloatingActionButton(
              onPressed: () => showTxForm(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.sms_outlined), label: 'SMS'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Setup'),
        ],
      ),
    );
  }
}
