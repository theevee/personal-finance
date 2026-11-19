import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';

/// Converts a transaction's amount into the user's base currency.
int amountInBase(TxRecord tx, Map<int, Wallet> wallets, AppSettings settings) {
  final currency = wallets[tx.walletId]?.currency ?? settings.baseCurrency;
  return Money.convert(tx.amount, currency, settings.baseCurrency, settings.khrPerUsd);
}

enum BudgetStatus { none, onTrack, nearLimit, over }

BudgetStatus budgetStatus({required int spent, required int? limit, required int threshold}) {
  if (limit == null || limit <= 0) return BudgetStatus.none;
  if (spent > limit) return BudgetStatus.over;
  if (spent * 100 >= limit * threshold) return BudgetStatus.nearLimit;
  return BudgetStatus.onTrack;
}

/// Everything the Home, Budget and Reports screens need for one month.
/// All amounts are in the base currency's minor unit.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.budget,
    required this.spent,
    required this.income,
    required this.allocations,
    required this.spentByCategory,
    required this.incomeByCategory,
    required this.spentByDay,
    required this.transactionCount,
  });

  /// Key used for expenses whose category was deleted.
  static const int uncategorized = -1;

  final int month;
  final int? budget;
  final int spent;
  final int income;
  final Map<int, int> allocations;
  final Map<int, int> spentByCategory;
  final Map<int, int> incomeByCategory;
  final Map<int, int> spentByDay;
  final int transactionCount;

  int get remaining => (budget ?? 0) - spent;

  double get usage {
    final b = budget ?? 0;
    return b > 0 ? spent / b : 0;
  }

  int get usagePercent => (usage * 100).round();

  int get allocated => allocations.values.fold(0, (a, b) => a + b);

  int get unallocated => (budget ?? 0) - allocated;

  int spentFor(int categoryId) => spentByCategory[categoryId] ?? 0;

  factory MonthSummary.compute({
    required int month,
    required List<TxRecord> transactions,
    required int? budget,
    required Map<int, int> allocations,
    required Map<int, Wallet> wallets,
    required AppSettings settings,
  }) {
    var spent = 0;
    var income = 0;
    final byCategory = <int, int>{};
    final incomeByCategory = <int, int>{};
    final byDay = <int, int>{};
    for (final tx in transactions) {
      if (tx.type == TxType.transfer) continue;
      final amount = amountInBase(tx, wallets, settings);
      final category = tx.categoryId ?? uncategorized;
      if (tx.type == TxType.expense) {
        spent += amount;
        byCategory[category] = (byCategory[category] ?? 0) + amount;
        byDay[tx.date.day] = (byDay[tx.date.day] ?? 0) + amount;
      } else {
        income += amount;
        incomeByCategory[category] = (incomeByCategory[category] ?? 0) + amount;
      }
    }
    return MonthSummary(
      month: month,
      budget: budget,
      spent: spent,
      income: income,
      allocations: allocations,
      spentByCategory: byCategory,
      incomeByCategory: incomeByCategory,
      spentByDay: byDay,
      transactionCount: transactions.length,
    );
  }
}
