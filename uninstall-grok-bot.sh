#!/usr/bin/env bash
#
# Remove a grok-bot-arch install. Does not touch ks-grok-bot (the KVM guest).
#
set -euo pipefail

DEST="/opt/Grok Bot"
BIN="/usr/local/bin/grok-bot"
APPDIR="/usr/local/share/applications"
ICONROOT="/usr/local/share/icons/hicolor"

if [[ -t 1 ]]; then
  B=$'\e[1;34m'; G=$'\e[1;32m'; Z=$'\e[0m'
else
  B=''; G=''; Z=''
fi
h()  { printf '%s>>%s %s\n' "$B" "$Z" "$*"; }
ok() { printf '   %s%s%s\n' "$G" "$*" "$Z"; }

if pgrep -f '/opt/Grok Bot/grok-bot' >/dev/null 2>&1; then
  h "Stopping Grok Bot ..."
  pkill -f '/opt/Grok Bot/grok-bot' || true
  sleep 1
fi

h "Removing Grok Bot (needs sudo) ..."
sudo env DEST="$DEST" BIN="$BIN" APPDIR="$APPDIR" ICONROOT="$ICONROOT" bash -euc '
  rm -rf "$DEST"
  rm -f "$BIN" /usr/bin/grok-bot
  rm -f "$APPDIR/grok-bot.desktop"
  for sz in 16 24 32 48 64 128 256 512; do
    rm -f "$ICONROOT/${sz}x${sz}/apps/grok-bot.png"
  done
  rm -f /etc/apparmor.d/grok-bot
  update-desktop-database "$APPDIR" 2>/dev/null || true
  gtk-update-icon-cache -q "$ICONROOT" 2>/dev/null || true
'
ok "Grok Bot removed."
