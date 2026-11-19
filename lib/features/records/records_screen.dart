import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/domain/month_summary.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/transaction_tile.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  final _search = TextEditingController();
  String _query = '';
  TxType? _filter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(TxRecord tx, Map<int, TxCategory> categories, Map<int, Wallet> wallets) {
    if (_filter != null && tx.type != _filter) return false;
    if (_query.isEmpty) return true;
    final l = context.l10n;
    final currency = wallets[tx.walletId]?.currency;
    final haystack = [
      tx.note,
      if (tx.categoryId != null) categoryName(l, categories[tx.categoryId]),
      walletName(l, wallets[tx.walletId]),
      if (tx.toWalletId != null) walletName(l, wallets[tx.toWalletId]),
      if (currency != null) Money.format(tx.amount, currency),
    ].join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    final txs = ref.watch(monthTransactionsProvider(month));
    final categories = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.records)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.clear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(l.all, null),
                _chip(l.expense, TxType.expense),
                _chip(l.income, TxType.income),
                _chip(l.transfer, TxType.transfer),
              ],
            ),
          ),
          const MonthSelector(),
          Expanded(
            child: AsyncBody(
              value: txs,
              builder: (list) {
                final filtered = list.where((t) => _matches(t, categories, wallets)).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: list.isEmpty ? l.noTransactions : l.noMatches,
                    message: list.isEmpty ? l.noTransactionsMessage : null,
                  );
                }
                final groups = <DateTime, List<TxRecord>>{};
                for (final tx in filtered) {
                  final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
                  groups.putIfAbsent(day, () => []).add(tx);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final entry in groups.entries) ...[
                      _DayHeader(
                        label: dayLabel(context, entry.key),
                        expense: entry.value
                            .where((t) => t.type == TxType.expense)
                            .fold(0, (sum, t) => sum + amountInBase(t, wallets, settings)),
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++) ...[
                              if (i > 0) const Divider(indent: 72),
                              TransactionTile(tx: entry.value[i], showDate: false),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, TxType? type) {
    final selected = _filter == type;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filter = type),
      ),
    );
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.label, required this.expense});

  final String label;
  final int expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(settingsProvider).baseCurrency;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          if (expense > 0)
            Text(
              Money.format(-expense, currency),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
