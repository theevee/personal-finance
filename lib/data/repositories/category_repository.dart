import 'package:drift/drift.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<TxCategory>> watchAll() {
    final q = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)]);
    return q.watch();
  }

  Future<int> create({
    required String name,
    required CategoryType type,
    required String icon,
    required int color,
  }) async {
    final maxRow = await _db.customSelect(
      'SELECT COALESCE(MAX(sort_order), 0) AS m FROM categories',
      readsFrom: {_db.categories},
    ).getSingle();
    return _db.into(_db.categories).insert(
          CategoriesCompanion(
            name: Value(name),
            type: Value(type),
            icon: Value(icon),
            color: Value(color),
            sortOrder: Value(maxRow.read<int>('m') + 1),
          ),
        );
  }

  Future<void> save(TxCategory category) => _db.update(_db.categories).replace(category);

  Future<void> setArchived(int id, bool archived) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(archived: Value(archived)));
  }

  Future<bool> isUsed(int id) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {_db.transactions},
    ).getSingle();
    return row.read<int>('c') > 0;
  }

  /// Deletes the category and its budget allocations. Only call for unused
  /// categories; otherwise archive so history keeps its labels.
  Future<void> delete(int id) =>
      (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
}
