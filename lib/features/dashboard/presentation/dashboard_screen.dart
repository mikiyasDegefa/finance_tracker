import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../transactions/transactions_screen.dart';

enum DashboardPeriod { day, month }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.month;
  DateTime _anchor = DateTime.now();
  int? _selectedAccountId;

  /// First moment of the selected day or month.
  DateTime get _start => _period == DashboardPeriod.day
      ? DateTime(_anchor.year, _anchor.month, _anchor.day)
      : DateTime(_anchor.year, _anchor.month, 1);

  /// First moment after the selected period.
  DateTime get _end => _period == DashboardPeriod.day
      ? _start.add(const Duration(days: 1))
      : DateTime(_start.year, _start.month + 1, 1);

  bool get _isCurrent {
    final now = DateTime.now();
    final s = _start;
    if (_period == DashboardPeriod.day) {
      return s.year == now.year && s.month == now.month && s.day == now.day;
    }
    return s.year == now.year && s.month == now.month;
  }

  String get _label {
    final s = _start;
    if (_period == DashboardPeriod.day) {
      return '${_isCurrent ? 'Today' : 'Day'} '
          '(${s.year}-${_two(s.month)}-${_two(s.day)})';
    }
    return '${_isCurrent ? 'This month' : 'Month'} '
        '(${s.year}-${_two(s.month)})';
  }

  void _step(int direction) => setState(() {
        _anchor = _period == DashboardPeriod.day
            ? _start.add(Duration(days: direction))
            : DateTime(_start.year, _start.month + direction, 1);
      });

  void _selectPeriod(DashboardPeriod period) => setState(() {
        _period = period;
        _anchor = DateTime.now();
      });

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(accountsProvider);
    final active = all.where((a) => a.active).toList();
    final txs = ref.watch(transactionsProvider);
    final recent = txs.take(5).toList();
    final names = {for (final a in all) a.id: a.bankLabel};

    Account? selectedAccount;
    for (final a in all) {
      if (a.id == _selectedAccountId) {
        selectedAccount = a;
        break;
      }
    }
    final scopeId = selectedAccount?.id;

    var credit = 0;
    var debit = 0;
    for (final t in txs) {
      if (t.occurredAt.isBefore(_start) || !t.occurredAt.isBefore(_end)) {
        continue;
      }
      if (scopeId != null && t.accountId != scopeId) {
        continue;
      }
      if (t.isCredit) {
        credit += t.amountMinor;
      } else {
        debit += t.totalMinor;
      }
    }

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
            Text(_label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              selectedAccount == null ? 'All accounts' : selectedAccount.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<DashboardPeriod>(
              segments: const [
                ButtonSegment(value: DashboardPeriod.day, label: Text('Day')),
                ButtonSegment(
                    value: DashboardPeriod.month, label: Text('Month')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _selectPeriod(s.first),
            ),
            Row(children: [
              IconButton(
                tooltip: _period == DashboardPeriod.day
                    ? 'Previous day'
                    : 'Previous month',
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              const Spacer(),
              if (!_isCurrent)
                TextButton(
                  onPressed: () => setState(() => _anchor = DateTime.now()),
                  child: Text(
                      _period == DashboardPeriod.day ? 'Today' : 'This month'),
                ),
              IconButton(
                tooltip:
                    _period == DashboardPeriod.day ? 'Next day' : 'Next month',
                onPressed: _isCurrent ? null : () => _step(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _Figure('Credits', credit, Colors.green)),
              Expanded(child: _Figure('Debits', debit, Colors.red)),
              Expanded(child: _Figure('Net', credit - debit, null)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      if (active.isNotEmpty) ...[
        Row(children: [
          Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (selectedAccount != null)
            TextButton(
              onPressed: () => setState(() => _selectedAccountId = null),
              child: const Text('Show all'),
            ),
        ]),
        for (final a in active)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: a.id == _selectedAccountId,
            leading: Icon(
              a.id == _selectedAccountId
                  ? Icons.check_circle
                  : Icons.account_balance_wallet_outlined,
            ),
            title: Text(a.label),
            subtitle: Text(a.currency),
            trailing: Text(formatMinor(a.balanceMinor),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => setState(() =>
                _selectedAccountId = _selectedAccountId == a.id ? null : a.id),
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

String _two(int v) => v.toString().padLeft(2, '0');

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
