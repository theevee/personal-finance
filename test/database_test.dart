import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/repositories/budget_repository.dart';
import 'package:kabob/data/repositories/transaction_repository.dart';
import 'package:kabob/data/repositories/wallet_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds default categories and a cash wallet', () async {
    final categories = await db.select(db.categories).get();
    final wallets = await db.select(db.wallets).get();
    expect(categories.where((c) => c.type == CategoryType.expense), isNotEmpty);
    expect(categories.where((c) => c.type == CategoryType.income), isNotEmpty);
    expect(wallets.single.nameKey, 'cash');
  });

  test('wallet balances include income, expenses and transfers', () async {
    final wallets = WalletRepository(db);
    final txs = TransactionRepository(db);
    final cash = (await db.select(db.wallets).get()).single.id;
    final bank = await wallets.create(
      name: 'ABA',
      currency: CurrencyCode.khr,
      initialBalance: 100000,
      icon: 'bank',
      color: 0xFF3B82F6,
    );
    final now = DateTime.now();
    await txs.insert(TransactionsCompanion(
      type: const Value(TxType.income), amount: const Value(50000), walletId: Value(cash), date: Value(now)));
    await txs.insert(TransactionsCompanion(
      type: const Value(TxType.expense), amount: const Value(1250), walletId: Value(cash), date: Value(now)));
    await txs.insert(TransactionsCompanion(
      type: const Value(TxType.transfer),
      amount: const Value(1000),
      walletId: Value(cash),
      toWalletId: Value(bank),
      toAmount: const Value(40000),
      date: Value(now),
    ));

    final balances = await wallets.watchBalances().first;
    expect(balances[cash], 50000 - 1250 - 1000);
    expect(balances[bank], 140000);
    expect(await wallets.isUsed(bank), isTrue);
  });

  test('copies previous month budget', () async {
    final budgets = BudgetRepository(db);
    final food = (await db.select(db.categories).get()).first.id;
    await budgets.setTotal(202510, 50000);
    await budgets.setAllocation(202510, food, 15000);

    expect(await budgets.copy(fromMonth: 202510, toMonth: 202511), isTrue);
    expect(await budgets.watchTotal(202511).first, 50000);
    expect(await budgets.watchAllocations(202511).first, {food: 15000});
    expect(await budgets.copy(fromMonth: 202501, toMonth: 202502), isFalse);
  });

  test('converts budgets when the base currency changes', () async {
    final budgets = BudgetRepository(db);
    await budgets.setTotal(202511, 50000); // $500.00
    await budgets.convertAll(CurrencyCode.usd, CurrencyCode.khr, 4000);
    expect(await budgets.watchTotal(202511).first, 2000000); // ៛2,000,000
  });

  test('eraseAll restores defaults', () async {
    await BudgetRepository(db).setTotal(202511, 100);
    await db.eraseAll();
    expect(await db.select(db.monthlyBudgets).get(), isEmpty);
    expect(await db.select(db.wallets).get(), hasLength(1));
  });
}
