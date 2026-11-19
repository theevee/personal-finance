#!/bin/zsh
# Prints the path of the flutter binary this project should use.
# Run from the Flutter project root:  F=$(zsh find_flutter.sh)
emulate -L zsh
setopt null_glob

pick() { [[ -x "$1/bin/flutter" ]] && { echo "$1/bin/flutter"; exit 0; } }

# 1. FVM config
if [[ -f .fvmrc ]]; then
  v=$(sed -nE 's/.*"flutter"[^"]*"([^"]+)".*/\1/p' .fvmrc | head -1)
  [[ -n $v ]] && pick "$HOME/fvm/versions/$v"
fi
[[ -L .fvm/flutter_sdk || -d .fvm/flutter_sdk ]] && pick "$(cd .fvm/flutter_sdk && pwd -P)"
if [[ -f .fvm/fvm_config.json ]]; then
  v=$(sed -nE 's/.*"flutterSdkVersion"[^"]*"([^"]+)".*/\1/p' .fvm/fvm_config.json | head -1)
  [[ -n $v ]] && pick "$HOME/fvm/versions/$v"
fi

# 2. SDK the Android build last used
if [[ -f android/local.properties ]]; then
  s=$(sed -nE 's/^flutter\.sdk=(.*)$/\1/p' android/local.properties | head -1)
  [[ -n $s ]] && pick "$s"
fi

# 3. PATH
command -v flutter >/dev/null 2>&1 && { command -v flutter; exit 0; }

# 4. Newest FVM install, then common locations
for d in ${(On)$(echo $HOME/fvm/versions/*)} $HOME/development/flutter $HOME/flutter /opt/homebrew/share/flutter; do
  pick "$d"
done

echo "flutter not found: install it (see references/setup.md)" >&2
exit 1
