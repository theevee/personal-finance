/// Months are identified by an integer `yyyymm` key, e.g. 202511.
abstract final class MonthKey {
  static int of(DateTime d) => d.year * 100 + d.month;

  static int now() => of(DateTime.now());

  static DateTime start(int key) => DateTime(key ~/ 100, key % 100);

  /// Exclusive end: first instant of the following month.
  static DateTime end(int key) => DateTime(key ~/ 100, key % 100 + 1);

  static int add(int key, int months) => of(DateTime(key ~/ 100, key % 100 + months));

  static int previous(int key) => add(key, -1);

  static int next(int key) => add(key, 1);

  static int daysIn(int key) => DateTime(key ~/ 100, key % 100 + 1, 0).day;
}
