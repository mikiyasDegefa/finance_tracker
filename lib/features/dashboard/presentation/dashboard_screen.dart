import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money.dart';
import '../../../state/providers.dart';
import '../../transactions/transactions_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(accountsProvider);
    final active = all.where((a) => a.active).toList();
    final totals = ref.watch(monthTotalsProvider);
    final recent = ref.watch(transactionsProvider).take(5).toList();
    final names = {for (final a in all) a.id: a.label};
    final month = DateTime.now();

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (all.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Get started'),
            subtitle: Text(
                'Open Setup > Accounts to add a bank account, then Setup > SMS senders to link the bank\'s SMS sender and a parsing template.'),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'This month (${month.year}-${month.month.toString().padLeft(2, '0')})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Figure('Credits', totals.credit, Colors.green)),
              Expanded(child: _Figure('Debits', totals.debit, Colors.red)),
              Expanded(
                  child: _Figure('Net', totals.credit - totals.debit, null)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      if (active.isNotEmpty) ...[
        Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
        for (final a in active)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(a.label),
            subtitle: Text(a.currency),
            trailing: Text(formatMinor(a.balanceMinor),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
      const SizedBox(height: 8),
      Text('Recent transactions',
          style: Theme.of(context).textTheme.titleMedium),
      if (recent.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('Nothing yet.')),
      for (final t in recent)
        TxTile(tx: t, accountName: names[t.accountId] ?? '?'),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.minor, this.color);
  final String label;
  final int minor;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(formatMinor(minor),
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]);
}
