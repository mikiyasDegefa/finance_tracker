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
  });
  final int? id;
  final String name;
  final String creditKeywords; // comma separated
  final String debitKeywords; // comma separated
  final String amountRegex;
  final String? balanceRegex;
  final String? referenceRegex;
  final String? counterpartyRegex;
}

class ParseResult {
  const ParseResult({
    this.direction,
    this.amountMinor,
    this.balanceMinor,
    this.reference,
    this.counterparty,
    this.currency,
    this.errors = const [],
  });
  final String? direction; // credit | debit
  final int? amountMinor;
  final int? balanceMinor;
  final String? reference;
  final String? counterparty;
  final String? currency;
  final List<String> errors;

  bool get isValid => direction != null && amountMinor != null;
  bool get isHighConfidence => isValid && reference != null;

  Map<String, Object?> toJson() => {
        'direction': direction,
        'amountMinor': amountMinor,
        'balanceMinor': balanceMinor,
        'reference': reference,
        'counterparty': counterparty,
        'currency': currency,
        'errors': errors,
      };
}

class ParsingEngine {
  static ParseResult parse(String body, SmsTemplate t) {
    final errors = <String>[];
    final lower = body.toLowerCase();

    bool hasAny(String csv) => csv
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .any((k) => lower.contains(k));

    final credit = hasAny(t.creditKeywords);
    final debit = hasAny(t.debitKeywords);
    String? direction;
    if (credit && !debit) {
      direction = 'credit';
    } else if (debit && !credit) {
      direction = 'debit';
    } else {
      errors.add(credit && debit
          ? 'Both credit and debit keywords matched'
          : 'No credit/debit keyword matched');
    }

    String? extract(String? pattern, String label) {
      if (pattern == null || pattern.trim().isEmpty) return null;
      try {
        final m = RegExp(pattern, caseSensitive: false, multiLine: true)
            .firstMatch(body);
        if (m == null) return null;
        return m.groupCount >= 1 ? m.group(1) : m.group(0);
      } on FormatException {
        errors.add('Invalid $label regex');
        return null;
      }
    }

    int? amount;
    final rawAmount = extract(t.amountRegex, 'amount');
    if (rawAmount == null) {
      errors.add('Amount not found');
    } else {
      amount = parseMinor(rawAmount);
      if (amount == null) errors.add('Amount "$rawAmount" is not a number');
    }

    final rawBalance = extract(t.balanceRegex, 'balance');
    final balance = rawBalance == null ? null : parseMinor(rawBalance);
    final reference = extract(t.referenceRegex, 'reference')?.trim();
    final counterparty = extract(t.counterpartyRegex, 'counterparty')?.trim();

    var currency = RegExp(r'\b(ETB|USD|EUR|GBP|Birr)\b', caseSensitive: false)
        .firstMatch(body)
        ?.group(1)
        ?.toUpperCase();
    if (currency == 'BIRR') currency = 'ETB';

    return ParseResult(
      direction: direction,
      amountMinor: amount,
      balanceMinor: balance,
      reference: (reference == null || reference.isEmpty) ? null : reference,
      counterparty:
          (counterparty == null || counterparty.isEmpty) ? null : counterparty,
      currency: currency,
      errors: errors,
    );
  }
}
