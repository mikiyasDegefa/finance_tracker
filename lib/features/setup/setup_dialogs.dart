import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

Future<void> showNewWorkspaceDialog(BuildContext context) => showDialog<void>(
    context: context, builder: (_) => const _NewWorkspaceDialog());

class _NewWorkspaceDialog extends ConsumerStatefulWidget {
  const _NewWorkspaceDialog();
  @override
  ConsumerState<_NewWorkspaceDialog> createState() => _NewWorkspaceState();
}

class _NewWorkspaceState extends ConsumerState<_NewWorkspaceDialog> {
  final _name = TextEditingController();
  String _type = 'personal';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New workspace'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name')),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'personal', child: Text('Personal')),
              DropdownMenuItem(value: 'business', child: Text('Business')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'personal'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) return;
              final id = ref
                  .read(repoProvider)!
                  .createWorkspace(_name.text.trim(), _type);
              switchWorkspace(ref, id);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      );
}

Future<void> showAccountDialog(BuildContext context, {Account? edit}) =>
    showDialog<void>(
        context: context, builder: (_) => _AccountDialog(edit: edit));

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({this.edit});
  final Account? edit;
  @override
  ConsumerState<_AccountDialog> createState() => _AccountState();
}

class _AccountState extends ConsumerState<_AccountDialog> {
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _mask = TextEditingController();
  final _cur = TextEditingController(text: 'ETB');
  final _open = TextEditingController(text: '0');
  String _type = 'bank';
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _bank.text = e.bank;
      _name.text = e.name;
      _mask.text = e.numberMask ?? '';
      _cur.text = e.currency;
      _open.text = formatMinor(e.openingMinor);
      _type = e.type;
    }
  }

  @override
  void dispose() {
    for (final c in [_bank, _name, _mask, _cur, _open]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final opening = parseMinor(_open.text);
    if (_name.text.trim().isEmpty || opening == null) {
      setState(() => _error = 'Enter a name and a valid opening balance');
      return;
    }
    final repo = ref.read(repoProvider)!;
    final ws = ref.read(workspaceIdProvider)!;
    final bank = _bank.text.trim();
    final name = _name.text.trim();
    final mask = _mask.text.trim().isEmpty ? null : _mask.text.trim();
    final cur =
        _cur.text.trim().isEmpty ? 'ETB' : _cur.text.trim().toUpperCase();
    if (widget.edit == null) {
      repo.addAccount(ws,
          bank: bank,
          name: name,
          mask: mask,
          currency: cur,
          type: _type,
          openingMinor: opening);
    } else {
      repo.updateAccount(ws, widget.edit!.id,
          bank: bank,
          name: name,
          mask: mask,
          currency: cur,
          type: _type,
          openingMinor: opening);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.edit == null ? 'New account' : 'Edit account'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _bank,
                decoration:
                    const InputDecoration(labelText: 'Bank (e.g. CBE)')),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Account name')),
            TextField(
                controller: _mask,
                decoration: const InputDecoration(
                    labelText: 'Masked number (optional)')),
            TextField(
                controller: _cur,
                decoration: const InputDecoration(labelText: 'Currency')),
            TextField(
              controller: _open,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Opening balance'),
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'bank', child: Text('Bank account')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'bank'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

Future<void> showAddSenderDialog(BuildContext context) => showDialog<void>(
    context: context, builder: (_) => const _AddSenderDialog());

class _AddSenderDialog extends ConsumerStatefulWidget {
  const _AddSenderDialog();
  @override
  ConsumerState<_AddSenderDialog> createState() => _AddSenderState();
}

class _AddSenderState extends ConsumerState<_AddSenderDialog> {
  final _sender = TextEditingController();
  int? _account;
  int? _template;
  String? _error;

  @override
  void initState() {
    super.initState();
    final accs = ref.read(accountsProvider).where((a) => a.active).toList();
    if (accs.isNotEmpty) _account = accs.first.id;
    final tpls = ref.read(templatesProvider);
    if (tpls.isNotEmpty) _template = tpls.first.id;
  }

  @override
  void dispose() {
    _sender.dispose();
    super.dispose();
  }

  void _save() {
    if (_sender.text.trim().isEmpty || _account == null) {
      setState(() => _error = 'Enter the sender and choose an account');
      return;
    }
    try {
      ref.read(repoProvider)!.addSource(
          ref.read(workspaceIdProvider)!, _sender.text, _account!, _template);
      Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'This sender is already configured');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accs = ref.watch(accountsProvider).where((a) => a.active).toList();
    final tpls = ref.watch(templatesProvider);
    return AlertDialog(
      title: const Text('New SMS sender'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _sender,
            decoration: const InputDecoration(
                labelText: 'Sender name or number',
                helperText: 'Exactly as shown in your SMS app'),
          ),
          DropdownButtonFormField<int>(
            value: _account,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              for (final a in accs)
                DropdownMenuItem(value: a.id, child: Text(a.label))
            ],
            onChanged: (v) => setState(() => _account = v),
          ),
          DropdownButtonFormField<int?>(
            value: _template,
            decoration: const InputDecoration(labelText: 'Parsing template'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              for (final t in tpls)
                DropdownMenuItem<int?>(
                    value: t.id,
                    child: Text(t.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _template = v),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
