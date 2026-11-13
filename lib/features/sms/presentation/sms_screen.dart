import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../parsing/parsing_engine.dart';
import '../sms_providers.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});
  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen> {
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _fetch() async {
    final gw = ref.read(smsGatewayProvider);
    if (!gw.isSupported) {
      _snack('This platform cannot read SMS. Use "Paste SMS" instead.');
      return;
    }
    final senders =
        ref.read(sourcesProvider).where((s) => s.active).map((s) => s.sender).toSet();
    if (senders.isEmpty) {
      _snack('Add at least one SMS sender in Setup first.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await gw.requestPermission()) {
        _snack('Allow the SMS permission, then tap Fetch again.');
        return;
      }
      final msgs = await gw.fetchFrom(senders);
      final repo = ref.read(repoProvider)!;
      final ws = ref.read(workspaceIdProvider)!;
      final added = repo.insertSmsBatch(ws, msgs);
      final s = repo.processPending(ws);
      _snack('Found ${msgs.length}, $added new. $s');
    } catch (e) {
      _snack('Fetch failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retry() {
    final repo = ref.read(repoProvider)!;
    final ws = ref.read(workspaceIdProvider)!;
    repo.requeueFailed(ws);
    _snack(repo.processPending(ws).toString());
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(smsListProvider);
    final mode = ref.watch(modeProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          const Text('Mode: '),
          DropdownButton<String>(
            value: mode,
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('Manual (review all)')),
              DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
              DropdownMenuItem(value: 'automatic', child: Text('Automatic')),
            ],
            onChanged: (v) => ref.read(repoProvider)!.setSetting('mode', v ?? 'hybrid'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, children: [
          FilledButton.icon(
            onPressed: _busy ? null : _fetch,
            icon: const Icon(Icons.download),
            label: const Text('Fetch SMS'),
          ),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => const _PasteSmsDialog()),
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste SMS'),
          ),
          TextButton(onPressed: _retry, child: const Text('Retry failed')),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No SMS stored yet. Configure a sender, then Fetch (Android) or Paste SMS (any platform).',
                      textAlign: TextAlign.center),
                ),
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  return ListTile(
                    onTap: () => showDialog<void>(
                        context: context, builder: (_) => SmsReviewDialog(msg: m)),
                    leading: _statusIcon(m.status),
                    title: Text('${m.sender} · ${m.status.replaceAll('_', ' ')}'),
                    subtitle: Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(fmtDate(m.receivedAt).substring(5, 10)),
                  );
                },
              ),
      ),
    ]);
  }

  Icon _statusIcon(String s) {
    switch (s) {
      case 'processed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'awaiting_review':
        return const Icon(Icons.rate_review, color: Colors.orange);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red);
      case 'duplicate':
        return const Icon(Icons.content_copy, color: Colors.grey);
      case 'ignored':
        return const Icon(Icons.block, color: Colors.grey);
      default:
        return const Icon(Icons.hourglass_empty);
    }
  }
}

class _PasteSmsDialog extends ConsumerStatefulWidget {
  const _PasteSmsDialog();
  @override
  ConsumerState<_PasteSmsDialog> createState() => _PasteState();
}

