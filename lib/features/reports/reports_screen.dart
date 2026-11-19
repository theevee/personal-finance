import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/core/utils/month_key.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/l10n/app_localizations.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/budget_widgets.dart';
import 'package:kabob/shared/widgets/common.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    final previous = ref.watch(monthSummaryProvider(MonthKey.previous(month))).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.monthlyReport)),
      body: AsyncBody(
        value: summary,
        builder: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Center(child: MonthSelector()),
            const SizedBox(height: 8),
            _MetricTiles(summary: s),
            const SizedBox(height: 16),
            _CategoryBreakdown(summary: s),
            const SizedBox(height: 16),
            _DailySpending(summary: s),
            const SizedBox(height: 16),
            _Insights(summary: s, previous: previous),
            if (s.allocations.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: l.budgetVsActual),
              CategoryBudgetList(summary: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTiles extends ConsumerWidget {
  const _MetricTiles({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final currency = ref.watch(settingsProvider).baseCurrency;
    final net = summary.income - summary.spent;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            icon: Icons.arrow_upward_rounded,
            label: l.expense,
            value: Money.format(summary.spent, currency),
            caption: summary.budget == null ? null : l.percentOfBudget(summary.usagePercent),
            color: AppColors.expense,
            background: AppColors.expenseLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Metric(
            icon: Icons.arrow_downward_rounded,
            label: l.income,
            value: Money.format(summary.income, currency),
            caption: l.netAmount(Money.format(net, currency, signed: true)),
            color: AppColors.primaryDark,
            background: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, style: TextStyle(color: color, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final currency = ref.watch(settingsProvider).baseCurrency;
    final categories = ref.watch(categoryMapProvider);
    final entries = summary.spentByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Color colorOf(int id) {
      final c = categories[id];
      return c == null ? AppColors.neutral : Color(c.color);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.spendingByCategory, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            EmptyState(compact: true, icon: Icons.donut_large_rounded, title: l.noSpending)
          else ...[
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 58,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: colorOf(e.key),
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Money.format(summary.spent, currency),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(l.totalSpent, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: colorOf(e.key), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        categoryName(l, categories[e.key]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(e.value * 100 / summary.spent).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(Money.format(e.value, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DailySpending extends ConsumerWidget {
  const _DailySpending({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final currency = ref.watch(settingsProvider).baseCurrency;
    final days = MonthKey.daysIn(summary.month);
    final isCurrent = summary.month == MonthKey.now();
    final today = DateTime.now().day;
    final divisor = currency.decimals == 0 ? 1.0 : 100.0;
    final values = [for (var d = 1; d <= days; d++) (summary.spentByDay[d] ?? 0) / divisor];
    final maxValue = values.fold<double>(0, math.max);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.dailySpending, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (maxValue > 0)
                Text(
                  l.highestDay(Money.compact((maxValue * divisor).round(), currency)),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
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
                        if (d != 1 && d % 5 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('$d', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                          toY: values[d - 1],
                          width: 5,
                          color: isCurrent && d == today ? AppColors.primaryDark : AppColors.primary.withValues(alpha: 0.55),
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

class _Insights extends ConsumerWidget {
  const _Insights({required this.summary, required this.previous});

  final MonthSummary summary;
  final MonthSummary? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(categoryMapProvider);
    final items = buildInsights(l, summary, previous, categories, settings.baseCurrency, DateTime.now());
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      color: AppColors.warningLight,
      borderColor: AppColors.warningLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warningDark),
              const SizedBox(width: 8),
              Text(
                l.insights,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.warningDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final text in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: AppColors.warningDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Plain-language observations about the month.
List<String> buildInsights(
  AppLocalizations l,
  MonthSummary s,
  MonthSummary? previous,
  Map<int, TxCategory> categories,
  CurrencyCode currency,
  DateTime now,
) {
  final out = <String>[];
  if (s.spent == 0) {
    out.add(l.insightNoSpending);
    return out;
  }

  final top = s.spentByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);
  out.add(l.insightTopCategory(categoryName(l, categories[top.key]), (top.value * 100 / s.spent).round()));

  if (previous != null && previous.spent > 0) {
    final change = ((s.spent - previous.spent) * 100 / previous.spent).round();
    if (change > 0) out.add(l.insightMoreThanLastMonth(change));
    if (change < 0) out.add(l.insightLessThanLastMonth(-change));
  }

  final overCount = s.allocations.entries.where((e) => s.spentFor(e.key) > e.value).length;
  if (overCount > 0) out.add(l.categoriesOverBudget(overCount));

  final budget = s.budget;
  if (budget != null && s.month == MonthKey.of(now)) {
    if (s.remaining > 0) {
      final daysLeft = MonthKey.daysIn(s.month) - now.day + 1;
      out.add(l.insightDailyAllowance(Money.format(s.remaining ~/ daysLeft, currency)));
    } else if (s.remaining < 0) {
      out.add(l.overBudgetBy(Money.format(-s.remaining, currency)));
    }
  }
  return out;
}
