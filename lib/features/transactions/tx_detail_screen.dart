import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'tx_form.dart';

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class TxDetailScreen extends ConsumerWidget {
  const TxDetailScreen({super.key, required this.txId});
  final int txId;

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok)
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not open the link')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found =
        ref.watch(transactionsProvider).where((t) => t.id == txId).toList();
    if (found.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: Text('Transaction not found')),
      );
    }
    final Tx t = found.first;
    final accounts = {
      for (final a in ref.watch(accountsProvider)) a.id: a.label
    };
    final smsBody =
        t.smsId == null ? null : ref.read(repoProvider)?.smsBody(t.smsId!);
    final cur = t.currency;

    Widget row(String label, String? value, {Widget? trailing}) => value == null
        ? const SizedBox.shrink()
        : ListTile(
            dense: true,
            title: Text(label, style: Theme.of(context).textTheme.bodySmall),
            subtitle: SelectableText(value,
                style: Theme.of(context).textTheme.bodyLarge),
            trailing: trailing,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.isCredit ? 'Credit' : 'Debit'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showTxForm(context, edit: t),
          ),
        ],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${t.isCredit ? '+' : '-'}${formatMinor(t.amountMinor, cur)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: t.isCredit ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        row('Type', t.kind == null ? null : cap(t.kind!)),
        row(
            'Service charge',
            t.serviceChargeMinor == 0
                ? null
                : formatMinor(t.serviceChargeMinor, cur)),
        row('Total ${t.isCredit ? 'received' : 'debited'}',
            t.serviceChargeMinor == 0 ? null : formatMinor(t.totalMinor, cur)),
        // A credit only has a sender; a debit only has a recipient.
        row(
            t.isCredit ? 'From' : 'To',
            t.isCredit
                ? (t.fromParty ?? t.counterparty)
                : (t.toParty ?? t.counterparty)),
        row('Recipient / sender account', t.counterpartyAccount),
        row('Account', accounts[t.accountId]),
        row('Date', fmtDate(t.occurredAt)),
        row('Reference', t.reference),
        row('Balance after',
            t.balanceMinor == null ? null : formatMinor(t.balanceMinor!, cur)),
        row('Receipt link', t.receiptUrl,
            trailing: t.receiptUrl == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: t.receiptUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')));
                      },
                    ),
                    IconButton(
                      tooltip: 'Open',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _open(context, t.receiptUrl!),
                    ),
                  ])),
        row('Remark', t.remark),
        row('Category', t.category),
        row('Description', t.description),
        row('Source', t.source == 'sms' ? 'From SMS' : 'Manual entry'),
        if (smsBody != null)
          ExpansionTile(
            title: const Text('Original SMS'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SelectableText(smsBody),
              ),
            ],
          ),
      ]),
    );
  }
}