class _PasteState extends ConsumerState<_PasteSmsDialog> {
  final _body = TextEditingController();
  String? _sender;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sourcesProvider);
    if (s.isNotEmpty) _sender = s.first.sender;
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _save() {
    if (_sender == null || _body.text.trim().isEmpty) {
      setState(() => _error = 'Choose a sender and paste the SMS text');
      return;
    }
    final repo = ref.read(repoProvider)!;
    final ws = ref.read(workspaceIdProvider)!;
    repo.insertPastedSms(ws, _sender!, _body.text.trim());
    repo.processPending(ws);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final senders = ref.watch(sourcesProvider);
    return AlertDialog(
      title: const Text('Paste SMS'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: _sender,
            decoration: const InputDecoration(labelText: 'Sender'),
            items: [
              for (final s in senders)
                DropdownMenuItem(value: s.sender, child: Text(s.sender)),
            ],
            onChanged: (v) => setState(() => _sender = v),
          ),
          TextField(
            controller: _body,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'SMS text'),
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

class SmsReviewDialog extends ConsumerStatefulWidget {
  const SmsReviewDialog({super.key, required this.msg});
  final SmsMsg msg;
  @override
  ConsumerState<SmsReviewDialog> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<SmsReviewDialog> {
  late final ParseResult _res;
  late String _dir;
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _cp = TextEditingController();
  final _remark = TextEditingController();
  String? _error;

  bool get _editable =>
      widget.msg.status != 'processed' && widget.msg.status != 'ignored';

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repoProvider)!;
    _res = repo.parseMessage(ref.read(workspaceIdProvider)!, widget.msg);
    _dir = _res.direction ?? 'debit';
    _amount.text = _res.amountMinor == null ? '' : formatMinor(_res.amountMinor!);
    _ref.text = _res.reference ?? '';
    _cp.text = _res.counterparty ??
        (_dir == 'debit' ? _res.toParty : _res.fromParty) ??
        '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _cp.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _save() {
    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final st = ref.read(repoProvider)!.approveSms(
          ref.read(workspaceIdProvider)!,
          widget.msg.id,
          TxInput(
            direction: _dir,
            amountMinor: minor,
            reference: _ref.text,
            counterparty: _cp.text,
            counterpartyAccount: _res.counterpartyAccount,
            fromParty: _res.fromParty,
            toParty: _res.toParty,
            kind: _res.keyword,
            serviceChargeMinor: _res.serviceChargeMinor ?? 0,
            receiptUrl: _res.receiptUrl,
            remark: _remark.text,
            balanceMinor: _res.balanceMinor,
          ),
        );
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(st == 'processed' ? 'Transaction saved' : 'Not saved: $st')));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    final repo = ref.read(repoProvider)!;
    final extras = <String>[
      if (_res.keyword != null) 'Keyword: ${_res.keyword}',
      if (_res.fromParty != null) 'From: ${_res.fromParty}',
      if (_res.toParty != null) 'To: ${_res.toParty}',
      if (_res.counterpartyAccount != null) 'Account: ${_res.counterpartyAccount}',
      if (_res.serviceChargeMinor != null)
        'Service charge: ${formatMinor(_res.serviceChargeMinor!)}',
      if (_res.receiptUrl != null) 'Receipt: ${_res.receiptUrl}',
    ];
    return AlertDialog(
      title: Text('${m.sender} · ${m.status.replaceAll('_', ' ')}'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(m.body),
          if (m.note != null) Text(m.note!, style: const TextStyle(color: Colors.orange)),
          if (_res.errors.isNotEmpty && _editable)
            Text(_res.errors.join('; '), style: const TextStyle(color: Colors.red)),
          if (_editable) ...[
            const Divider(),
            if (extras.isNotEmpty) Text(extras.join('\n')),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'debit', label: Text('Debit')),
                ButtonSegment(value: 'credit', label: Text('Credit')),
              ],
              selected: {_dir},
              onSelectionChanged: (s) => setState(() => _dir = s.first),
            ),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference')),
            TextField(
                controller: _cp,
                decoration: const InputDecoration(labelText: 'Name (sent to / received from)')),
            TextField(
                controller: _remark,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remark')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(
          onPressed: () {
            repo.deleteSms(m.id);
            Navigator.pop(context);
          },
          child: const Text('Delete SMS'),
        ),
        if (_editable)
          TextButton(
            onPressed: () {
              repo.ignoreSms(m.id);
              Navigator.pop(context);
            },
            child: const Text('Ignore'),
          ),
        if (_editable) FilledButton(onPressed: _save, child: const Text('Save transaction')),
      ],
    );
  }
}
