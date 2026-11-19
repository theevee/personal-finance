import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF16A34A);
  static const primaryDark = Color(0xFF15803D);
  static const primaryLight = Color(0xFFDCFCE7);
  static const background = Color(0xFFF7F9F7);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF17212B);
  static const textSecondary = Color(0xFF64748B);
  static const expense = Color(0xFFE85D75);
  static const expenseLight = Color(0xFFFDECEF);
  static const income = Color(0xFF16A34A);
  static const transfer = Color(0xFF3B82F6);
  static const transferLight = Color(0xFFDBEAFE);
  static const warning = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFB45309);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEE2E2);
  static const border = Color(0xFFE6ECE8);
  static const track = Color(0xFFE9EFEA);
  static const neutral = Color(0xFF94A3B8);

  /// Palette offered when creating categories and wallets.
  static const pickerColors = <int>[
    0xFF16A34A, 0xFF0D9488, 0xFF0EA5E9, 0xFF3B82F6, 0xFF6366F1, 0xFFA855F7,
    0xFFEC4899, 0xFFEF6C57, 0xFFF97316, 0xFFF59E0B, 0xFF84CC16, 0xFF64748B,
  ];
}
