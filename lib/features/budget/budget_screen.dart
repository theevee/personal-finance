import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/features/budget/budget_actions.dart';
import 'package:kabob/features/categories/category_editor.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/progress.dart';
import 'package:kabob/shared/widgets/sheets.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.budgetTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'copy') copyPreviousBudget(context, ref, month);
              if (value == 'categories') context.push('/categories');
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'copy', child: Text(l.copyLastMonth)),
              PopupMenuItem(value: 'categories', child: Text(l.manageCategories)),
            ],
          ),
        ],
      ),
      body: AsyncBody(value: summary, builder: (s) => _BudgetBody(summary: s)),
    );
  }
}

class _BudgetBody extends ConsumerWidget {
  const _BudgetBody({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final currency = ref.watch(settingsProvider).baseCurrency;
    final categories = ref.watch(categoryMapProvider);
    final budget = summary.budget;
    final entries = summary.allocations.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Center(child: MonthSelector()),
        const SizedBox(height: 8),
        AppCard(
          onTap: () => editTotalBudget(context, ref, summary.month, budget),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.monthlyBudget, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      budget == null ? l.notSet : Money.format(budget, currency),
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: l.edit,
                icon: Icon(budget == null ? Icons.add_rounded : Icons.edit_outlined),
                onPressed: () => editTotalBudget(context, ref, summary.month, budget),
              ),
            ],
          ),
        ),
        if (budget == null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => copyPreviousBudget(context, ref, summary.month),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: Text(l.copyLastMonth),
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(title: l.allocationByCategory),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: entries.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: Icons.pie_chart_outline_rounded,
                  title: l.noCategoryBudgets,
                  message: l.noCategoryBudgetsMessage,
                )
              : Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const Divider(indent: 68),
                      Builder(builder: (context) {
                        final category = categories[entries[i].key];
                        final amount = entries[i].value;
                        final share = (budget ?? 0) > 0 ? amount / budget! : 0.0;
                        final label = categoryName(l, category);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CategoryAvatar(
                            iconKey: category?.icon ?? 'other',
                            color: category == null ? AppColors.neutral : Color(category.color),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                Money.format(amount, currency),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(child: BudgetProgressBar(value: share, color: AppColors.primary, height: 6)),
                                const SizedBox(width: 8),
                                Text(
                                  '${(share * 100).round()}%',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => editAllocation(
                            context,
                            ref,
                            month: summary.month,
                            categoryId: entries[i].key,
                            categoryLabel: label,
                            current: amount,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addAllocation(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: Text(l.addCategoryBudget),
        ),
        const SizedBox(height: 16),
        _AllocationSummary(summary: summary),
      ],
    );
  }

  Future<void> _addAllocation(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final all = ref.read(categoriesProvider).valueOrNull ?? const [];
    final available = all
        .where((c) => !c.archived && c.type == CategoryType.expense && !summary.allocations.containsKey(c.id))
        .toList();
    var picked = await showCategoryPicker(context, categories: available);
    if (picked == null || !context.mounted) return;
    if (picked == kNewCategory) {
      picked = await showCategoryEditor(context, type: CategoryType.expense);
      if (picked == null || !context.mounted) return;
    }
    final category = ref.read(categoryMapProvider)[picked];
    await editAllocation(
      context,
      ref,
      month: summary.month,
      categoryId: picked,
      categoryLabel: category == null ? l.newCategory : categoryName(l, category),
    );
  }
}

class _AllocationSummary extends ConsumerWidget {
  const _AllocationSummary({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final currency = ref.watch(settingsProvider).baseCurrency;
    final budget = summary.budget;
    final unallocated = summary.unallocated;
    final over = budget != null && unallocated < 0;
    final full = budget != null && unallocated == 0;

    final (Color fg, Color bg, IconData icon, String message) = budget == null
        ? (AppColors.textSecondary, AppColors.surface, Icons.info_outline_rounded, l.setTotalFirst)
        : over
            ? (AppColors.danger, AppColors.dangerLight, Icons.error_outline_rounded,
                l.overAllocated(Money.format(-unallocated, currency)))
            : full
                ? (AppColors.primaryDark, AppColors.primaryLight, Icons.check_circle_outline_rounded,
                    l.fullyAllocated)
                : (AppColors.primaryDark, AppColors.primaryLight, Icons.info_outline_rounded,
                    l.unallocatedHint(Money.format(unallocated, currency)));

    return AppCard(
      color: bg,
      borderColor: bg == AppColors.surface ? null : bg,
      child: Column(
        children: [
          _row(l.totalAllocated, Money.format(summary.allocated, currency), AppColors.textPrimary),
          if (budget != null) ...[
            const SizedBox(height: 8),
            _row(l.unallocated, Money.format(unallocated, currency), over ? AppColors.danger : AppColors.textPrimary),
          ],
          ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(message, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
