import 'package:flutter/material.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/amount_input.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/numeric_keypad.dart';

class AmountSheetResult {
  const AmountSheetResult.value(this.amount) : removed = false;
  const AmountSheetResult.removed()
      : amount = 0,
        removed = true;

  final int amount;
  final bool removed;
}

/// Bottom sheet with an amount display and keypad. Returns null on dismiss.
Future<AmountSheetResult?> showAmountSheet(
  BuildContext context, {
  required String title,
  required CurrencyCode currency,
  int? initial,
  String? subtitle,
  bool allowRemove = false,
}) {
  return showModalBottomSheet<AmountSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AmountSheet(
      title: title,
      subtitle: subtitle,
      currency: currency,
      initial: initial,
      allowRemove: allowRemove,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.currency,
    required this.allowRemove,
    this.subtitle,
    this.initial,
  });

  final String title;
  final String? subtitle;
  final CurrencyCode currency;
  final int? initial;
  final bool allowRemove;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late String _buffer = AmountInput.fromMinor(widget.initial, widget.currency);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final value = Money.parse(_buffer, widget.currency) ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AmountInput.display(_buffer, widget.currency),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              allowDecimal: widget.currency.decimals > 0,
              onKey: (k) => setState(() => _buffer = AmountInput.apply(_buffer, k, widget.currency)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.allowRemove) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        minimumSize: const Size(64, 52),
                      ),
                      onPressed: () => Navigator.pop(context, const AmountSheetResult.removed()),
                      child: Text(l.remove),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: value > 0 ? () => Navigator.pop(context, AmountSheetResult.value(value)) : null,
                    child: Text(l.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showWalletPicker(
  BuildContext context, {
  required List<Wallet> wallets,
  int? selectedId,
  int? excludeId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final l = ctx.l10n;
      final options = wallets.where((w) => w.id != excludeId).toList();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l.selectWallet,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final w in options)
              ListTile(
                leading: CategoryAvatar(iconKey: w.icon, color: Color(w.color)),
                title: Text(walletName(l, w)),
                subtitle: Text(w.currency.code),
                trailing: w.id == selectedId
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, w.id),
              ),
          ],
        ),
      );
    },
  );
}

/// Sentinel returned by [showCategoryPicker] when "New category" is chosen.
const int kNewCategory = -100;

Future<int?> showCategoryPicker(BuildContext context, {required List<TxCategory> categories}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final l = ctx.l10n;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l.selectCategory,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final c in categories)
              ListTile(
                leading: CategoryAvatar(iconKey: c.icon, color: Color(c.color)),
                title: Text(categoryName(l, c)),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.add_rounded, color: AppColors.primary),
              ),
              title: Text(l.newCategory),
              onTap: () => Navigator.pop(ctx, kNewCategory),
            ),
          ],
        ),
      );
    },
  );
}
