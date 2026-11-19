import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}

String? builtInLabel(AppLocalizations l, String key) {
  return switch (key) {
    'food' => l.catFood,
    'transport' => l.catTransport,
    'shopping' => l.catShopping,
    'bills' => l.catBills,
    'entertainment' => l.catEntertainment,
    'health' => l.catHealth,
    'education' => l.catEducation,
    'family' => l.catFamily,
    'other' => l.catOther,
    'salary' => l.catSalary,
    'freelance' => l.catFreelance,
    'business' => l.catBusiness,
    'gift' => l.catGift,
    'bonus' => l.catBonus,
    'other_income' => l.catOther,
    'cash' => l.walletCash,
    _ => null,
  };
}

String categoryName(AppLocalizations l, TxCategory? c) {
  if (c == null) return l.uncategorized;
  final key = c.nameKey;
  if (key != null) return builtInLabel(l, key) ?? c.name;
  return c.name;
}

String walletName(AppLocalizations l, Wallet? w) {
  if (w == null) return '—';
  final key = w.nameKey;
  if (key != null) return builtInLabel(l, key) ?? w.name;
  return w.name;
}

String txTypeLabel(AppLocalizations l, TxType type) => switch (type) {
      TxType.expense => l.expense,
      TxType.income => l.income,
      TxType.transfer => l.transfer,
    };

String monthLabel(BuildContext context, int month) =>
    DateFormat.yMMMM(context.localeTag).format(MonthKey.start(month));

String dayLabel(BuildContext context, DateTime date) {
  final l = context.l10n;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.today;
  if (diff == 1) return l.yesterday;
  return DateFormat.yMMMd(context.localeTag).format(date);
}
