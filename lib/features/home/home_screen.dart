import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/budget_widgets.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/transaction_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: const Align(alignment: AlignmentDirectional.centerStart, child: MonthDropdown()),
        actions: [
          _AlertsButton(summary: summary.valueOrNull),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: AsyncBody(value: summary, builder: (s) => _HomeBody(summary: s)),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        BudgetOverviewCard(summary: summary),
        if (summary.budget != null) ...[
          const SizedBox(height: 12),
          BudgetAlertBanner(summary: summary),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.remove_rounded,
                label: l.addExpense,
                color: AppColors.expense,
                background: AppColors.expenseLight,
                onTap: () => context.push('/add?type=expense'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickAction(
                icon: Icons.add_rounded,
                label: l.addIncome,
                color: AppColors.primaryDark,
                background: AppColors.primaryLight,
                onTap: () => context.push('/add?type=income'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: l.categoryBudgets,
          actionLabel: l.manage,
          onAction: () => context.go('/budget'),
        ),
        if (summary.allocations.isEmpty)
          AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.pie_chart_outline_rounded,
              title: l.noCategoryBudgets,
              message: l.noCategoryBudgetsMessage,
            ),
          )
        else
          CategoryBudgetList(summary: summary, limit: 5),
        const SizedBox(height: 24),
        SectionHeader(
          title: l.recentTransactions,
          actionLabel: l.seeAll,
          onAction: () => context.go('/records'),
        ),
        const _RecentTransactions(),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recent = ref.watch(recentTransactionsProvider);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: recent.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Padding(padding: const EdgeInsets.all(16), child: Text(l.somethingWentWrong)),
        data: (txs) {
          if (txs.isEmpty) {
            return EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: l.noTransactions,
              message: l.noTransactionsMessage,
            );
          }
          return Column(
            children: [
              for (var i = 0; i < txs.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                TransactionTile(tx: txs[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Categories (and the whole month) that reached the alert threshold.
List<MapEntry<int, int>> _alertCategories(MonthSummary s, int threshold) {
  final list = s.allocations.entries
      .where((e) => budgetStatus(spent: s.spentFor(e.key), limit: e.value, threshold: threshold).index >=
          BudgetStatus.nearLimit.index)
      .toList()
    ..sort((a, b) => (s.spentFor(b.key) * a.value).compareTo(s.spentFor(a.key) * b.value));
  return list;
}

class _AlertsButton extends ConsumerWidget {
  const _AlertsButton({required this.summary});

  final MonthSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    final s = summary;
    var count = 0;
    if (s != null) {
      count = _alertCategories(s, threshold).length;
      final overall = budgetStatus(spent: s.spent, limit: s.budget, threshold: threshold);
      if (overall.index >= BudgetStatus.nearLimit.index) count++;
    }
    return IconButton(
      tooltip: l.budgetAlerts,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_none_rounded),
      ),
      onPressed: s == null
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AlertsSheet(month: s.month),
              ),
    );
  }
}

class _AlertsSheet extends ConsumerWidget {
  const _AlertsSheet({required this.month});

  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    final categories = ref.watch(categoryMapProvider);
    final s = ref.watch(monthSummaryProvider(month)).valueOrNull;
    if (s == null) return const SizedBox(height: 200);
    final alerts = _alertCategories(s, threshold);
    final overall = budgetStatus(spent: s.spent, limit: s.budget, threshold: threshold);
    final showOverall = overall.index >= BudgetStatus.nearLimit.index;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.budgetAlerts, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (showOverall) ...[
              BudgetAlertBanner(summary: s),
              const SizedBox(height: 12),
            ],
            if (alerts.isEmpty && !showOverall)
              EmptyState(
                compact: true,
                icon: Icons.notifications_off_outlined,
                title: l.noAlerts,
                message: l.noAlertsMessage,
              )
            else if (alerts.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < alerts.length; i++) ...[
                      if (i > 0) const Divider(indent: 68),
                      CategoryBudgetRow(
                        category: categories[alerts[i].key],
                        spent: s.spentFor(alerts[i].key),
                        limit: alerts[i].value,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/category/${alerts[i].key}');
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
