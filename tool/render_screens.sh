#!/bin/zsh
# Renders the main screens into build/screens/{en,km}/ (see tool/screens_test.dart).
cd "$(dirname "$0")/.."
F="${FLUTTER:-$(zsh tool/find_flutter.sh)}"
mkdir -p build
"$F" gen-l10n > build/gen-l10n.txt 2>&1 || { cat build/gen-l10n.txt; exit 1; }
"$F" test tool/screens_test.dart > build/screens.txt 2>&1
echo "screens: $(grep -oE 'All tests passed!|Some tests failed.' build/screens.txt | tail -1)"
echo RENDER_DONE
