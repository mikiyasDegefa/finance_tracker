import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import 'parsing_engine.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  void _open(BuildContext context, SmsTemplate? t) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TemplateEditorScreen(template: t)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Parsing templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(children: [
        for (final t in list)
          ListTile(
            title: Text(t.name),
            subtitle: Text('Amount: ${t.amountRegex}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _open(context, t),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(repoProvider)!.deleteTemplate(t.id!),
            ),
          ),
      ]),
    );
  }
}

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, this.template});
  final SmsTemplate? template;
  @override
  ConsumerState<TemplateEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<TemplateEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _credit;
  late final TextEditingController _debit;
  late final TextEditingController _amount;
  late final TextEditingController _balance;
  late final TextEditingController _reference;
  late final TextEditingController _cp;
  final _sample = TextEditingController();
  ParseResult? _result;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.name ?? '');
    _credit = TextEditingController(
        text: t?.creditKeywords ?? 'credited,received,deposited');
    _debit = TextEditingController(
        text: t?.debitKeywords ?? 'debited,withdrawn,paid,transferred');
    _amount = TextEditingController(
        text: t?.amountRegex ?? r'(?:ETB|Birr)\s*([\d,]+(?:\.\d+)?)');
    _balance = TextEditingController(text: t?.balanceRegex ?? '');
    _reference = TextEditingController(text: t?.referenceRegex ?? '');
    _cp = TextEditingController(text: t?.counterpartyRegex ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _credit,
      _debit,
      _amount,
      _balance,
      _reference,
      _cp,
      _sample
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  SmsTemplate _build() => SmsTemplate(
        id: widget.template?.id,
        name: _name.text.trim(),
        creditKeywords: _credit.text,
        debitKeywords: _debit.text,
        amountRegex: _amount.text,
        balanceRegex: _balance.text.trim().isEmpty ? null : _balance.text,
        referenceRegex: _reference.text.trim().isEmpty ? null : _reference.text,
        counterpartyRegex: _cp.text.trim().isEmpty ? null : _cp.text,
      );

  void _save() {
    if (_name.text.trim().isEmpty || _amount.text.trim().isEmpty) return;
    ref
        .read(repoProvider)!
        .saveTemplate(ref.read(workspaceIdProvider)!, _build());
    Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label, {String? help}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
              labelText: label, helperText: help, helperMaxLines: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'New template' : 'Edit template'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _field(_name, 'Template name'),
        _field(_credit, 'Credit keywords',
            help: 'Comma separated words that mean money came in'),
        _field(_debit, 'Debit keywords',
            help: 'Comma separated words that mean money went out'),
        _field(_amount, 'Amount regex',
            help: 'Capture group 1 must be the number, e.g. ETB\\s*([\\d,.]+)'),
        _field(_balance, 'Balance regex (optional)'),
        _field(_reference, 'Reference regex (optional)',
            help: 'Used to prevent duplicates'),
        _field(_cp, 'Counterparty regex (optional)'),
        const Divider(),
        Text('Test with a real SMS',
            style: Theme.of(context).textTheme.titleMedium),
        TextField(
          controller: _sample,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Paste an SMS here'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => setState(
                () => _result = ParsingEngine.parse(_sample.text, _build())),
            child: const Text('Test'),
          ),
        ),
        if (r != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Direction: ${r.direction ?? '-'}'),
                    Text(
                        'Amount: ${r.amountMinor == null ? '-' : formatMinor(r.amountMinor!)}'),
                    Text(
                        'Balance: ${r.balanceMinor == null ? '-' : formatMinor(r.balanceMinor!)}'),
                    Text('Reference: ${r.reference ?? '-'}'),
                    Text('Counterparty: ${r.counterparty ?? '-'}'),
                    Text('Currency: ${r.currency ?? '-'}'),
                    Text(r.isHighConfidence
                        ? 'High confidence (will auto-save in hybrid mode)'
                        : r.isValid
                            ? 'Valid, but no reference (hybrid mode will ask you to review)'
                            : 'Not valid: ${r.errors.join('; ')}'),
                  ]),
            ),
          ),
      ]),
    );
  }
}
