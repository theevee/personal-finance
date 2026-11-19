#!/usr/bin/env bash
# One-time project bootstrap. Run from the project root:  bash tool/setup.sh
# Safe to re-run: `flutter create` only adds files that don't exist yet.
set -euo pipefail
cd "$(dirname "$0")/.."

# Use the SDK pinned in .fvmrc (falls back to PATH). Override with FLUTTER=...
F="${FLUTTER:-$(zsh tool/find_flutter.sh)}"
D="$(dirname "$F")/dart"
echo "==> Using $F"
"$F" --version | head -1

echo "==> Generating platform folders (existing files are kept)"
"$F" create --org net.blissbyte --project-name kabob --platforms android,ios .

echo "==> Adding release signing + shrinking to Android build"
python3 tool/patch_android.py

echo "==> Fetching packages and generating localizations"
"$F" pub get
"$F" gen-l10n

echo "==> Generating Drift database code"
"$D" run build_runner build

echo "==> Generating launcher icons and splash screen"
"$D" run flutter_launcher_icons
"$D" run flutter_native_splash:create

PLIST=ios/Runner/Info.plist
if [[ -f "$PLIST" && -x /usr/libexec/PlistBuddy ]]; then
  echo "==> Configuring iOS Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Kabob" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Kabob" "$PLIST"
  /usr/libexec/PlistBuddy -c "Delete :ITSAppUsesNonExemptEncryption" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string km" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$PLIST"
fi

echo "==> Analyzing and testing"
"$F" analyze
"$F" test

echo "Done. Run the app with: $F run"
