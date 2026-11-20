import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/utils/async.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/repositories/budget_repository.dart';
import 'package:kabob/data/repositories/category_repository.dart';
import 'package:kabob/data/repositories/transaction_repository.dart';
import 'package:kabob/data/repositories/wallet_repository.dart';
import 'package:kabob/domain/month_summary.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final walletRepositoryProvider =
    Provider<WalletRepository>((ref) => WalletRepository(ref.watch(databaseProvider)));
final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository(ref.watch(databaseProvider)));
final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => TransactionRepository(ref.watch(databaseProvider)));
final budgetRepositoryProvider =
    Provider<BudgetRepository>((ref) => BudgetRepository(ref.watch(databaseProvider)));

// ---- Wallets --------------------------------------------------------------

final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(walletRepositoryProvider).watchAll(),
);

final activeWalletsProvider = Provider<List<Wallet>>((ref) {
  final all = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
  return all.where((w) => !w.archived).toList();
});

final walletMapProvider = Provider<Map<int, Wallet>>((ref) {
  final all = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
  return {for (final w in all) w.id: w};
});

final walletBalancesProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(walletRepositoryProvider).watchBalances(),
);

// ---- Categories -----------------------------------------------------------

final categoriesProvider = StreamProvider<List<TxCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final categoryMapProvider = Provider<Map<int, TxCategory>>((ref) {
  final all = ref.watch(categoriesProvider).valueOrNull ?? const <TxCategory>[];
  return {for (final c in all) c.id: c};
});

// ---- Month selection ------------------------------------------------------

class SelectedMonthController extends Notifier<int> {
  @override
  int build() => MonthKey.now();

  void previous() => state = MonthKey.previous(state);
  void next() => state = MonthKey.next(state);
  void reset() => state = MonthKey.now();
  void set(int month) => state = month;
}

/// Month shared by Home, Budget, Records and Reports.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthController, int>(SelectedMonthController.new);

// ---- Transactions & budgets -----------------------------------------------

final monthTransactionsProvider =
    StreamProvider.autoDispose.family<List<TxRecord>, int>((ref, month) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchRange(MonthKey.start(month), MonthKey.end(month));
});

final recentTransactionsProvider = StreamProvider.autoDispose<List<TxRecord>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchRecent(5),
);

final monthBudgetTotalProvider = StreamProvider.autoDispose.family<int?, int>(
  (ref, month) => ref.watch(budgetRepositoryProvider).watchTotal(month),
);

final monthAllocationsProvider = StreamProvider.autoDispose.family<Map<int, int>, int>(
  (ref, month) => ref.watch(budgetRepositoryProvider).watchAllocations(month),
);

final monthSummaryProvider =
    Provider.autoDispose.family<AsyncValue<MonthSummary>, int>((ref, month) {
  final settings = ref.watch(settingsProvider);
  final txs = ref.watch(monthTransactionsProvider(month));
  final total = ref.watch(monthBudgetTotalProvider(month));
  final allocations = ref.watch(monthAllocationsProvider(month));
  final wallets = ref.watch(walletsProvider);
  return combineAsync([txs, total, allocations, wallets], () {
    return MonthSummary.compute(
      month: month,
      transactions: txs.requireValue,
      budget: total.requireValue,
      allocations: allocations.requireValue,
      wallets: {for (final w in wallets.requireValue) w.id: w},
      settings: settings,
    );
  });
});
