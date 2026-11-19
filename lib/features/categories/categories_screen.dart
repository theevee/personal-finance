import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/features/categories/category_editor.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/common.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  CategoryType get _currentType => _tabs.index == 0 ? CategoryType.expense : CategoryType.income;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.categories),
        actions: [
          IconButton(
            tooltip: l.newCategory,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showCategoryEditor(context, type: _currentType),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [Tab(text: l.expense), Tab(text: l.income)],
        ),
      ),
      body: AsyncBody(
        value: categories,
        builder: (all) => TabBarView(
          controller: _tabs,
          children: [
            _CategoryList(categories: all.where((c) => c.type == CategoryType.expense).toList()),
            _CategoryList(categories: all.where((c) => c.type == CategoryType.income).toList()),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});

  final List<TxCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = categories.where((c) => !c.archived).toList();
    final archived = categories.where((c) => c.archived).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < active.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                ListTile(
                  leading: CategoryAvatar(iconKey: active[i].icon, color: Color(active[i].color)),
                  title: Text(categoryName(l, active[i])),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showCategoryEditor(context, type: active[i].type, existing: active[i]),
                ),
              ],
            ],
          ),
        ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(title: l.archived),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final c in archived)
                  ListTile(
                    leading: CategoryAvatar(iconKey: c.icon, color: AppColors.neutral),
                    title: Text(categoryName(l, c), style: const TextStyle(color: AppColors.textSecondary)),
                    trailing: TextButton(
                      onPressed: () => ref.read(categoryRepositoryProvider).setArchived(c.id, false),
                      child: Text(l.restore),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
