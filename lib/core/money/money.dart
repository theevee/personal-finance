import 'package:intl/intl.dart';
import 'package:kabob/core/money/currency.dart';

/// Formatting, parsing and conversion of integer minor-unit amounts.
abstract final class Money {
  static final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');
  static final RegExp _pattern = RegExp(r'^(-)?(\d*)(?:\.(\d*))?$');

  /// Formats [minor] (cents / riel) as e.g. `$1,234.50` or `៛490,000`.
  static String format(int minor, CurrencyCode currency, {bool signed = false}) {
    final negative = minor < 0;
    final text = '${currency.symbol}${_body(minor.abs(), currency)}';
    if (negative) return '-$text';
    if (signed && minor > 0) return '+$text';
    return text;
  }

  /// Short label for chart axes, e.g. `$1.2K`.
  static String compact(int minor, CurrencyCode currency) {
    final major = currency.decimals == 0 ? minor.toDouble() : minor / 100;
    final abs = major.abs();
    String body;
    if (abs >= 1000000) {
      body = '${_trim(major / 1000000)}M';
    } else if (abs >= 1000) {
      body = '${_trim(major / 1000)}K';
    } else {
      body = major.round().toString();
    }
    return '${currency.symbol}$body';
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String _body(int abs, CurrencyCode currency) {
    if (currency.decimals == 0) return _grouped.format(abs);
    final whole = abs ~/ 100;
    final cents = abs % 100;
    return '${_grouped.format(whole)}.${cents.toString().padLeft(2, '0')}';
  }

  /// Parses user text such as `12.5`, `1,000` or `-3` into minor units.
  /// Returns null when the text is not a valid amount.
  static int? parse(String input, CurrencyCode currency) {
    final s = input.replaceAll(',', '').replaceAll(' ', '').trim();
    final m = _pattern.firstMatch(s);
    if (m == null) return null;
    final wholeStr = m.group(2) ?? '';
    final fracStr = m.group(3) ?? '';
    if (wholeStr.isEmpty && fracStr.isEmpty) return null;
    if (wholeStr.length > 12) return null;
    final whole = wholeStr.isEmpty ? 0 : int.parse(wholeStr);
    int value;
    if (currency.decimals == 0) {
      value = whole;
    } else {
      final frac = fracStr.length >= 2 ? fracStr.substring(0, 2) : fracStr.padRight(2, '0');
      value = whole * 100 + int.parse(frac);
    }
    return m.group(1) == null ? value : -value;
  }

  /// Plain editable text for [minor], e.g. `12.5` → `12.50`, `1200` → `12`.
  static String toEditable(int minor, CurrencyCode currency) {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    if (currency.decimals == 0) return '$sign$abs';
    final whole = abs ~/ 100;
    final cents = abs % 100;
    if (cents == 0) return '$sign$whole';
    return '$sign$whole.${cents.toString().padLeft(2, '0')}';
  }

  /// Converts between USD cents and KHR riel using [khrPerUsd]
  /// (how many riel buy one US dollar).
  static int convert(int minor, CurrencyCode from, CurrencyCode to, int khrPerUsd) {
    if (from == to || khrPerUsd <= 0) return minor;
    if (from == CurrencyCode.usd) return (minor * khrPerUsd / 100).round();
    return (minor * 100 / khrPerUsd).round();
  }
}
