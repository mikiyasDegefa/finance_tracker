import '../../core/money.dart';

/// Declarative template. No user code is ever executed: only keyword lists
/// and regular expressions (capture group 1 is the extracted value).
class SmsTemplate {
  const SmsTemplate({
    this.id,
    required this.name,
    required this.creditKeywords,
    required this.debitKeywords,
    required this.amountRegex,
    this.balanceRegex,
    this.referenceRegex,
    this.counterpartyRegex,
    this.fromRegex,
    this.toRegex,
    this.counterpartyAccountRegex,
    this.serviceChargeRegex,
    this.receiptRegex,
  });
  final int? id;
  final String name;
  final String creditKeywords; // comma separated
  final String debitKeywords; // comma separated
  final String amountRegex;
  final String? balanceRegex;
  final String? referenceRegex;
  final String? counterpartyRegex;
  final String? fromRegex;
  final String? toRegex;
  final String? counterpartyAccountRegex;
  final String? serviceChargeRegex;
  final String?
      receiptRegex; // optional; the first http(s) link is used otherwise
}

class ParseResult {
  const ParseResult({
    this.direction,
    this.keyword,
    this.amountMinor,
    this.balanceMinor,
    this.reference,
    this.counterparty,
    this.counterpartyAccount,
    this.fromParty,
    this.toParty,
    this.serviceChargeMinor,
    this.receiptUrl,
    this.currency,
    this.errors = const [],
  });
  final String? direction; // credit | debit
  final String? keyword; // the matched keyword, e.g. "transferred"
  final int? amountMinor;
  final int? balanceMinor;
  final String? reference;
  final String? counterparty;
  final String? counterpartyAccount;
  final String? fromParty;
  final String? toParty;
  final int? serviceChargeMinor;
  final String? receiptUrl;
  final String? currency;
  final List<String> errors;

  bool get isValid => direction != null && amountMinor != null;
  bool get isHighConfidence => isValid && reference != null;

  Map<String, Object?> toJson() => {
        'direction': direction,
        'keyword': keyword,
        'amountMinor': amountMinor,
        'balanceMinor': balanceMinor,
        'reference': reference,
        'counterparty': counterparty,
        'counterpartyAccount': counterpartyAccount,
        'fromParty': fromParty,
        'toParty': toParty,
        'serviceChargeMinor': serviceChargeMinor,
        'receiptUrl': receiptUrl,
        'currency': currency,
        'errors': errors,
      };
}

class ParsingEngine {
  static ParseResult parse(String body, SmsTemplate t) {
    final errors = <String>[];
    final lower = body.toLowerCase();

    String? firstKeyword(String csv) {
      for (final k in csv.split(',').map((e) => e.trim().toLowerCase())) {
        if (k.isNotEmpty && lower.contains(k)) return k;
      }
      return null;
    }

    final ck = firstKeyword(t.creditKeywords);
    final dk = firstKeyword(t.debitKeywords);
    String? direction;
    String? keyword;
    if (ck != null && dk == null) {
      direction = 'credit';
      keyword = ck;
    } else if (dk != null && ck == null) {
      direction = 'debit';
      keyword = dk;
    } else {
      errors.add(ck != null && dk != null
          ? 'Both credit and debit keywords matched'
          : 'No credit/debit keyword matched');
    }

    String? extract(String? pattern, String label) {
      if (pattern == null || pattern.trim().isEmpty) return null;
      try {
        final m = RegExp(pattern, caseSensitive: false, multiLine: true)
            .firstMatch(body);
        if (m == null) return null;
        return (m.groupCount >= 1 ? m.group(1) : m.group(0))?.trim();
      } on FormatException {
        errors.add('Invalid $label regex');
        return null;
      }
    }

    String? text(String? pattern, String label) {
      final v = extract(pattern, label);
      return (v == null || v.isEmpty) ? null : v;
    }

    int? money(String? pattern, String label) {
      final v = extract(pattern, label);
      return v == null ? null : parseMinor(v);
    }

    int? amount;
    final rawAmount = extract(t.amountRegex, 'amount');
    if (rawAmount == null) {
      errors.add('Amount not found');
    } else {
      amount = parseMinor(rawAmount);
      if (amount == null) errors.add('Amount "$rawAmount" is not a number');
    }

    var receipt = text(t.receiptRegex, 'receipt');
    receipt ??= RegExp(r'https?://\S+', caseSensitive: false)
        .firstMatch(body)
        ?.group(0)
        ?.replaceAll(RegExp(r'[.,;)\]]+$'), '');

    var currency = RegExp(r'\b(ETB|USD|EUR|GBP|Birr)\b', caseSensitive: false)
        .firstMatch(body)
        ?.group(1)
        ?.toUpperCase();
    if (currency == 'BIRR') currency = 'ETB';

    return ParseResult(
      direction: direction,
      keyword: keyword,
      amountMinor: amount,
      balanceMinor: money(t.balanceRegex, 'balance'),
      reference: text(t.referenceRegex, 'reference'),
      counterparty: text(t.counterpartyRegex, 'counterparty'),
      counterpartyAccount:
          text(t.counterpartyAccountRegex, 'counterparty account'),
      fromParty: text(t.fromRegex, 'from'),
      toParty: text(t.toRegex, 'to'),
      serviceChargeMinor: money(t.serviceChargeRegex, 'service charge'),
      receiptUrl: receipt,
      currency: currency,
      errors: errors,
    );
  }
}
