import 'package:drift/drift.dart';
import 'package:kabob/data/db/database.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// Transactions with `start <= date < end`, newest first.
  Stream<List<TxRecord>> watchRange(DateTime start, DateTime end, {int? categoryId}) {
    final q = _db.select(_db.transactions)
      ..where((t) {
        var e = t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end);
        if (categoryId != null) e = e & t.categoryId.equals(categoryId);
        return e;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)]);
    return q.watch();
  }

  Stream<List<TxRecord>> watchRecent(int limit) {
    final q = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
    return q.watch();
  }

  Future<TxRecord?> getById(int id) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insert(TransactionsCompanion entry) => _db.into(_db.transactions).insert(entry);

  Future<void> updateFields(int id, TransactionsCompanion entry) =>
      (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(entry);

  Future<void> delete(int id) =>
      (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
}
