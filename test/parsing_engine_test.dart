import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/core/money.dart';
import 'package:finance_tracker/features/parsing/parsing_engine.dart';

const _t = SmsTemplate(
  name: 'sample',
  creditKeywords: 'credited,received,deposited',
  debitKeywords: 'debited,withdrawn,paid',
  amountRegex: r'(?:ETB|Birr)\s*([\d,]+(?:\.\d+)?)',
  balanceRegex: r'balance[^\d]{0,25}([\d,]+(?:\.\d+)?)',
  referenceRegex: r'\b(?:ref|txn)\b[^A-Za-z0-9]{0,5}([A-Za-z0-9]{6,})',
);

void main() {
  test('money parsing and formatting', () {
    expect(parseMinor('1,234.5'), 123450);
    expect(parseMinor('10'), 1000);
    expect(parseMinor('abc'), isNull);
    expect(formatMinor(123456), '1,234.56');
    expect(formatMinor(-5, 'ETB'), '-ETB 0.05');
  });

  test('credit message', () {
    final r = ParsingEngine.parse(
        'Your account has been credited with ETB 1,250.50. Ref: ABC123456. Balance ETB 5,000.00',
        _t);
    expect(r.direction, 'credit');
    expect(r.amountMinor, 125050);
    expect(r.balanceMinor, 500000);
    expect(r.reference, 'ABC123456');
    expect(r.currency, 'ETB');
    expect(r.isHighConfidence, isTrue);
  });

  test('debit message', () {
    final r = ParsingEngine.parse(
        'ETB 300.00 was debited from your account. Txn 99887766. Balance ETB 4,700.00',
        _t);
    expect(r.direction, 'debit');
    expect(r.amountMinor, 30000);
    expect(r.reference, '99887766');
  });

  test('unrecognised message is invalid', () {
    final r = ParsingEngine.parse('Hello, enjoy our new promotion!', _t);
    expect(r.isValid, isFalse);
    expect(r.errors, isNotEmpty);
  });

  test('bad regex is reported, not thrown', () {
    const bad = SmsTemplate(
        name: 'bad',
        creditKeywords: 'credited',
        debitKeywords: 'debited',
        amountRegex: r'([');
    final r = ParsingEngine.parse('credited ETB 5', bad);
    expect(r.isValid, isFalse);
    expect(r.errors.any((e) => e.contains('Invalid')), isTrue);
  });

  test('extracts keyword, from, to, service charge and receipt link', () {
    const t = SmsTemplate(
      name: 'details',
      creditKeywords: 'credited',
      debitKeywords: 'transferred,debited',
      amountRegex: r'(?:ETB|Birr)\s*([\d,]+(?:\.\d+)?)',
      referenceRegex: r'\bref\b[^A-Za-z0-9]{0,5}([A-Za-z0-9]{6,})',
      fromRegex: r'\bfrom\s+([A-Za-z ]+?)\s+to\b',
      toRegex: r'\bto\s+([A-Za-z ]+?)(?:\s+on|\.)',
      serviceChargeRegex: r'service\s*charge[^\d]{0,15}([\d,]+(?:\.\d+)?)',
    );
    final r = ParsingEngine.parse(
        'ETB 500.00 transferred from Abebe Kebede to Sara Tadesse on 12/11/2026. '
        'Service charge ETB 5.00. Ref: TXN778899. Receipt: https://example.com/r/TXN778899.',
        t);
    expect(r.direction, 'debit');
    expect(r.keyword, 'transferred');
    expect(r.amountMinor, 50000);
    expect(r.fromParty, 'Abebe Kebede');
    expect(r.toParty, 'Sara Tadesse');
    expect(r.serviceChargeMinor, 500);
    expect(r.reference, 'TXN778899');
    expect(r.receiptUrl, 'https://example.com/r/TXN778899');
  });
}
