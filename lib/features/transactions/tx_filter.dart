import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class TxFilter {
  const TxFilter({
    this.query = '',
    this.direction,
    this.accountId,
    this.range,
    this.minMinor,
    this.maxMinor,
  });
  final String query; // name, account number, reference, remark, keyword...
  final String? direction; // credit | debit | null = all
  final int? accountId;
  final DateTimeRange? range;
  final int? minMinor;
  final int? maxMinor;

  /// True when any filter other than the search text is set.
  bool get hasSheetFilters =>
      direction != null ||
      accountId != null ||
      range != null ||
      minMinor != null ||
      maxMinor != null;

  bool get isActive => hasSheetFilters || query.trim().isNotEmpty;

  TxFilter withQuery(String q) => TxFilter(
        query: q,
        direction: direction,
        accountId: accountId,
        range: range,
        minMinor: minMinor,
        maxMinor: maxMinor,
      );

  bool matches(Tx t) {
    if (direction != null && t.direction != direction) return false;
    if (accountId != null && t.accountId != accountId) return false;
    final r = range;
    if (r != null) {
      final start = DateTime(r.start.year, r.start.month, r.start.day);
      final end = DateTime(r.end.year, r.end.month, r.end.day)
          .add(const Duration(days: 1));
      if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end))
        return false;
    }
    if (minMinor != null && t.amountMinor < minMinor!) return false;
    if (maxMinor != null && t.amountMinor > maxMinor!) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        t.counterparty,
        t.counterpartyAccount,
        t.fromParty,
        t.toParty,
        t.description,
        t.reference,
        t.remark,
        t.category,
        t.kind,
      ].whereType<String>().join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }
}

final txFilterProvider = StateProvider<TxFilter>((_) => const TxFilter());

final filteredTransactionsProvider = Provider<List<Tx>>((ref) {
  final f = ref.watch(txFilterProvider);
  return ref.watch(transactionsProvider).where(f.matches).toList();
});
