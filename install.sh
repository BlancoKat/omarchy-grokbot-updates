#!/usr/bin/env bash
#
# Install Grok Bot updater + wire it into Omarchy menu > Update.
#
# After this runs:
#   Super + Space → Update → Grok Bot
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-grok-bot"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
EXT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions"
EXT_FILE="$EXT_DIR/omarchy-menu.jsonc"
MARKER_BEGIN="// --- omarchy-grok-bot-update begin ---"
MARKER_END="// --- omarchy-grok-bot-update end ---"

if [[ -t 1 ]]; then
  B=$'\e[1;34m'; G=$'\e[1;32m'; Y=$'\e[0;33m'; Z=$'\e[0m'
else
  B=''; G=''; Y=''; Z=''
fi
h()  { printf '%s>>%s %s\n' "$B" "$Z" "$*"; }
ok() { printf '   %s%s%s\n' "$G" "$*" "$Z"; }
warn(){ printf '   %s%s%s\n' "$Y" "$*" "$Z"; }

h "Installing updater scripts to $DATA_DIR ..."
mkdir -p "$DATA_DIR" "$BIN_DIR" "$EXT_DIR"
install -m0755 "$ROOT/update-grok-bot.sh" "$DATA_DIR/update-grok-bot.sh"
install -m0755 "$ROOT/uninstall-grok-bot.sh" "$DATA_DIR/uninstall-grok-bot.sh"
install -m0755 "$ROOT/bin/omarchy-update-grok-bot" "$DATA_DIR/omarchy-update-grok-bot"
# PATH shim so the menu action and terminals find the command.
ln -sfn "$DATA_DIR/omarchy-update-grok-bot" "$BIN_DIR/omarchy-update-grok-bot"
ln -sfn "$DATA_DIR/update-grok-bot.sh" "$BIN_DIR/update-grok-bot"
ok "Scripts installed"

# Rewrite the wrapper's default search path so it finds the share copy.
# (It already probes ~/.local/share/omarchy-grok-bot/.)

h "Wiring Update > Grok Bot into Omarchy menu ..."

FRAGMENT="$(cat <<'EOF'
  // --- omarchy-grok-bot-update begin ---
  "update.grok-bot": {
    "icon": "",
    "iconFont": "omarchy",
    "label": "Grok Bot",
    "description": "Update Grok Bot from Cursor's signed releases",
    "when": "omarchy-pkg-present grok-bot || [[ -x '/opt/Grok Bot/grok-bot' ]] || command -v grok-bot >/dev/null",
    "action": "omarchy-launch-floating-terminal-with-presentation omarchy-update-grok-bot"
  },
  // --- omarchy-grok-bot-update end ---
EOF
)"

python3 - "$EXT_FILE" "$FRAGMENT" "$MARKER_BEGIN" "$MARKER_END" <<'PY'
import pathlib, re, sys

ext_path = pathlib.Path(sys.argv[1])
fragment = sys.argv[2].rstrip() + "\n"
begin, end = sys.argv[3], sys.argv[4]

if ext_path.exists():
    text = ext_path.read_text(encoding="utf-8")
else:
    text = "{\n}\n"

# Drop a previous install of this block.
text = re.sub(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    "",
    text,
    flags=re.S,
)

# Ensure the file is a JSONC object we can splice into.
if "{" not in text:
    text = "{\n" + text.strip() + "\n}\n"

# Insert fragment immediately after the first opening brace.
m = re.search(r"\{", text)
if not m:
    text = "{\n" + fragment + "}\n"
else:
    text = text[: m.end()] + "\n" + fragment + text[m.end() :]

ext_path.parent.mkdir(parents=True, exist_ok=True)
ext_path.write_text(text, encoding="utf-8")
print(ext_path)
PY

ok "Menu extension updated: $EXT_FILE"

if command -v omarchy >/dev/null 2>&1; then
  h "Refreshing Omarchy menu ..."
  omarchy menu refresh 2>/dev/null || true
  ok "Menu refresh requested"
else
  warn "omarchy CLI not found here — on Omarchy the menu picks this up automatically"
  warn "(or run: omarchy menu refresh)"
fi

# Ensure ~/.local/bin is on PATH for the current session hint.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "Add $BIN_DIR to your PATH if 'omarchy-update-grok-bot' is not found" ;;
esac

echo ""
ok "Done."
echo ""
echo "  Open Omarchy menu (Super + Space) → Update → Grok Bot"
echo "  Or run:  omarchy-update-grok-bot"
echo ""
echo "  First run installs/updates the official app under /opt/Grok Bot."
echo "  If you previously used Install > AI > Grok Bot (pacman), the"
echo "  updater will migrate you to Cursor's signed builds."
echo ""
