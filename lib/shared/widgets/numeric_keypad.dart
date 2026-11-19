import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kabob/core/money/amount_input.dart';
import 'package:kabob/core/theme/app_colors.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.onKey, this.allowDecimal = true, this.keyHeight = 52});

  final ValueChanged<String> onKey;
  final bool allowDecimal;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [allowDecimal ? AmountInput.keyDot : AmountInput.keyTripleZero, '0', AmountInput.keyBack],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            children: [
              for (final k in row)
                Expanded(child: _Key(value: k, onKey: onKey, height: keyHeight)),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.value, required this.onKey, required this.height});

  final String value;
  final ValueChanged<String> onKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isBack = value == AmountInput.keyBack;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onKey(value);
          },
          onLongPress: isBack ? () => onKey(AmountInput.keyClear) : null,
          child: SizedBox(
            height: height,
            child: Center(
              child: isBack
                  ? Icon(
                      Icons.backspace_outlined,
                      semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
