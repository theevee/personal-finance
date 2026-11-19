import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/core/money/currency.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

@immutable
class AppSettings {
  const AppSettings({
    this.localeCode,
    this.baseCurrency = CurrencyCode.usd,
    this.khrPerUsd = defaultKhrPerUsd,
    this.alertThreshold = defaultAlertThreshold,
    this.lastWalletId,
  });

  static const int defaultKhrPerUsd = 4000;
  static const int defaultAlertThreshold = 80;

  /// `null` means follow the device language.
  final String? localeCode;

  /// Currency budgets and reports are expressed in.
  final CurrencyCode baseCurrency;

  /// Riel per one US dollar, used to convert between wallets.
  final int khrPerUsd;

  /// Percent of a budget at which Kabob starts warning (50–100).
  final int alertThreshold;

  /// Wallet pre-selected on the Add screen.
  final int? lastWalletId;

  AppSettings copyWith({
    ValueGetter<String?>? localeCode,
    CurrencyCode? baseCurrency,
    int? khrPerUsd,
    int? alertThreshold,
    ValueGetter<int?>? lastWalletId,
  }) {
    return AppSettings(
      localeCode: localeCode != null ? localeCode() : this.localeCode,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      khrPerUsd: khrPerUsd ?? this.khrPerUsd,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      lastWalletId: lastWalletId != null ? lastWalletId() : this.lastWalletId,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _kLocale = 'settings.locale';
  static const _kBase = 'settings.baseCurrency';
  static const _kRate = 'settings.khrPerUsd';
  static const _kAlert = 'settings.alertThreshold';
  static const _kLastWallet = 'settings.lastWalletId';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      localeCode: p.getString(_kLocale),
      baseCurrency: CurrencyCode.values.asNameMap()[p.getString(_kBase)] ?? CurrencyCode.usd,
      khrPerUsd: p.getInt(_kRate) ?? AppSettings.defaultKhrPerUsd,
      alertThreshold: p.getInt(_kAlert) ?? AppSettings.defaultAlertThreshold,
      lastWalletId: p.getInt(_kLastWallet),
    );
  }

  Future<void> setLocale(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
    state = state.copyWith(localeCode: () => code);
  }

  Future<void> setBaseCurrency(CurrencyCode currency) async {
    await _prefs.setString(_kBase, currency.name);
    state = state.copyWith(baseCurrency: currency);
  }

  Future<void> setKhrPerUsd(int rate) async {
    if (rate <= 0) return;
    await _prefs.setInt(_kRate, rate);
    state = state.copyWith(khrPerUsd: rate);
  }

  Future<void> setAlertThreshold(int percent) async {
    final value = percent.clamp(50, 100);
    await _prefs.setInt(_kAlert, value);
    state = state.copyWith(alertThreshold: value);
  }

  Future<void> setLastWallet(int? id) async {
    if (id == state.lastWalletId) return;
    if (id == null) {
      await _prefs.remove(_kLastWallet);
    } else {
      await _prefs.setInt(_kLastWallet, id);
    }
    state = state.copyWith(lastWalletId: () => id);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
