import 'package:flutter_test/flutter_test.dart';
import 'package:kabob/core/money/amount_input.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/domain/month_summary.dart';

void main() {
  group('Money.format', () {
    test('USD uses cents and grouping', () {
      expect(Money.format(123450, CurrencyCode.usd), r'$1,234.50');
      expect(Money.format(5, CurrencyCode.usd), r'$0.05');
      expect(Money.format(-1250, CurrencyCode.usd), r'-$12.50');
      expect(Money.format(50000, CurrencyCode.usd, signed: true), r'+$500.00');
    });

    test('KHR has no decimals', () {
      expect(Money.format(490000, CurrencyCode.khr), '៛490,000');
    });
  });

  group('Money.parse', () {
    test('parses USD to cents without float error', () {
      expect(Money.parse('12.5', CurrencyCode.usd), 1250);
      expect(Money.parse('0.29', CurrencyCode.usd), 29);
      expect(Money.parse('1,000', CurrencyCode.usd), 100000);
      expect(Money.parse('-3', CurrencyCode.usd), -300);
      expect(Money.parse('.5', CurrencyCode.usd), 50);
      expect(Money.parse('1.999', CurrencyCode.usd), 199);
    });

    test('parses KHR as whole riel', () {
      expect(Money.parse('4,000', CurrencyCode.khr), 4000);
    });

    test('rejects junk', () {
      expect(Money.parse('', CurrencyCode.usd), isNull);
      expect(Money.parse('abc', CurrencyCode.usd), isNull);
      expect(Money.parse('1.2.3', CurrencyCode.usd), isNull);
    });

    test('round-trips through toEditable', () {
      for (final v in [0, 1, 99, 100, 1250, 123456]) {
        expect(Money.parse(Money.toEditable(v, CurrencyCode.usd), CurrencyCode.usd), v);
      }
    });
  });

  group('Money.convert', () {
    test('USD <-> KHR', () {
      expect(Money.convert(100, CurrencyCode.usd, CurrencyCode.khr, 4000), 4000);
      expect(Money.convert(10000, CurrencyCode.khr, CurrencyCode.usd, 4000), 250);
      expect(Money.convert(777, CurrencyCode.usd, CurrencyCode.usd, 4000), 777);
    });
  });

  group('AmountInput', () {
    String type(String keys, CurrencyCode c) {
      var b = '';
      for (final k in keys.split(' ')) {
        b = AmountInput.apply(b, k, c);
      }
      return b;
    }

    test('limits decimals to the currency', () {
      expect(type('1 2 . 5 0 9', CurrencyCode.usd), '12.50');
      expect(type('1 . 5', CurrencyCode.khr), '15');
    });

    test('replaces a leading zero and supports backspace', () {
      expect(type('0 0 7', CurrencyCode.usd), '7');
      expect(type('1 2 back', CurrencyCode.usd), '1');
      expect(type('. 5', CurrencyCode.usd), '0.5');
    });

    test('000 key for riel', () {
      expect(type('5 000', CurrencyCode.khr), '5000');
      expect(type('000', CurrencyCode.khr), '');
    });

    test('display groups thousands', () {
      expect(AmountInput.display('1250.5', CurrencyCode.usd), r'$1,250.5');
      expect(AmountInput.display('', CurrencyCode.khr), '៛0');
    });
  });

  group('MonthKey', () {
    test('wraps across years', () {
      expect(MonthKey.previous(202501), 202412);
      expect(MonthKey.next(202512), 202601);
      expect(MonthKey.daysIn(202402), 29);
      expect(MonthKey.end(202512), DateTime(2026, 1));
    });
  });

  group('budgetStatus', () {
    test('thresholds', () {
      expect(budgetStatus(spent: 10, limit: null, threshold: 80), BudgetStatus.none);
      expect(budgetStatus(spent: 50, limit: 100, threshold: 80), BudgetStatus.onTrack);
      expect(budgetStatus(spent: 80, limit: 100, threshold: 80), BudgetStatus.nearLimit);
      expect(budgetStatus(spent: 100, limit: 100, threshold: 80), BudgetStatus.nearLimit);
      expect(budgetStatus(spent: 101, limit: 100, threshold: 80), BudgetStatus.over);
    });
  });
}
