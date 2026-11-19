# Kabob

**Better Budget. Brighter Days.** A budget-first personal finance app for Cambodia, in Khmer and English, with USD and KHR support. Everything runs offline, and all data stays on the device.

Package / bundle ID: `net.blissbyte.kabob`

## First-time setup

Requires Flutter 3.38 (Dart 3.8+) and Python 3 (macOS ships it). The Flutter version is pinned in `.fvmrc` (`fvm install` fetches it). The scripts in `tool/` find that SDK themselves through `tool/find_flutter.sh`; set `FLUTTER=/path/to/bin/flutter` to override.

```bash
bash tool/setup.sh
```

The script:

1. Runs `flutter create` to generate the `android/` and `ios/` folders. It never overwrites files that already exist, such as `lib/` or the Android manifest.
2. Patches `android/app/build.gradle.kts` to add release signing and R8 shrinking (`tool/patch_android.py`).
3. Runs `pub get`, `gen-l10n`, and `build_runner`, which generates the Drift database code.
4. Generates the launcher icons and splash screen from `assets/branding/`.
5. Sets the iOS display name, the export-compliance flag and the supported languages (km, en).
6. Runs `flutter analyze` and `flutter test`.

Then run the app:

```bash
flutter run
```

Before committing, run the analyzer and the tests. Full output goes to `build/analyze.txt` and `build/test.txt`:

```bash
zsh tool/check.sh
```

After changing the database tables in `lib/data/db/database.dart`, regenerate the code:

```bash
dart run build_runner build
```

## Architecture

```
lib/
  app/            MaterialApp, GoRouter, bottom-nav shell
  core/           theme tokens, money/currency math, settings, l10n helpers
  data/
    db/           Drift tables (wallets, categories, transactions, budgets)
    repositories/ the only code that talks to the database
    providers.dart  Riverpod providers (streams + derived month summaries)
  domain/         MonthSummary, budget status, currency conversion
  features/       home, budget, transactions (add/edit), records, reports,
                  categories, wallets, settings
  shared/widgets/ cards, progress bars, keypad, sheets, transaction tile
  l10n/           app_en.arb, app_km.arb
```

**Money rules**

- Amounts are stored as integers in the minor unit: cents for USD, riel for KHR. Floating-point numbers are never used for stored money.
- Each wallet has a currency. Budgets and reports use the **budget currency** set in Settings. Converting between USD and KHR uses the exchange rate in Settings (default ៛4,000 = $1).
- Changing the budget currency converts every saved budget at the current rate.
- Transfers move money between the user's own wallets. They never count as spending or income.

**Adding a backend later:** screens only depend on the repositories, so you can swap those for API-backed versions without touching the UI.

## Releasing

### Android (Google Play)

1. Create an upload keystore once, then copy `android/key.properties.example` to `android/key.properties` and fill it in. `key.properties` is git-ignored.
2. Bump `version:` in `pubspec.yaml`. The number after `+` must go up on every upload.
3. Build the bundle:

   ```bash
   flutter build appbundle --release
   ```

   The output is `build/app/outputs/bundle/release/app-release.aab`.

If `key.properties` is missing, the release build is signed with the debug key. Never upload that build.

### iOS (App Store)

1. Open `ios/Runner.xcworkspace` in Xcode and set your Team under Signing & Capabilities.
2. Build:

   ```bash
   flutter build ipa --release
   ```

3. Upload with Xcode Organizer or Transporter.

### Store listing checklist

- **Privacy policy URL:** both stores require a public URL. Host the text from the in-app policy (Settings → Privacy policy), for example on GitHub Pages.
- **Google Play Data safety:** "No data collected" and "No data shared". The app requests no permissions and has no network access in release builds.
- **Apple App Privacy:** "Data Not Collected".
- **Content rating:** finance or productivity, no user-generated content.
- **Screenshots:** in both Khmer and English.
- **Contact:** the in-app privacy policy points users to the store page for a contact address, so set a support email there.
