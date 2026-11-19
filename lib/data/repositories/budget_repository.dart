import 'package:drift/drift.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/data/db/database.dart';

class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<int?> watchTotal(int month) {
    return (_db.select(_db.monthlyBudgets)..where((b) => b.month.equals(month)))
        .watchSingleOrNull()
        .map((row) => row?.amount);
  }

  Stream<Map<int, int>> watchAllocations(int month) {
    return (_db.select(_db.categoryBudgets)..where((b) => b.month.equals(month)))
        .watch()
        .map((rows) => {for (final r in rows) r.categoryId: r.amount});
  }

  Future<void> setTotal(int month, int amount) {
    return _db.into(_db.monthlyBudgets).insertOnConflictUpdate(
          MonthlyBudgetsCompanion(month: Value(month), amount: Value(amount)),
        );
  }

  Future<void> clearTotal(int month) =>
      (_db.delete(_db.monthlyBudgets)..where((b) => b.month.equals(month))).go();

  Future<void> setAllocation(int month, int categoryId, int amount) {
    return _db.into(_db.categoryBudgets).insertOnConflictUpdate(
          CategoryBudgetsCompanion(
            month: Value(month),
            categoryId: Value(categoryId),
            amount: Value(amount),
          ),
        );
  }

  Future<void> removeAllocation(int month, int categoryId) {
    return (_db.delete(_db.categoryBudgets)
          ..where((b) => b.month.equals(month) & b.categoryId.equals(categoryId)))
        .go();
  }

  Future<bool> hasBudget(int month) async {
    final total = await (_db.select(_db.monthlyBudgets)..where((b) => b.month.equals(month)))
        .getSingleOrNull();
    if (total != null) return true;
    final alloc = await (_db.select(_db.categoryBudgets)
          ..where((b) => b.month.equals(month))
          ..limit(1))
        .get();
    return alloc.isNotEmpty;
  }

  /// Replaces [toMonth]'s budget with a copy of [fromMonth]'s.
  /// Returns false when [fromMonth] has nothing to copy.
  Future<bool> copy({required int fromMonth, required int toMonth}) async {
    final total = await (_db.select(_db.monthlyBudgets)..where((b) => b.month.equals(fromMonth)))
        .getSingleOrNull();
    final allocations =
        await (_db.select(_db.categoryBudgets)..where((b) => b.month.equals(fromMonth))).get();
    if (total == null && allocations.isEmpty) return false;

    await _db.transaction(() async {
      await clearTotal(toMonth);
      await (_db.delete(_db.categoryBudgets)..where((b) => b.month.equals(toMonth))).go();
      if (total != null) await setTotal(toMonth, total.amount);
      for (final a in allocations) {
        await setAllocation(toMonth, a.categoryId, a.amount);
      }
    });
    return true;
  }

  /// Re-expresses every stored budget in a new base currency.
  Future<void> convertAll(CurrencyCode from, CurrencyCode to, int khrPerUsd) async {
    if (from == to) return;
    await _db.transaction(() async {
      final totals = await _db.select(_db.monthlyBudgets).get();
      for (final t in totals) {
        await setTotal(t.month, Money.convert(t.amount, from, to, khrPerUsd));
      }
      final allocations = await _db.select(_db.categoryBudgets).get();
      for (final a in allocations) {
        await setAllocation(a.month, a.categoryId, Money.convert(a.amount, from, to, khrPerUsd));
      }
    });
  }
}
