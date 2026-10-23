#!/usr/bin/env bash
# Smoke-test install/uninstall menu merge without touching a real Omarchy box.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_BIN_HOME="$HOME/.local/bin"
mkdir -p "$XDG_CONFIG_HOME/omarchy/extensions"

EXT="$XDG_CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc"
cat > "$EXT" <<'EOF'
{
  // sample
  "personal": {"icon":"x","label":"Personal"},
}
EOF

"$ROOT/install.sh" >/dev/null
grep -q 'update.grok-bot' "$EXT"
test -x "$XDG_BIN_HOME/omarchy-update-grok-bot"
"$ROOT/install.sh" >/dev/null
count="$(grep -c 'omarchy-grok-bot-update begin' "$EXT" || true)"
[[ "$count" == "1" ]]

"$ROOT/uninstall-menu.sh" >/dev/null
if grep -q 'update.grok-bot' "$EXT"; then
  echo "leftover update.grok-bot menu entry in $EXT" >&2
  exit 1
fi
grep -q '"personal"' "$EXT"
[[ ! -e "$XDG_DATA_HOME/omarchy-grok-bot" ]]

echo "smoke-test OK"
