import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/icons/app_icons.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/core/theme/app_colors.dart';
import 'package:kabob/data/db/database.dart';
import 'package:kabob/data/db/enums.dart';
import 'package:kabob/data/providers.dart';
import 'package:kabob/shared/widgets/common.dart';

/// Opens the create/edit sheet. Returns the category id on save.
Future<int?> showCategoryEditor(
  BuildContext context, {
  required CategoryType type,
  TxCategory? existing,
}) {
  final initialName = existing == null ? '' : categoryName(context.l10n, existing);
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditorSheet(type: type, existing: existing, initialName: initialName),
  );
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({required this.type, required this.initialName, this.existing});

  final CategoryType type;
  final TxCategory? existing;
  final String initialName;

  @override
  ConsumerState<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _icon = widget.existing?.icon ?? 'other';
  late int _color = widget.existing?.color ?? AppColors.pickerColors.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.nameRequired);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(categoryRepositoryProvider);
    final existing = widget.existing;
    int id;
    if (existing == null) {
      id = await repo.create(name: name, type: widget.type, icon: _icon, color: _color);
    } else {
      final renamed = name != widget.initialName;
      await repo.save(existing.copyWith(
        name: renamed ? name : existing.name,
        nameKey: renamed ? const Value(null) : Value(existing.nameKey),
        icon: _icon,
        color: _color,
      ));
      id = existing.id;
    }
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final existing = widget.existing!;
    final repo = ref.read(categoryRepositoryProvider);
    final used = await repo.isUsed(existing.id);
    if (!mounted) return;
    if (used) {
      final ok = await confirmDialog(
        context,
        title: l.archiveCategoryTitle,
        message: l.archiveCategoryMessage,
        confirmLabel: l.archive,
      );
      if (!ok) return;
      await repo.setArchived(existing.id, true);
    } else {
      final ok = await confirmDialog(
        context,
        title: l.deleteCategoryTitle,
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
              existing == null ? l.newCategory : l.editCategory,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: existing == null,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.categoryName, errorText: _error, counterText: ''),
            ),
            const SizedBox(height: 16),
            Text(l.icon, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in categoryIconKeys)
                  _ChoiceCircle(
                    selected: key == _icon,
                    color: Color(_color),
                    onTap: () => setState(() => _icon = key),
                    child: Icon(iconFor(key), color: Color(_color), size: 22),
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
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(64, 52)),
                      onPressed: _busy ? null : _remove,
                      child: Text(l.delete),
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

class _ChoiceCircle extends StatelessWidget {
  const _ChoiceCircle({required this.selected, required this.color, required this.onTap, required this.child});

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.18 : 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: selected ? color : Colors.transparent, width: 2),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class ColorChoices extends StatelessWidget {
  const ColorChoices({super.key, required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in AppColors.pickerColors)
          Semantics(
            selected: c == selected,
            button: true,
            child: InkResponse(
              onTap: () => onSelected(c),
              radius: 22,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: c == selected ? AppColors.textPrimary : Colors.transparent, width: 3),
                ),
                child: c == selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
              ),
            ),
          ),
      ],
    );
  }
}
