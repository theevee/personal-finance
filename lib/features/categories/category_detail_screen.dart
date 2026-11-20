import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/features/budget/budget_actions.dart';
import 'package:kabob/features/categories/category_editor.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/budget_widgets.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/progress.dart';
import 'package:kabob/shared/widgets/transaction_tile.dart';

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final categoriesAsync = ref.watch(categoriesProvider);
    final category = ref.watch(categoryMapProvider)[categoryId];
    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: categoriesAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off_rounded, title: l.notFound),
      );
    }
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    final name = categoryName(l, category);
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: l.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCategoryEditor(context, type: category.type, existing: category),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: category.type == CategoryType.income ? l.addIncome : l.addExpense,
        onPressed: () => context.push(
          '/add?type=${category.type == CategoryType.income ? 'income' : 'expense'}&category=${category.id}',
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: AsyncBody(
        value: summary,
        builder: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const Center(child: MonthSelector()),
            const SizedBox(height: 8),
            _Header(category: category, summary: s),
            const SizedBox(height: 16),
            _Trend(category: category, month: month),
            const SizedBox(height: 24),
            SectionHeader(title: l.transactionsThisMonth),
            _MonthTransactions(categoryId: categoryId, month: month),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.category, required this.summary});

  final TxCategory category;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final currency = settings.baseCurrency;
    final isIncome = category.type == CategoryType.income;
    final amount = isIncome ? (summary.incomeByCategory[category.id] ?? 0) : summary.spentFor(category.id);
    final limit = summary.allocations[category.id];
    final status = budgetStatus(spent: amount, limit: limit, threshold: settings.alertThreshold);
    final color = statusColor(status);
    final name = categoryName(l, category);

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              CategoryAvatar(iconKey: category.icon, color: Color(category.color), size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? l.earnedThisMonth : (limit == null ? l.spentThisMonth : l.categoryBudget),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        Money.format(isIncome || limit == null ? amount : limit, currency),
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isIncome && limit != null) StatusPill(label: statusLabel(l, status), color: color),
            ],
          ),
          if (!isIncome) ...[
            const SizedBox(height: 16),
            if (limit == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.setCategoryBudget),
                  onPressed: () => editAllocation(
                    context,
                    ref,
                    month: summary.month,
                    categoryId: category.id,
                    categoryLabel: name,
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: _figure(l.spent, Money.format(amount, currency), AppColors.expense)),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: _figure(
                      limit - amount < 0 ? l.over : l.remaining,
                      Money.format((limit - amount).abs(), currency),
                      limit - amount < 0 ? AppColors.danger : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: BudgetProgressBar(value: limit > 0 ? amount / limit : 0, color: color, height: 10)),
                  const SizedBox(width: 8),
                  Text(
                    '${limit > 0 ? (amount * 100 / limit).round() : 0}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => editAllocation(
                    context,
                    ref,
                    month: summary.month,
                    categoryId: category.id,
                    categoryLabel: name,
                    current: limit,
                  ),
                  child: Text(l.editBudget),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _figure(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Daily spending in this category over the selected month.
class _Trend extends ConsumerWidget {
  const _Trend({required this.category, required this.month});

  final TxCategory category;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletMapProvider);
    final txs = ref.watch(monthTransactionsProvider(month)).valueOrNull ?? const <TxRecord>[];
    final days = MonthKey.daysIn(month);
    final totals = List<int>.filled(days + 1, 0);
    for (final tx in txs) {
      if (tx.type != TxType.expense || tx.categoryId != category.id) continue;
      totals[tx.date.day] += amountInBase(tx, wallets, settings);
    }
    final divisor = settings.baseCurrency.decimals == 0 ? 1.0 : 100.0;
    final maxValue = totals.fold<int>(0, math.max) / divisor;
    final color = Color(category.color);
    final now = DateTime.now();
    final today = MonthKey.of(now) == month ? now.day : null;
    final labelDays = {1, 8, 15, 22, days};

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.spendingHistory,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: () => context.go('/records'), child: Text(l.seeAll)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
                alignment: BarChartAlignment.spaceBetween,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final d = value.toInt();
                        if (!labelDays.contains(d)) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            NumberFormat.decimalPattern(context.localeTag).format(d),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var d = 1; d <= days; d++)
                    BarChartGroupData(
                      x: d,
                      barRods: [
                        BarChartRodData(
                          // A stub keeps empty days visible as a baseline.
                          toY: totals[d] > 0 ? totals[d] / divisor : (maxValue <= 0 ? 1 : maxValue) * 0.03,
                          width: 6,
                          color: totals[d] == 0
                              ? AppColors.track
                              : d == today
                                  ? color
                                  : color.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthTransactions extends ConsumerWidget {
  const _MonthTransactions({required this.categoryId, required this.month});

  final int categoryId;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final txs = (ref.watch(monthTransactionsProvider(month)).valueOrNull ?? const <TxRecord>[])
        .where((t) => t.categoryId == categoryId)
        .toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: txs.isEmpty
          ? EmptyState(compact: true, icon: Icons.receipt_long_outlined, title: l.noTransactions)
          : Column(
              children: [
                for (var i = 0; i < txs.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  TransactionTile(tx: txs[i]),
                ],
              ],
            ),
    );
  }
}
