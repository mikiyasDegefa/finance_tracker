import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'tx_detail_screen.dart';
import 'tx_filter.dart';

class TxTile extends StatelessWidget {
  const TxTile(
      {super.key, required this.tx, required this.accountName, this.onTap});
  final Tx tx;
  final String accountName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = tx.counterparty ??
        tx.description ??
        tx.category ??
        (tx.kind == null ? (tx.isCredit ? 'Credit' : 'Debit') : cap(tx.kind!));
    // Show only the sender (credit) or recipient (debit).
    final party = tx.isCredit ? tx.fromParty : tx.toParty;
    final partyLabel = party ?? tx.counterparty;
    final partyLine = partyLabel != null
        ? '${tx.isCredit ? 'From' : 'To'}: $partyLabel'
        : (tx.counterpartyAccount == null
            ? null
            : 'Account: ${tx.counterpartyAccount}');
    // Bank name followed by the reason (remark/category), e.g. "for package".
    final reason = tx.remark ?? tx.category;
    final meta = <String>[
      accountName,
      fmtDate(tx.occurredAt),
      if (reason != null && reason.isNotEmpty) reason,
    ].join(' · ');
    final extras = <String>[
      if (tx.serviceChargeMinor != 0)
        'service charge ${formatMinor(tx.serviceChargeMinor)}',
      if (tx.receiptUrl != null) 'receipt link',
    ].join(' · ');
    return ListTile(
      onTap: onTap ??
          () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TxDetailScreen(txId: tx.id))),
      isThreeLine: partyLine != null || extras.isNotEmpty,
      leading: CircleAvatar(
          child: Icon(tx.isCredit ? Icons.south_west : Icons.north_east)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (partyLine != null)
          Text(partyLine, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (extras.isNotEmpty)
          Text(extras, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
      trailing: Text(
        '${tx.isCredit ? '+' : '-'}${formatMinor(tx.amountMinor)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: tx.isCredit ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsState();
}

class _TransactionsState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    final n = ref.read(txFilterProvider.notifier);
    n.state = n.state.withQuery(q);
  }

  void _clearAll() {
    _search.clear();
    ref.read(txFilterProvider.notifier).state = const TxFilter();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(txFilterProvider);
    final txs = ref.watch(filteredTransactionsProvider);
    final total = ref.watch(transactionsProvider).length;
    final names = {
      for (final a in ref.watch(accountsProvider)) a.id: a.bankLabel
    };
    var credit = 0;
    var debit = 0;
    for (final t in txs) {
      if (t.isCredit) {
        credit += t.amountMinor;
      } else {
        debit += t.totalMinor;
      }
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Name, account no., remark, reference',
              ),
              onChanged: _setQuery,
            ),
          ),
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              isLabelVisible: filter.hasSheetFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const _FilterSheet(),
            ),
          ),
        ]),
      ),
      if (total > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
          child: Row(children: [
            Expanded(
              child: Text(
                '${txs.length} of $total · In ${formatMinor(credit)} · Out ${formatMinor(debit)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (filter.isActive)
              TextButton(
                  onPressed: _clearAll, child: const Text('Clear filters')),
          ]),
        ),
      Expanded(
        child: txs.isEmpty
            ? Center(
                child: Text(total == 0
                    ? 'No transactions yet. Tap + to add one.'
                    : 'No transactions match your filters.'))
            : ListView.builder(
                itemCount: txs.length,
                itemBuilder: (_, i) => TxTile(
                    tx: txs[i], accountName: names[txs[i].accountId] ?? '?'),
              ),
      ),
    ]);
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String _dir; // all | debit | credit
  int? _account;
  DateTimeRange? _range;
  final _min = TextEditingController();
  final _max = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = ref.read(txFilterProvider);
    _dir = f.direction ?? 'all';
    _account = f.accountId;
    _range = f.range;
    if (f.minMinor != null) _min.text = formatMinor(f.minMinor!);
    if (f.maxMinor != null) _max.text = formatMinor(f.maxMinor!);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  void _apply() {
    int? min;
    int? max;
    if (_min.text.trim().isNotEmpty) {
      min = parseMinor(_min.text);
      if (min == null) {
        setState(() => _error = 'Minimum amount is not a number');
        return;
      }
    }
    if (_max.text.trim().isNotEmpty) {
      max = parseMinor(_max.text);
      if (max == null) {
        setState(() => _error = 'Maximum amount is not a number');
        return;
      }
    }
    final query = ref.read(txFilterProvider).query;
    ref.read(txFilterProvider.notifier).state = TxFilter(
      query: query,
      direction: _dir == 'all' ? null : _dir,
      accountId: _account,
      range: _range,
      minMinor: min,
      maxMinor: max,
    );
    Navigator.pop(context);
  }

  void _reset() {
    final query = ref.read(txFilterProvider).query;
    ref.read(txFilterProvider.notifier).state = TxFilter(query: query);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    const money = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Filter transactions',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'debit', label: Text('Debited')),
              ButtonSegment(value: 'credit', label: Text('Credited')),
            ],
            selected: {_dir},
            onSelectionChanged: (s) => setState(() => _dir = s.first),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _account,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All accounts')),
              for (final a in accounts)
                DropdownMenuItem<int?>(value: a.id, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _account = v),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(_range == null
                    ? 'Any date'
                    : '${fmtDate(_range!.start).substring(0, 10)} - ${fmtDate(_range!.end).substring(0, 10)}'),
              ),
            ),
            if (_range != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _range = null),
              ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType: money,
                decoration: const InputDecoration(labelText: 'Min amount'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: money,
                decoration: const InputDecoration(labelText: 'Max amount'),
              ),
            ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(onPressed: _reset, child: const Text('Reset')),
            const Spacer(),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ]),
        ]),
      ),
    );
  }
}
