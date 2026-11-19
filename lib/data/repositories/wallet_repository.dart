import 'package:drift/drift.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/data/db/database.dart';

class WalletRepository {
  WalletRepository(this._db);

  final AppDatabase _db;

  Stream<List<Wallet>> watchAll() {
    final q = _db.select(_db.wallets)
      ..orderBy([(w) => OrderingTerm.asc(w.sortOrder), (w) => OrderingTerm.asc(w.id)]);
    return q.watch();
  }

  /// Current balance of every wallet, in that wallet's own currency.
  Stream<Map<int, int>> watchBalances() {
    return _db
        .customSelect(
          'SELECT w.id AS id, w.initial_balance '
          "+ COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount ELSE -t.amount END) "
          'FROM transactions t WHERE t.wallet_id = w.id), 0) '
          "+ COALESCE((SELECT SUM(t.to_amount) FROM transactions t WHERE t.type = 'transfer' "
          'AND t.to_wallet_id = w.id), 0) AS balance '
          'FROM wallets w',
          readsFrom: {_db.wallets, _db.transactions},
        )
        .watch()
        .map((rows) => {for (final r in rows) r.read<int>('id'): r.read<int>('balance')});
  }

  Future<int> create({
    required String name,
    required CurrencyCode currency,
    required int initialBalance,
    required String icon,
    required int color,
  }) {
    return _db.into(_db.wallets).insert(
          WalletsCompanion(
            name: Value(name),
            currency: Value(currency),
            initialBalance: Value(initialBalance),
            icon: Value(icon),
            color: Value(color),
          ),
        );
  }

  Future<void> save(Wallet wallet) => _db.update(_db.wallets).replace(wallet);

  Future<void> setArchived(int id, bool archived) {
    return (_db.update(_db.wallets)..where((w) => w.id.equals(id)))
        .write(WalletsCompanion(archived: Value(archived)));
  }

  Future<bool> isUsed(int id) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE wallet_id = ? OR to_wallet_id = ?',
      variables: [Variable.withInt(id), Variable.withInt(id)],
      readsFrom: {_db.transactions},
    ).getSingle();
    return row.read<int>('c') > 0;
  }

  /// Only call for wallets with no transactions; otherwise archive.
  Future<void> delete(int id) => (_db.delete(_db.wallets)..where((w) => w.id.equals(id))).go();
}
