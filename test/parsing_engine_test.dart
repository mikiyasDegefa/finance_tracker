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
}
