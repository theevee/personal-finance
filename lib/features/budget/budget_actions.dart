import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/sheets.dart';

Future<void> editTotalBudget(BuildContext context, WidgetRef ref, int month, int? current) async {
  final l = context.l10n;
  final currency = ref.read(settingsProvider).baseCurrency;
  final result = await showAmountSheet(
    context,
    title: l.monthlyBudget,
    subtitle: monthLabel(context, month),
    currency: currency,
    initial: current,
    allowRemove: current != null,
  );
  if (result == null) return;
  final repo = ref.read(budgetRepositoryProvider);
  if (result.removed) {
    await repo.clearTotal(month);
  } else {
    await repo.setTotal(month, result.amount);
  }
}

Future<void> editAllocation(
  BuildContext context,
  WidgetRef ref, {
  required int month,
  required int categoryId,
  required String categoryLabel,
  int? current,
}) async {
  final currency = ref.read(settingsProvider).baseCurrency;
  final result = await showAmountSheet(
    context,
    title: categoryLabel,
    subtitle: context.l10n.categoryBudget,
    currency: currency,
    initial: current,
    allowRemove: current != null,
  );
  if (result == null) return;
  final repo = ref.read(budgetRepositoryProvider);
  if (result.removed) {
    await repo.removeAllocation(month, categoryId);
  } else {
    await repo.setAllocation(month, categoryId, result.amount);
  }
}

Future<void> copyPreviousBudget(BuildContext context, WidgetRef ref, int month) async {
  final l = context.l10n;
  final repo = ref.read(budgetRepositoryProvider);
  if (await repo.hasBudget(month)) {
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.copyLastMonth,
      message: l.copyOverwriteMessage,
      confirmLabel: l.replace,
    );
    if (!ok) return;
  }
  final copied = await repo.copy(fromMonth: MonthKey.previous(month), toMonth: month);
  if (!context.mounted) return;
  showMessage(context, copied ? l.budgetCopied : l.nothingToCopy);
}
