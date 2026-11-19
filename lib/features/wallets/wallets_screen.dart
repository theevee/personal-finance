import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/icons/app_icons.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/features/categories/category_editor.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/common.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final wallets = ref.watch(walletsProvider);
    final balances = ref.watch(walletBalancesProvider).valueOrNull ?? const <int, int>{};
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.myWallets),
        actions: [
          IconButton(
            tooltip: l.addWallet,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showWalletEditor(context),
          ),
        ],
      ),
      body: AsyncBody(
        value: wallets,
        builder: (all) {
          final active = all.where((w) => !w.archived).toList();
          final archived = all.where((w) => w.archived).toList();
          int balanceOf(Wallet w) => balances[w.id] ?? w.initialBalance;
          final total = active.fold<int>(
            0,
            (sum, w) => sum + Money.convert(balanceOf(w), w.currency, settings.baseCurrency, settings.khrPerUsd),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              AppCard(
                color: AppColors.primary,
                borderColor: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.totalBalance, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.format(total, settings.baseCurrency),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.exchangeRateValue(Money.format(settings.khrPerUsd, CurrencyCode.khr)),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (active.isEmpty)
                AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.account_balance_wallet_outlined,
                    title: l.noWallets,
                    action: FilledButton(onPressed: () => showWalletEditor(context), child: Text(l.addWallet)),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < active.length; i++) ...[
                        if (i > 0) const Divider(indent: 72),
                        _WalletTile(wallet: active[i], balance: balanceOf(active[i])),
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
                      for (final w in archived) _WalletTile(wallet: w, balance: balanceOf(w)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l.walletsHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WalletTile extends ConsumerWidget {
  const _WalletTile({required this.wallet, required this.balance});

  final Wallet wallet;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final converted = Money.convert(balance, wallet.currency, settings.baseCurrency, settings.khrPerUsd);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CategoryAvatar(
        iconKey: wallet.icon,
        color: wallet.archived ? AppColors.neutral : Color(wallet.color),
      ),
      title: Text(walletName(l, wallet), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(wallet.currency.code),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(balance, wallet.currency),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: balance < 0 ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          if (wallet.currency != settings.baseCurrency)
            Text(
              '≈ ${Money.format(converted, settings.baseCurrency)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
        ],
      ),
      onTap: () => showWalletEditor(context, existing: wallet),
    );
  }
}

Future<void> showWalletEditor(BuildContext context, {Wallet? existing}) {
  final initialName = existing == null ? '' : walletName(context.l10n, existing);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WalletEditorSheet(existing: existing, initialName: initialName),
  );
}

class _WalletEditorSheet extends ConsumerStatefulWidget {
  const _WalletEditorSheet({required this.initialName, this.existing});

  final Wallet? existing;
  final String initialName;

  @override
  ConsumerState<_WalletEditorSheet> createState() => _WalletEditorSheetState();
}

class _WalletEditorSheetState extends ConsumerState<_WalletEditorSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late CurrencyCode _currency = widget.existing?.currency ?? ref.read(settingsProvider).baseCurrency;
  late final _balance = TextEditingController(
    text: widget.existing == null || widget.existing!.initialBalance == 0
        ? ''
        : Money.toEditable(widget.existing!.initialBalance, widget.existing!.currency),
  );
  late String _icon = widget.existing?.icon ?? 'wallet';
  late int _color = widget.existing?.color ?? AppColors.pickerColors[3];
  bool _used = false;
  bool _busy = false;
  String? _nameError;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      ref.read(walletRepositoryProvider).isUsed(existing.id).then((used) {
        if (mounted) setState(() => _used = used);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    final balanceText = _balance.text.trim();
    final balance = balanceText.isEmpty ? 0 : Money.parse(balanceText, _currency);
    setState(() {
      _nameError = name.isEmpty ? l.nameRequired : null;
      _balanceError = balance == null ? l.invalidAmount : null;
    });
    if (name.isEmpty || balance == null) return;
    setState(() => _busy = true);
    final repo = ref.read(walletRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.create(name: name, currency: _currency, initialBalance: balance, icon: _icon, color: _color);
    } else {
      final renamed = name != widget.initialName;
      await repo.save(existing.copyWith(
        name: renamed ? name : existing.name,
        nameKey: renamed ? const Value(null) : Value(existing.nameKey),
        currency: _used ? existing.currency : _currency,
        initialBalance: balance,
        icon: _icon,
        color: _color,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archiveOrDelete() async {
    final l = context.l10n;
    final existing = widget.existing!;
    final repo = ref.read(walletRepositoryProvider);
    if (existing.archived) {
      await repo.setArchived(existing.id, false);
    } else if (_used) {
      final ok = await confirmDialog(
        context,
        title: l.archiveWalletTitle,
        message: l.archiveWalletMessage,
        confirmLabel: l.archive,
      );
      if (!ok) return;
      await repo.setArchived(existing.id, true);
    } else {
      final ok = await confirmDialog(
        context,
        title: l.deleteWalletTitle,
        message: l.cannotUndo,
        confirmLabel: l.delete,
        destructive: true,
      );
      if (!ok) return;
      await repo.delete(existing.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? l.addWallet : l.editWallet,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: existing == null,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.walletName, errorText: _nameError, counterText: ''),
            ),
            const SizedBox(height: 16),
            Text(l.currency, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<CurrencyCode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CurrencyCode.usd, label: Text(r'USD $')),
                ButtonSegment(value: CurrencyCode.khr, label: Text('KHR ៛')),
              ],
              selected: {_currency},
              onSelectionChanged: _used ? null : (s) => setState(() => _currency = s.first),
            ),
            if (_used) ...[
              const SizedBox(height: 4),
              Text(l.currencyLocked, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _balance,
              keyboardType: TextInputType.numberWithOptions(decimal: _currency.decimals > 0, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
              decoration: InputDecoration(
                labelText: l.initialBalance,
                prefixText: '${_currency.symbol} ',
                errorText: _balanceError,
              ),
            ),
            const SizedBox(height: 16),
            Text(l.icon, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in walletIconKeys)
                  ChoiceChip(
                    label: Icon(iconFor(key), size: 22, color: Color(_color)),
                    selected: key == _icon,
                    showCheckmark: false,
                    selectedColor: Color(_color).withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _icon = key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.color, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ColorChoices(selected: _color, onSelected: (c) => setState(() => _color = c)),
            const SizedBox(height: 24),
            Row(
              children: [
                if (existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: existing.archived ? AppColors.primary : AppColors.danger,
                        minimumSize: const Size(64, 52),
                      ),
                      onPressed: _busy ? null : _archiveOrDelete,
                      child: Text(existing.archived ? l.restore : (_used ? l.archive : l.delete)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
