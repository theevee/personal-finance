import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/money/amount_input.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/features/categories/category_editor.dart';
import 'package:kabob/shared/widgets/category_avatar.dart';
import 'package:kabob/shared/widgets/common.dart';
import 'package:kabob/shared/widgets/numeric_keypad.dart';
import 'package:kabob/shared/widgets/sheets.dart';

/// Fast entry screen for expenses, income and transfers (also used to edit).
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType = TxType.expense,
    this.transactionId,
    this.initialCategoryId,
  });

  final TxType initialType;
  final int? transactionId;
  final int? initialCategoryId;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

enum _Target { amount, received }

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TxType _type = widget.initialType;
  String _amount = '';
  String _received = '';
  bool _receivedEdited = false;
  _Target _target = _Target.amount;
  int? _categoryId;
  int? _walletId;
  int? _toWalletId;
  DateTime _date = DateTime.now();
  final _note = TextEditingController();
  bool _loading = false;

  /// The amount keypad. It opens for a new record and closes once a category
  /// is picked, so wallet, date and note come into view.
  late bool _keypad = widget.transactionId == null;
  bool _saving = false;

  bool get _isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tx = await ref.read(transactionRepositoryProvider).getById(widget.transactionId!);
    final wallets = await ref.read(walletsProvider.future);
    if (!mounted) return;
    if (tx == null) {
      context.pop();
      return;
    }
    final byId = {for (final w in wallets) w.id: w};
    setState(() {
      _type = tx.type;
      _walletId = tx.walletId;
      _toWalletId = tx.toWalletId;
      _categoryId = tx.categoryId;
      _date = tx.date;
      _note.text = tx.note;
      _amount = AmountInput.fromMinor(tx.amount, byId[tx.walletId]?.currency ?? CurrencyCode.usd);
      final to = tx.toWalletId == null ? null : byId[tx.toWalletId];
      if (tx.toAmount != null && to != null) {
        _received = AmountInput.fromMinor(tx.toAmount, to.currency);
        _receivedEdited = true;
      }
      _loading = false;
    });
  }

  int? _defaultWalletId(List<Wallet> active, AppSettings settings) {
    if (active.isEmpty) return null;
    final last = settings.lastWalletId;
    if (last != null && active.any((w) => w.id == last)) return last;
    return active.first.id;
  }

  Wallet? _fromWallet() {
    final id = _walletId ?? _defaultWalletId(ref.read(activeWalletsProvider), ref.read(settingsProvider));
    return id == null ? null : ref.read(walletMapProvider)[id];
  }

  Wallet? _toWallet() => _toWalletId == null ? null : ref.read(walletMapProvider)[_toWalletId];

  /// Received amount for a cross-currency transfer, auto-converted until the
  /// user types their own figure.
  String _receivedBuffer(Wallet from, Wallet to) {
    if (_receivedEdited) return _received;
    final amount = Money.parse(_amount, from.currency) ?? 0;
    final converted = Money.convert(amount, from.currency, to.currency, ref.read(settingsProvider).khrPerUsd);
    return AmountInput.fromMinor(converted, to.currency);
  }

  void _onKey(String key) {
    final from = _fromWallet();
    final to = _toWallet();
    setState(() {
      if (_target == _Target.received && from != null && to != null) {
        final start = _receivedEdited ? _received : '';
        _received = AmountInput.apply(start, key, to.currency);
        _receivedEdited = true;
      } else {
        _amount = AmountInput.apply(_amount, key, from?.currency ?? ref.read(settingsProvider).baseCurrency);
      }
    });
  }

  void _openKeypad(_Target target) {
    FocusScope.of(context).unfocus();
    setState(() {
      _target = target;
      _keypad = true;
    });
  }

  Future<void> _pickWallet({required bool source}) async {
    final active = ref.read(activeWalletsProvider);
    final from = _fromWallet();
    final picked = await showWalletPicker(
      context,
      wallets: active,
      selectedId: source ? from?.id : _toWalletId,
      excludeId: source || _type != TxType.transfer ? null : from?.id,
    );
    if (picked == null) return;
    setState(() {
      if (source) {
        _walletId = picked;
        if (_toWalletId == picked) _toWalletId = null;
      } else {
        _toWalletId = picked;
      }
      _receivedEdited = false;
      _received = '';
      _target = _Target.amount;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  Future<void> _addCategory() async {
    final id = await showCategoryEditor(
      context,
      type: _type == TxType.income ? CategoryType.income : CategoryType.expense,
    );
    if (id != null && mounted) setState(() => _categoryId = id);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final from = _fromWallet();
    if (from == null) {
      showMessage(context, l.walletRequired);
      return;
    }
    final amount = Money.parse(_amount, from.currency) ?? 0;
    if (amount <= 0) {
      showMessage(context, l.amountRequired);
      return;
    }
    int? toAmount;
    if (_type == TxType.transfer) {
      final to = _toWallet();
      if (to == null) {
        showMessage(context, l.toWalletRequired);
        return;
      }
      if (to.id == from.id) {
        showMessage(context, l.sameWalletError);
        return;
      }
      toAmount = to.currency == from.currency
          ? amount
          : _receivedEdited
              ? (Money.parse(_received, to.currency) ?? 0)
              : Money.convert(amount, from.currency, to.currency, settings.khrPerUsd);
      if (toAmount <= 0) {
        showMessage(context, l.amountRequired);
        return;
      }
    } else if (_categoryId == null) {
      showMessage(context, l.categoryRequired);
      return;
    }

    setState(() => _saving = true);
    final isTransfer = _type == TxType.transfer;
    final entry = TransactionsCompanion(
      type: Value(_type),
      amount: Value(amount),
      walletId: Value(from.id),
      toWalletId: Value(isTransfer ? _toWalletId : null),
      toAmount: Value(isTransfer ? toAmount : null),
      categoryId: Value(isTransfer ? null : _categoryId),
      date: Value(_date),
      note: Value(_note.text.trim()),
    );
    final repo = ref.read(transactionRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateFields(widget.transactionId!, entry);
      } else {
        await repo.insert(entry);
      }
      await ref.read(settingsProvider.notifier).setLastWallet(from.id);
      if (!mounted) return;
      showMessage(context, l.saved);
      context.pop();
    } catch (e, st) {
      debugPrint('Save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, l.somethingWentWrong);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.deleteTransactionTitle,
      message: l.cannotUndo,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(transactionRepositoryProvider).delete(widget.transactionId!);
    if (!mounted) return;
    showMessage(context, l.deleted);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final active = ref.watch(activeWalletsProvider);
    final walletMap = ref.watch(walletMapProvider);
    final allCategories = ref.watch(categoriesProvider).valueOrNull ?? const <TxCategory>[];
    final categoryType = _type == TxType.income ? CategoryType.income : CategoryType.expense;
    final categories = allCategories.where((c) => c.type == categoryType && (!c.archived || c.id == _categoryId)).toList();

    final fromId = _walletId ?? _defaultWalletId(active, settings);
    final from = fromId == null ? null : walletMap[fromId];
    final to = _toWalletId == null ? null : walletMap[_toWalletId];
    final currency = from?.currency ?? settings.baseCurrency;
    final crossCurrency = _type == TxType.transfer && from != null && to != null && from.currency != to.currency;
    final keypadCurrency = crossCurrency && _target == _Target.received ? to.currency : currency;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final accent = switch (_type) {
      TxType.expense => AppColors.expense,
      TxType.income => AppColors.income,
      TxType.transfer => AppColors.transfer,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editTransaction : l.newTransaction),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TxType>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: accent.withValues(alpha: 0.14),
                        selectedForegroundColor: accent,
                      ),
                      segments: [
                        ButtonSegment(value: TxType.expense, label: Text(l.expense)),
                        ButtonSegment(value: TxType.income, label: Text(l.income)),
                        ButtonSegment(value: TxType.transfer, label: Text(l.transfer)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() {
                        _type = s.first;
                        _categoryId = null;
                        _target = _Target.amount;
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _AmountDisplay(
                        label: crossCurrency ? l.amountSent : null,
                        text: AmountInput.display(_amount, currency),
                        color: accent,
                        active: _target == _Target.amount,
                        onTap: () => _openKeypad(_Target.amount),
                      ),
                      if (_type == TxType.transfer) ...[
                        const SizedBox(height: 12),
                        _FieldRow(
                          icon: Icons.north_east_rounded,
                          label: l.fromWallet,
                          value: from == null ? l.selectWallet : walletName(l, from),
                          onTap: () => _pickWallet(source: true),
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(
                          icon: Icons.south_west_rounded,
                          label: l.toWallet,
                          value: to == null ? l.selectWallet : walletName(l, to),
                          onTap: () => _pickWallet(source: false),
                        ),
                        if (crossCurrency) ...[
                          const SizedBox(height: 8),
                          _AmountDisplay(
                            label: l.amountReceived,
                            text: AmountInput.display(_receivedBuffer(from, to), to.currency),
                            color: AppColors.transfer,
                            active: _target == _Target.received,
                            compact: true,
                            onTap: () => _openKeypad(_Target.received),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l.transferHint,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        _CategoryGrid(
                          categories: categories,
                          selectedId: _categoryId,
                          onSelected: (id) => setState(() {
                            _categoryId = id;
                            if (_amount.isNotEmpty) _keypad = false;
                          }),
                          onAdd: _addCategory,
                        ),
                        const SizedBox(height: 12),
                        _FieldRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: l.wallet,
                          value: from == null ? l.selectWallet : '${walletName(l, from)} (${from.currency.code})',
                          onTap: () => _pickWallet(source: true),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _FieldRow(
                        icon: Icons.calendar_today_outlined,
                        label: l.date,
                        value: dayLabel(context, _date),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        onTap: () => setState(() => _keypad = false),
                        decoration: InputDecoration(
                          hintText: l.noteOptional,
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!keyboardOpen)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              alignment: Alignment.topCenter,
                              child: _keypad
                                  ? Column(
                                      children: [
                                        NumericKeypad(
                                          keyHeight: 46,
                                          allowDecimal: keypadCurrency.decimals > 0,
                                          onKey: _onKey,
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => setState(() => _keypad = false),
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                            label: Text(l.done),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: Text(l.save),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.text,
    required this.color,
    required this.active,
    required this.onTap,
    this.label,
    this.compact = false,
  });

  final String text;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
          ),
          child: Column(
            children: [
              if (label != null)
                Text(label!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: compact ? 24 : 40,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  final List<TxCategory> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final c in categories)
          _CategoryCell(
            label: categoryName(l, c),
            selected: c.id == selectedId,
            onTap: () => onSelected(c.id),
            child: CategoryAvatar(iconKey: c.icon, color: Color(c.color), size: 44),
          ),
        _CategoryCell(
          label: l.add,
          selected: false,
          onTap: onAdd,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.label, required this.selected, required this.onTap, required this.child});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                child,
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
