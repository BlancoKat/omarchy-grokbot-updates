#!/usr/bin/env bash
#
# Remove the Omarchy Update > Grok Bot menu wiring and local updater scripts.
# Does NOT uninstall Grok Bot itself — use uninstall-grok-bot.sh for that.
#
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-grok-bot"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
EXT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
MARKER_BEGIN="// --- omarchy-grok-bot-update begin ---"
MARKER_END="// --- omarchy-grok-bot-update end ---"

if [[ -t 1 ]]; then
  B=$'\e[1;34m'; G=$'\e[1;32m'; Z=$'\e[0m'
else
  B=''; G=''; Z=''
fi
h()  { printf '%s>>%s %s\n' "$B" "$Z" "$*"; }
ok() { printf '   %s%s%s\n' "$G" "$*" "$Z"; }

h "Removing menu extension block ..."
if [[ -f "$EXT_FILE" ]]; then
  python3 - "$EXT_FILE" "$MARKER_BEGIN" "$MARKER_END" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
begin, end = sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")
text2 = re.sub(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    "",
    text,
    flags=re.S,
)
path.write_text(text2, encoding="utf-8")
PY
  ok "Removed from $EXT_FILE"
else
  ok "No extension file present"
fi

h "Removing scripts ..."
rm -f "$BIN_DIR/omarchy-update-grok-bot" "$BIN_DIR/update-grok-bot"
rm -rf "$DATA_DIR"
ok "Scripts removed"

if command -v omarchy >/dev/null 2>&1; then
  omarchy menu refresh 2>/dev/null || true
fi

ok "Update > Grok Bot menu entry removed."
echo "Grok Bot app (if installed) is untouched. To remove it:"
echo "  $(dirname "$0")/uninstall-grok-bot.sh"
