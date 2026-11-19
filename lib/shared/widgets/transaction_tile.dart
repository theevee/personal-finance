import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.tx, this.showDate = true});

  final TxRecord tx;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final categories = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final wallet = wallets[tx.walletId];
    final currency = wallet?.currency ?? CurrencyCode.usd;

    late final Widget avatar;
    late final String label;
    late final Color amountColor;
    late final String amountText;
    switch (tx.type) {
      case TxType.transfer:
        avatar = const CategoryAvatar(iconKey: 'bank', color: AppColors.transfer);
        label = '${walletName(l, wallet)} → ${walletName(l, wallets[tx.toWalletId])}';
        amountColor = AppColors.transfer;
        amountText = Money.format(tx.amount, currency);
      case TxType.expense:
      case TxType.income:
        final category = tx.categoryId == null ? null : categories[tx.categoryId];
        avatar = CategoryAvatar(
          iconKey: category?.icon ?? 'other',
          color: category == null ? AppColors.neutral : Color(category.color),
        );
        label = categoryName(l, category);
        final isExpense = tx.type == TxType.expense;
        amountColor = isExpense ? AppColors.expense : AppColors.income;
        amountText = Money.format(isExpense ? -tx.amount : tx.amount, currency, signed: true);
    }

    final title = tx.note.isNotEmpty ? tx.note : label;
    final parts = <String>[
      if (tx.note.isNotEmpty) label,
      if (showDate) DateFormat.MMMd(context.localeTag).format(tx.date),
      if (tx.type != TxType.transfer) walletName(l, wallet),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: avatar,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        amountText,
        style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 15),
      ),
      onTap: () => context.push('/add?id=${tx.id}'),
    );
  }
}
