import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabob/app/router.dart';
import 'package:kabob/core/settings/app_settings.dart';
import 'package:kabob/core/theme/app_theme.dart';
import 'package:kabob/l10n/app_localizations.dart';

class KabobApp extends ConsumerWidget {
  const KabobApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final localeCode = ref.watch(settingsProvider.select((s) => s.localeCode));
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: localeCode == null ? null : Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Khmer-first: anything that is not English falls back to Khmer.
      localeResolutionCallback: (locale, supported) =>
          locale?.languageCode == 'en' ? const Locale('en') : const Locale('km'),
    );
  }
}
