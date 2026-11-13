import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

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
  final _name = TextEditingController();
  final _remark = TextEditingController();
  final _kind = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _cpAccount = TextEditingController();
  final _fee = TextEditingController();
  final _receipt = TextEditingController();
  final _category = TextEditingController();
  final _desc = TextEditingController();
  final _ref = TextEditingController();
  String? _error;

  List<TextEditingController> get _all => [
        _amount,
        _name,
        _remark,
        _kind,
        _from,
        _to,
        _cpAccount,
        _fee,
        _receipt,
        _category,
        _desc,
        _ref,
      ];

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
      _name.text = e.counterparty ?? '';
      _remark.text = e.remark ?? '';
      _kind.text = e.kind ?? '';
      _from.text = e.fromParty ?? '';
      _to.text = e.toParty ?? '';
      _cpAccount.text = e.counterpartyAccount ?? '';
      _fee.text =
          e.serviceChargeMinor == 0 ? '' : formatMinor(e.serviceChargeMinor);
      _receipt.text = e.receiptUrl ?? '';
      _category.text = e.category ?? '';
      _desc.text = e.description ?? '';
      _ref.text = e.reference ?? '';
    } else if (accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
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
    final fee = _fee.text.trim().isEmpty ? 0 : parseMinor(_fee.text);
    if (fee == null) {
      setState(() => _error = 'Service charge is not a valid number');
      return;
    }
    final input = TxInput(
      accountId: _accountId,
      direction: _dir,
      amountMinor: minor,
      occurredAt: _date,
      reference: _ref.text,
      counterparty: _name.text,
      counterpartyAccount: _cpAccount.text,
      fromParty: _from.text,
      toParty: _to.text,
      kind: _kind.text,
      serviceChargeMinor: fee,
      receiptUrl: _receipt.text,
      remark: _remark.text,
      category: _category.text,
      description: _desc.text,
    );
    try {
      if (widget.edit == null) {
        repo.addTransaction(ws, input);
      } else {
        repo.updateTransaction(ws, widget.edit!.id, input);
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

  Widget _tf(TextEditingController c, String label,
          {TextInputType? type, int lines = 1}) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final accounts = ref
        .watch(accountsProvider)
        .where((a) => a.active || a.id == _accountId)
        .toList();
    final e = widget.edit;
    final hasExtras = e != null &&
        (e.kind != null ||
            e.fromParty != null ||
            e.toParty != null ||
            e.counterpartyAccount != null ||
            e.serviceChargeMinor != 0 ||
            e.receiptUrl != null);
    const money = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(e == null ? 'New transaction' : 'Edit transaction',
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
          _tf(_amount, 'Amount', type: money),
          _tf(_name, 'Name (sent to / received from)'),
          _tf(_remark, 'Remark', lines: 2),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(fmtDate(_date)),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: hasExtras,
            title: const Text('More details'),
            children: [
              _tf(_kind, 'Type / keyword (e.g. transferred)'),
              _tf(_from, 'From'),
              _tf(_to, 'To'),
              _tf(_cpAccount, 'Recipient / sender account number'),
              _tf(_fee, 'Service charge (added to a debit)', type: money),
              _tf(_receipt, 'Receipt link', type: TextInputType.url),
              _tf(_ref, 'Reference'),
              _tf(_category, 'Category'),
              _tf(_desc, 'Description'),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          Row(children: [
            if (e != null)
              TextButton(onPressed: _delete, child: const Text('Delete')),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }
}
