import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

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
        (tx.isCredit ? 'Credit' : 'Debit');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
          child: Icon(tx.isCredit ? Icons.south_west : Icons.north_east)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '$accountName · ${fmtDate(tx.occurredAt)}${tx.source == 'sms' ? ' · SMS' : ''}'),
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
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(transactionsProvider);
    final names = {for (final a in ref.watch(accountsProvider)) a.id: a.label};
    final q = _q.toLowerCase();
    final txs = q.isEmpty
        ? all
        : all.where((t) {
            final hay =
                '${t.counterparty} ${t.description} ${t.reference} ${t.category}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Search transactions'),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: txs.isEmpty
            ? const Center(
                child: Text('No transactions yet. Tap + to add one.'))
            : ListView.builder(
                itemCount: txs.length,
                itemBuilder: (_, i) => TxTile(
                  tx: txs[i],
                  accountName: names[txs[i].accountId] ?? '?',
                  onTap: () => showTxForm(context, edit: txs[i]),
                ),
              ),
      ),
    ]);
  }
}

Future<void> showTxForm(BuildContext context, {Tx? edit}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TxForm(edit: edit),
    );

class TxForm extends ConsumerStatefulWidget {
  const TxForm({super.key, this.edit});
  final Tx? edit;
  @override
  ConsumerState<TxForm> createState() => _TxFormState();
}

class _TxFormState extends ConsumerState<TxForm> {
  int? _accountId;
  String _dir = 'debit';
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _desc = TextEditingController();
  final _ref = TextEditingController();
  final _cp = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    final accounts = ref.read(accountsProvider).where((a) => a.active).toList();
    if (e != null) {
      _accountId = e.accountId;
      _dir = e.direction;
      _date = e.occurredAt;
      _amount.text = formatMinor(e.amountMinor);
      _category.text = e.category ?? '';
      _desc.text = e.description ?? '';
      _ref.text = e.reference ?? '';
      _cp.text = e.counterparty ?? '';
    } else if (accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _category, _desc, _ref, _cp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() =>
          _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  void _save() {
    final repo = ref.read(repoProvider)!;
    final ws = ref.read(workspaceIdProvider)!;
    final minor = parseMinor(_amount.text);
    if (_accountId == null) {
      setState(() => _error = 'Create an account first (Setup > Accounts)');
      return;
    }
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    try {
      if (widget.edit == null) {
        repo.addTransaction(ws,
            accountId: _accountId!,
            direction: _dir,
            amountMinor: minor,
            occurredAt: _date,
            reference: _ref.text,
            counterparty: _cp.text,
            category: _category.text,
            description: _desc.text);
      } else {
        repo.updateTransaction(ws, widget.edit!.id,
            accountId: _accountId!,
            direction: _dir,
            amountMinor: minor,
            occurredAt: _date,
            reference: _ref.text,
            counterparty: _cp.text,
            category: _category.text,
            description: _desc.text);
      }
      Navigator.pop(context);
    } on DuplicateException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _delete() {
    ref
        .read(repoProvider)!
        .deleteTransaction(ref.read(workspaceIdProvider)!, widget.edit!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref
        .watch(accountsProvider)
        .where((a) => a.active || a.id == _accountId)
        .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.edit == null ? 'New transaction' : 'Edit transaction',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'debit', label: Text('Debit (out)')),
              ButtonSegment(value: 'credit', label: Text('Credit (in)')),
            ],
            selected: {_dir},
            onSelectionChanged: (s) => setState(() => _dir = s.first),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          TextField(
              controller: _cp,
              decoration:
                  const InputDecoration(labelText: 'Counterparty (optional)')),
          TextField(
              controller: _category,
              decoration:
                  const InputDecoration(labelText: 'Category (optional)')),
          TextField(
              controller: _desc,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)')),
          TextField(
              controller: _ref,
              decoration:
                  const InputDecoration(labelText: 'Reference (optional)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(fmtDate(_date)),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          Row(children: [
            if (widget.edit != null)
              TextButton(onPressed: _delete, child: const Text('Delete')),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }
}
