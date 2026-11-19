#!/bin/zsh
# Analyze + test, writing full results to build/ so they can be read afterwards.
# Copy into the project's tool/ and run:  zsh tool/check.sh [test paths...]
cd "$(dirname "$0")/.."
F="${FLUTTER:-$(zsh "$(dirname "$0")/find_flutter.sh" 2>/dev/null || command -v flutter)}"
[[ -x "$F" ]] || { echo "flutter not found; set FLUTTER=/path/to/bin/flutter"; exit 1; }
mkdir -p build
"$F" analyze > build/analyze.txt 2>&1
"$F" test "$@" > build/test.txt 2>&1
echo "analyze: $(tail -1 build/analyze.txt)"
echo "test: $(grep -oE 'All tests passed!|Some tests failed.' build/test.txt | tail -1)"
echo CHECK_DONE
