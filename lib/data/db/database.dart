import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/db/seed.dart';

part 'database.g.dart';

/// Cash, bank or e-wallet balances the user tracks manually.
@DataClassName('Wallet')
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Set for built-in wallets so the name follows the app language.
  TextColumn get nameKey => text().nullable()();
  TextColumn get currency => textEnum<CurrencyCode>()();

  /// Opening balance in minor units of [currency].
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('TxCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameKey => text().nullable()();
  TextColumn get type => textEnum<CategoryType>()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Expenses, income and bookkeeping transfers. [amount] is always positive
/// and in the source wallet's currency.
@DataClassName('TxRecord')
@TableIndex(name: 'transactions_date_idx', columns: {#date})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get amount => integer()();
  @ReferenceName('outgoingTransactions')
  IntColumn get walletId => integer().references(Wallets, #id)();

  /// Destination wallet for transfers.
  @ReferenceName('incomingTransfers')
  IntColumn get toWalletId => integer().nullable().references(Wallets, #id)();

  /// Amount received by [toWalletId] in its own currency (transfers only).
  IntColumn get toAmount => integer().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Total budget for a month, in the user's base currency.
@DataClassName('MonthlyBudgetRow')
class MonthlyBudgets extends Table {
  IntColumn get month => integer()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {month};
}

/// Per-category allocation for a month, in the user's base currency.
@DataClassName('CategoryBudgetRow')
class CategoryBudgets extends Table {
  IntColumn get month => integer()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {month, categoryId};
}

@DriftDatabase(tables: [Wallets, Categories, Transactions, MonthlyBudgets, CategoryBudgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'kabob'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> seedDefaults() async {
    await batch((b) {
      b.insertAll(categories, [
        for (var i = 0; i < seedCategories.length; i++)
          CategoriesCompanion(
            name: const Value(''),
            nameKey: Value(seedCategories[i].key),
            type: Value(seedCategories[i].type),
            icon: Value(seedCategories[i].icon),
            color: Value(seedCategories[i].color),
            sortOrder: Value(i),
          ),
      ]);
      b.insert(
        wallets,
        const WalletsCompanion(
          name: Value(''),
          nameKey: Value('cash'),
          currency: Value(CurrencyCode.usd),
          icon: Value('cash'),
          color: Value(0xFF16A34A),
        ),
      );
    });
  }

  /// Deletes every record and restores the default categories and wallet.
  Future<void> eraseAll() {
    return transaction(() async {
      await delete(transactions).go();
      await delete(categoryBudgets).go();
      await delete(monthlyBudgets).go();
      await delete(categories).go();
      await delete(wallets).go();
      await seedDefaults();
    });
  }
}
