import 'package:intl/intl.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:kabob/core/money/money.dart';

/// Pure logic behind the on-screen numeric keypad. The buffer is a plain
/// decimal string such as `12.5`; keys are digits, `.`, `000`, `back`, `clear`.
abstract final class AmountInput {
  static const int maxWholeDigits = 10;
  static const String keyBack = 'back';
  static const String keyClear = 'clear';
  static const String keyDot = '.';
  static const String keyTripleZero = '000';

  static final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');
  static final RegExp _digit = RegExp(r'^\d$');

  static String apply(String current, String key, CurrencyCode currency) {
    if (key == keyClear) return '';
    if (key == keyBack) {
      return current.isEmpty ? current : current.substring(0, current.length - 1);
    }
    final dotIndex = current.indexOf('.');
    if (key == keyDot) {
      if (currency.decimals == 0 || dotIndex >= 0) return current;
      return current.isEmpty ? '0.' : '$current.';
    }
    if (key == keyTripleZero) {
      if (current.isEmpty || current == '0' || dotIndex >= 0) return current;
      if (current.length + 3 > maxWholeDigits) return current;
      return '${current}000';
    }
    if (!_digit.hasMatch(key)) return current;
    if (dotIndex >= 0) {
      final decimals = current.length - dotIndex - 1;
      if (decimals >= currency.decimals) return current;
      return current + key;
    }
    if (current == '0') return key;
    if (current.length >= maxWholeDigits) return current;
    return current + key;
  }

  static String fromMinor(int? minor, CurrencyCode currency) {
    if (minor == null || minor <= 0) return '';
    return Money.toEditable(minor, currency);
  }

  /// Display text for the buffer, e.g. `$1,250.5`.
  static String display(String buffer, CurrencyCode currency) {
    final b = buffer.isEmpty ? '0' : buffer;
    final parts = b.split('.');
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    final frac = parts.length > 1 ? '.${parts[1]}' : '';
    return '${currency.symbol}${_grouped.format(whole)}$frac';
  }
}
