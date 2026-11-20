// Renders every main screen with realistic sample data into build/screens/<lang>/.
// Useful for checking the UI against the design without a device.
// Run: flutter test tool/screens_test.dart
// Kept in tool/ so a plain `flutter test` (test/) doesn't run it.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabob/app/app.dart';
import 'package:kabob/app/router.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = 'build/screens';

Future<void> _font(String family, List<String> paths) async {
  for (final f in [family, if (family == 'Roboto') 'FlutterTest']) {
    await _fontAs(f, paths);
  }
}

/// Text with no explicit family uses the test font, so it is loaded under both.
Future<void> _fontAs(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await l.load();
}

Future<void> _loadFonts(String lang) async {
  const s = '/System/Library/Fonts/Supplemental';
  final flutter = Platform.environment['FLUTTER_ROOT']!;
  // The test engine has no glyph fallback, and every test in this file shares
  // one font registry, so a single font that covers Khmer, Latin and the riel
  // sign is used for both languages.
  await _font('Roboto', ['$s/Khmer Sangam MN.ttf']);
  await _font('MaterialIcons', [
    '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _screen(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final rv = tester.binding.renderViews.first;
    final layer = rv.debugLayer! as OffsetLayer;
    final img = await layer.toImage(rv.paintBounds, pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Sample month that mirrors the design mockup: $500 budget, $320 spent.
Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now();
  final month = MonthKey.now();
  final cats = {for (final c in await db.select(db.categories).get()) c.nameKey: c.id};

  // Default "cash" wallet is id 1 (USD). Add the usual Cambodian accounts.
  final w = <String, int>{'cash': 1};
  await db.update(db.wallets).write(const WalletsCompanion(initialBalance: Value(12000)));
  Future<int> wallet(String name, CurrencyCode c, int bal, String icon, int color) =>
      db.into(db.wallets).insert(WalletsCompanion.insert(
            name: name,
            currency: c,
            initialBalance: Value(bal),
            icon: icon,
            color: color,
          ));
  w['aba'] = await wallet('ABA Bank', CurrencyCode.usd, 25000, 'bank', 0xFF0F4C81);
  w['acleda'] = await wallet('ACLEDA Bank', CurrencyCode.usd, 18000, 'bank', 0xFF1E3A8A);
  w['wing'] = await wallet('Wing', CurrencyCode.khr, 200000, 'mobile', 0xFF84CC16);
  w['bakong'] = await wallet('Bakong', CurrencyCode.khr, 120000, 'mobile', 0xFFDC2626);

  await db.into(db.monthlyBudgets).insert(
        MonthlyBudgetsCompanion.insert(month: Value(month), amount: 50000),
      );
  const alloc = {
    'food': 15000, 'transport': 6000, 'bills': 12000,
    'shopping': 8000, 'entertainment': 4000, 'other': 5000,
  };
  for (final e in alloc.entries) {
    await db.into(db.categoryBudgets).insert(CategoryBudgetsCompanion.insert(
          month: month, categoryId: cats[e.key]!, amount: e.value));
  }

  DateTime day(int back) {
    final d = now.subtract(Duration(days: back));
    return d.month == now.month ? d : DateTime(now.year, now.month, 1, 9);
  }

  Future<void> tx(TxType t, int amount, String cat, int back, String note,
      [String wal = 'cash']) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: t,
            amount: amount,
            walletId: w[wal]!,
            categoryId: Value(cats[cat]),
            date: day(back),
            note: Value(note),
          ));

  await tx(TxType.income, 50000, 'salary', 1, '', 'aba');
  await tx(TxType.expense, 1250, 'food', 0, 'Lunch with friends');
  await tx(TxType.expense, 350, 'transport', 1, 'Tuk-tuk');
  await tx(TxType.expense, 2500, 'shopping', 2, 'Groceries', 'aba');
  await tx(TxType.expense, 400, 'food', 3, 'Iced coffee');
  await tx(TxType.expense, 9000, 'bills', 4, 'Rent share', 'aba');
  await tx(TxType.expense, 3000, 'food', 5, 'Family dinner');
  await tx(TxType.expense, 3150, 'transport', 6, 'Fuel');
  await tx(TxType.expense, 4500, 'shopping', 7, 'Shoes', 'acleda');
  await tx(TxType.expense, 3850, 'food', 8, 'Market');
  await tx(TxType.expense, 4000, 'entertainment', 9, 'Cinema');
}

void main() {
  for (final lang in const ['en', 'km']) {
    testWidgets('screens $lang', (tester) async {
      await tester.runAsync(() => _loadFonts(lang));
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;

      late AppDatabase db;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        SharedPreferences.setMockInitialValues({'settings.locale': lang});
        prefs = await SharedPreferences.getInstance();
        db = AppDatabase(NativeDatabase.memory());
        await _seed(db);
      });

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KabobApp()),
      );
      await _settle(tester);
      final router = container.read(routerProvider);

      var n = 1;
      for (final (path, name) in const [
        ('/home', 'home'),
        ('/budget', 'budget'),
        ('/add', 'add_expense_keypad'),
        ('/add#filled', 'add_expense'),
        ('/add?type=income', 'add_income'),
        ('/category/1', 'category_detail'),
        ('/records', 'records'),
        ('/reports', 'reports'),
        ('/wallets', 'wallets'),
      ]) {
        if (path == '/add#filled') {
          // Type $12.50, then pick the first category: the keypad tucks away.
          for (final k in ['1', '2', '.', '5', '0']) {
            await tester.tap(find.text(k).last);
            await tester.pump();
          }
          await tester.tap(find.byType(CategoryAvatar).first);
          await _settle(tester);
          await tester.scrollUntilVisible(find.byType(TextField), 200,
              scrollable: find.byType(Scrollable).first);
          await tester.enterText(find.byType(TextField), 'Lunch with friends');
          FocusManager.instance.primaryFocus?.unfocus();
          await _settle(tester);
        } else {
          // Leave the current route first so screens never reuse old state.
          router.go('/home');
          await _settle(tester, 3);
          router.go(path);
          await _settle(tester);
        }
        await _screen(tester, '$_out/$lang/${n++}_$name.png');
      }

      await tester.pumpWidget(const SizedBox());
      await _settle(tester, 4);
      container.dispose();
      await tester.runAsync(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));
      await _settle(tester, 4);
    });
  }
}
