import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/features/budget/budget_actions.dart';
import 'package:kabob/l10n/app_localizations.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/progress.dart';

String statusLabel(AppLocalizations l, BudgetStatus status) => switch (status) {
      BudgetStatus.over => l.statusOver,
      BudgetStatus.nearLimit => l.statusNearLimit,
      BudgetStatus.onTrack => l.statusOnTrack,
      BudgetStatus.none => l.statusNoBudget,
    };

/// One category's spending against its allocation.
class CategoryBudgetRow extends ConsumerWidget {
  const CategoryBudgetRow({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    this.onTap,
  });

  final TxCategory? category;
  final int spent;
  final int limit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final currency = settings.baseCurrency;
    final status = budgetStatus(spent: spent, limit: limit, threshold: settings.alertThreshold);
    final color = statusColor(status);
    final pct = limit > 0 ? (spent * 100 / limit).round() : 0;
    final c = category;
    return InkWell(
      onTap: onTap ?? (c == null ? null : () => context.push('/category/${c.id}')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CategoryAvatar(
              iconKey: c?.icon ?? 'other',
              color: c == null ? AppColors.neutral : Color(c.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryName(l, c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${Money.format(spent, currency)} / ${Money.format(limit, currency)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BudgetProgressBar(value: limit > 0 ? spent / limit : 0, color: color),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$pct%',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of all allocated categories for a month, most-used first.
class CategoryBudgetList extends ConsumerWidget {
  const CategoryBudgetList({super.key, required this.summary, this.limit});

  final MonthSummary summary;
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryMapProvider);
    final entries = summary.allocations.entries.toList()
      ..sort((a, b) {
        final ua = a.value > 0 ? summary.spentFor(a.key) / a.value : 0.0;
        final ub = b.value > 0 ? summary.spentFor(b.key) / b.value : 0.0;
        return ub.compareTo(ua);
      });
    final shown = limit == null ? entries : entries.take(limit!).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(indent: 68),
            CategoryBudgetRow(
              category: categories[shown[i].key],
              spent: summary.spentFor(shown[i].key),
              limit: shown[i].value,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ring + totals card shown on Home.
class BudgetOverviewCard extends ConsumerWidget {
  const BudgetOverviewCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final currency = settings.baseCurrency;
    final budget = summary.budget;

    if (budget == null) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.savings_outlined, size: 40, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(l.noBudgetTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l.noBudgetMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (summary.spent > 0) ...[
              const SizedBox(height: 8),
              Text(
                l.spentSoFar(Money.format(summary.spent, currency)),
                style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => copyPreviousBudget(context, ref, summary.month),
                    child: Text(l.copyLastMonth, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => editTotalBudget(context, ref, summary.month, null),
                    child: Text(l.setBudget),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final status = budgetStatus(spent: summary.spent, limit: budget, threshold: settings.alertThreshold);
    final color = statusColor(status);
    return AppCard(
      onTap: () => editTotalBudget(context, ref, summary.month, budget),
      child: Column(
        children: [
          Row(
            children: [
              RingProgress(
                value: summary.usage,
                color: color,
                child: Text(
                  '${summary.usagePercent}%',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.monthlyBudget, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        Money.format(budget, currency),
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.budgetSetForMonth,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l.spent,
                  amount: summary.spent,
                  currency: currency,
                  color: AppColors.expense,
                  background: AppColors.expenseLight,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: l.remaining,
                  amount: summary.remaining,
                  currency: currency,
                  color: summary.remaining < 0 ? AppColors.danger : AppColors.primaryDark,
                  background: summary.remaining < 0 ? AppColors.dangerLight : AppColors.primaryLight,
                  icon: Icons.savings_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(l.budgetUsed, style: const TextStyle(color: AppColors.textSecondary))),
              Text('${summary.usagePercent}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          BudgetProgressBar(value: summary.usage, color: color, height: 10),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final int amount;
  final CurrencyCode currency;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              Money.format(amount, currency),
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured banner telling the user how the month is going.
class BudgetAlertBanner extends ConsumerWidget {
  const BudgetAlertBanner({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final currency = settings.baseCurrency;
    final budget = summary.budget;
    if (budget == null) return const SizedBox.shrink();

    final status = budgetStatus(spent: summary.spent, limit: budget, threshold: settings.alertThreshold);
    final (Color fg, Color bg, IconData icon, String text) = switch (status) {
      BudgetStatus.over => (
          AppColors.danger,
          AppColors.dangerLight,
          Icons.error_outline_rounded,
          l.overBudgetBy(Money.format(-summary.remaining, currency)),
        ),
      BudgetStatus.nearLimit => (
          AppColors.warningDark,
          AppColors.warningLight,
          Icons.warning_amber_rounded,
          l.approachingLimit(summary.usagePercent),
        ),
      _ => (
          AppColors.primaryDark,
          AppColors.primaryLight,
          Icons.check_circle_outline_rounded,
          l.remainingThisMonth(Money.format(summary.remaining, currency)),
        ),
    };

    final overCategories = summary.allocations.entries
        .where((e) => summary.spentFor(e.key) > e.value)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                if (overCategories > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.categoriesOverBudget(overCategories),
                    style: TextStyle(color: fg, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
