import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/shared/widgets/app_card.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/sheets.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final version = ref.watch(packageInfoProvider).valueOrNull;
    final languageLabel = switch (settings.localeCode) {
      'km' => l.khmer,
      'en' => l.english,
      _ => l.systemDefault,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader(title: l.preferences),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text(l.language),
              subtitle: Text(languageLabel),
              onTap: () => _pickLanguage(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money_rounded),
              title: Text(l.baseCurrency),
              subtitle: Text(settings.baseCurrency.code),
              onTap: () => _pickCurrency(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange_rounded),
              title: Text(l.exchangeRate),
              subtitle: Text(l.exchangeRateValue(Money.format(settings.khrPerUsd, CurrencyCode.khr))),
              onTap: () => _editRate(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l.budgetAlert),
              subtitle: Text(l.budgetAlertDescription(settings.alertThreshold)),
              onTap: () => _editThreshold(context, ref),
            ),
          ]),
          const SizedBox(height: 24),
          SectionHeader(title: l.manage),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l.myWallets),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/wallets'),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(l.manageCategories),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/categories'),
            ),
          ]),
          const SizedBox(height: 24),
          SectionHeader(title: l.about),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l.privacyPolicy),
              subtitle: Text(l.dataStoredLocally),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l.version),
              subtitle: Text(version == null ? '…' : '${version.version} (${version.buildNumber})'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appTitle,
                applicationVersion: version?.version,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
              title: Text(l.eraseData, style: const TextStyle(color: AppColors.danger)),
              onTap: () => _erase(context, ref),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l.tagline,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref.read(settingsProvider).localeCode;
    final options = <(String?, String)>[(null, l.systemDefault), ('km', l.khmer), ('en', l.english)];
    final picked = await showDialog<(String?,)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.language),
        children: [
          for (final (code, label) in options)
            _Option(label: label, selected: code == current, onTap: () => Navigator.pop(ctx, (code,))),
        ],
      ),
    );
    if (picked == null) return;
    await ref.read(settingsProvider.notifier).setLocale(picked.$1);
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final picked = await showDialog<CurrencyCode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.baseCurrency),
        children: [
          for (final c in CurrencyCode.values)
            _Option(
              label: '${c.code} (${c.symbol})',
              selected: c == settings.baseCurrency,
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (picked == null || picked == settings.baseCurrency || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.changeBaseCurrencyTitle,
      message: l.changeBaseCurrencyMessage(
        picked.code,
        Money.format(settings.khrPerUsd, CurrencyCode.khr),
      ),
      confirmLabel: l.change,
    );
    if (!ok) return;
    await ref.read(budgetRepositoryProvider).convertAll(settings.baseCurrency, picked, settings.khrPerUsd);
    await ref.read(settingsProvider.notifier).setBaseCurrency(picked);
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final result = await showAmountSheet(
      context,
      title: l.exchangeRate,
      subtitle: l.exchangeRateHint,
      currency: CurrencyCode.khr,
      initial: ref.read(settingsProvider).khrPerUsd,
    );
    if (result == null || result.removed) return;
    await ref.read(settingsProvider.notifier).setKhrPerUsd(result.amount);
  }

  Future<void> _editThreshold(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    var value = ref.read(settingsProvider).alertThreshold.toDouble();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.budgetAlert),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.budgetAlertDescription(value.round())),
              Slider(
                value: value,
                min: 50,
                max: 100,
                divisions: 10,
                label: '${value.round()}%',
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.pop(ctx, value.round()),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(settingsProvider.notifier).setAlertThreshold(picked);
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.eraseDataTitle,
      message: l.eraseDataMessage,
      confirmLabel: l.erase,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(databaseProvider).eraseAll();
    await ref.read(settingsProvider.notifier).setLastWallet(null);
    if (!context.mounted) return;
    showMessage(context, l.dataErased);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
      onTap: onTap,
    );
  }
}
