import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/features/budget/budget_screen.dart';
import 'package:kabob/features/categories/categories_screen.dart';
import 'package:kabob/features/categories/category_detail_screen.dart';
import 'package:kabob/features/home/home_screen.dart';
import 'package:kabob/features/records/records_screen.dart';
import 'package:kabob/features/reports/reports_screen.dart';
import 'package:kabob/features/settings/privacy_screen.dart';
import 'package:kabob/features/settings/settings_screen.dart';
import 'package:kabob/features/transactions/add_transaction_screen.dart';
import 'package:kabob/features/wallets/wallets_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/budget', builder: (context, state) => const BudgetScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/records', builder: (context, state) => const RecordsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return AddTransactionScreen(
            initialType: TxType.values.asNameMap()[q['type']] ?? TxType.expense,
            transactionId: int.tryParse(q['id'] ?? ''),
            initialCategoryId: int.tryParse(q['category'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) =>
            CategoryDetailScreen(categoryId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1),
      ),
      GoRoute(path: '/wallets', builder: (context, state) => const WalletsScreen()),
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Bottom navigation: Home · Budget · (+) · Records · Reports.
/// The centre item is an action that opens the Add screen, not a tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = shell.currentIndex;
    final selected = branch >= 2 ? branch + 1 : branch;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE6ECE8))),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) {
            if (index == 2) {
              context.push('/add');
              return;
            }
            final target = index > 2 ? index - 1 : index;
            shell.goBranch(target, initialLocation: target == shell.currentIndex);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.savings_outlined),
              selectedIcon: const Icon(Icons.savings_rounded),
              label: l.navBudget,
            ),
            NavigationDestination(icon: const _AddIcon(), label: l.navAdd),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: l.navRecords,
            ),
            NavigationDestination(
              icon: const Icon(Icons.insert_chart_outlined_rounded),
              selectedIcon: const Icon(Icons.insert_chart_rounded),
              label: l.navReports,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddIcon extends StatelessWidget {
  const _AddIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }
}
