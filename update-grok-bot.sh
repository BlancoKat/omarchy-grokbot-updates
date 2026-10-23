#!/usr/bin/env bash
#
# update-grok-bot.sh
#
# Installs / updates official Grok Bot on Arch (or any distro without dpkg)
# from Cursor's GPG-signed apt repository.
#
# Trust chain:
#   embedded Anysphere key (fingerprint-pinned)
#     -> verifies InRelease
#       -> SHA256 of Packages
#         -> SHA256 of the .deb
#
# Then:
#   * extracts the .deb (ar + tar) into /opt/Grok Bot, root-owned
#   * sets chrome-sandbox mode the same way Debian postinst does
#   * installs a launcher WRAPPER (not a symlink) so Hyprland/sway keep
#     sign-in in gnome-libsecret instead of a plaintext file
#   * installs the .desktop entry and icons
#
# Re-run any time to upgrade. Idempotent. --force reinstalls the current build.
#
# Usage:
#   update-grok-bot.sh
#   update-grok-bot.sh --force
#   update-grok-bot.sh --deb /path/to/grok-bot_0.30.0_amd64.deb
#
set -euo pipefail

REPO="https://downloads.cursor.com/aptrepo"
SUITE="grok-bot"
DEST="/opt/Grok Bot"
BIN="/usr/local/bin/grok-bot"
APPDIR="/usr/local/share/applications"
ICONROOT="/usr/local/share/icons/hicolor"

# Anysphere Inc <security@anysphere.co>
# Same key Debian postinst writes to /usr/share/keyrings/grok-bot.gpg.
EXPECT_FPR="380FF4BCDC34A4BD92A3565342A1772E62E492D6"

FORCE=0
DEB_OVERRIDE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--force] [--deb FILE]

  --force     reinstall even if this version is already present
  --deb FILE  install FILE instead of downloading; SHA256 must still
              match the signed Packages index
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --deb)
      [[ $# -ge 2 ]] || usage
      DEB_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

case "$(uname -m)" in
  x86_64)        ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 1; }; }
need curl; need ar; need tar; need sha256sum; need gpg; need awk; need unshare

if [[ -t 1 ]]; then
  B=$'\e[1;34m'; G=$'\e[1;32m'; Y=$'\e[0;33m'; R=$'\e[1;31m'; Z=$'\e[0m'
else
  B=''; G=''; Y=''; R=''; Z=''
fi
h()   { printf '%s>>%s %s\n' "$B" "$Z" "$*"; }
ok()  { printf '   %s%s%s\n' "$G" "$*" "$Z"; }
die() { printf '%sFATAL:%s %s\n' "$R" "$Z" "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- embedded Anysphere signing key ----------------------------------------
cat > "$TMP/anysphere.asc" <<'ANYSPHERE_KEY_EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGhv/tgBEAC24VCTfKi5NSVaUAuSaIERf2EC5PCyOQz7WOh/UwyuG/1RB2r8
/SYtipV+fD2b+xdu7WGPqrSHrKNNO1A9j6TtqbLVDDweJU2keHOqfIaamxrcyfCw
3LMF9elIsmdkbZBukezWM32YBrG5MOwfCmG782sN79jYIPYckGZehh8Q6uIlZAzM
TR7Qr6mlRR9cRZOF1gY1hRVCXQc1P3SH+ncX1abo/w3idRjxW3l0tqzjLcovWXD1
xQdgt5odrpHlUkXRxxr7ukkPu2yJ2tL0KJydLtRDFf7k6ipYoCQv6hrFziHBHqfA
EAMymr4YH96GhlbeP/zTSeUn8Y9Blz18q8sJJ2AKoAwpxWTYDIk7D3GDxHQYkcWI
uh3MNJd3nulrptCOXgLBPqAF9/N1PW6UyX2XZmcFf0MQYC++IO0FwgcRw968L4Lv
gIGJdSCA5umcadDPoCQNcdobTur0WtzrsZ8letGoZ18FAhfeWfMWfljHDPbG0LSI
mKthaiAwXggi76sQyo374azY/ZfjepxRG3U7iEcesopqeo9p8l/8R7aZEk3zUbVt
45yhp7XN8YtDrFvAPZfcIuoQTkeDZEub9Cch+fbeqdNk+LAyUbVzX/cFWBvRWC4a
jsI/rD4IgeZInV39uG5ngpiwdb755xmZFiZSD1riGUYFYMfFfI1d80EOtQARAQAB
tCVBbnlzcGhlcmUgSW5jIDxzZWN1cml0eUBhbnlzcGhlcmUuY28+iQJRBBMBCAA7
FiEEOA/0vNw0pL2So1ZTQqF3LmLkktYFAmhv/tgCGwMFCwkIBwICIgIGFQoJCAsC
BBYCAwECHgcCF4AACgkQQqF3LmLkktZXUw//fAEm1Vo8uQ1E/4lNToEPM24olQp6
If49+HSwFLCB5HhsGFmed6Zx1L+iNDJ8eW8niuepIqSRTX8G/+0z487hP29moLTE
85g/YNsgWfkptbps3vgxlStotfgXZIKI71/m7FItBiA/tMS2ZkL1UwCSUQWE1YJg
YJ8Gm4IbvoqYNwHv+8i0wJi3/G6lphHMxQp6XuO4HVlIk0dteQPaeszFK7jf74ud
RVTpxu+ffM0x/NFw08qYPsmBQJ9Of4/dhRfAYI9ZQOAFnIhujykOs7QBnq49JlzF
3pYG/ZnvXwpUzRQgga+ro+5bXoQ1DZrNH+zl4EXtiXKpowUoYOZpDSELRVPGUW4v
syi+n34M5jMnxglYQJGB/ZTW95al7c84WZANripx2szeIxKukDcln7y0Qd7jpfGI
C7xAjTzwVK8JzsDPisP9KPfua/zifr972QMK/4xlwjRRS6yRyM7Z2QZVdtzpUdPs
VgbnXJkb6IBQSJDXKN7LQeB5Wi+4Cg9hddAG6sPu5wIcig67qFN/GEaeu6P4SuQq
gBhmtf0x26Y0MDBbJtQ4adHSr90F8Fn8si6/Hb5xjSSOTg9QsPbAbBpmXjblLLRm
dhUt0JCbIrBn2+jPKL+bT7aLkXiyI/k6kNC3AbI+YYwYgIDqSpqNHbdu+t9IOHK0
33IS4qoybKtiKbY=
=s2ww
-----END PGP PUBLIC KEY BLOCK-----
ANYSPHERE_KEY_EOF

export GNUPGHOME="$TMP/gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
gpg --quiet --import "$TMP/anysphere.asc" 2>/dev/null
GOT_FPR="$(gpg --with-colons --fingerprint 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
if [[ "$GOT_FPR" != "$EXPECT_FPR" ]]; then
  echo "FATAL: embedded key fingerprint mismatch." >&2
  echo "  got:      $GOT_FPR" >&2
  echo "  expected: $EXPECT_FPR" >&2
  exit 1
fi

h "Verifying repository signature ..."
curl -fsSL "$REPO/dists/$SUITE/InRelease" -o "$TMP/InRelease"
if ! gpg --batch --status-fd 3 --decrypt "$TMP/InRelease" \
        3>"$TMP/gpgstatus" >"$TMP/Release" 2>/dev/null \
   || ! grep -q '^\[GNUPG:\] VALIDSIG' "$TMP/gpgstatus"; then
  die "InRelease signature did not verify against Anysphere's key."
fi
ok "InRelease signature OK"

PKG_PATH="main/binary-$ARCH/Packages"
read -r PKG_SHA PKG_SIZE < <(
  awk -v p="$PKG_PATH" '$3==p && length($1)==64 {print $1, $2; exit}' "$TMP/Release"
) || true
[[ -n "${PKG_SHA:-}" ]] || die "$PKG_PATH not found in signed Release."

h "Fetching + verifying package index ..."
curl -fsSL "$REPO/dists/$SUITE/$PKG_PATH" -o "$TMP/Packages"
echo "$PKG_SHA  $TMP/Packages" | sha256sum -c - >/dev/null \
  || die "Packages index hash does not match signed Release."
ok "Packages index authenticated"

# Parse every grok-bot stanza so --deb can match an older published build.
mapfile -t PKG_ROWS < <(
  awk -v RS='' '
    { ver=""; fn=""; sha=""
      n=split($0, L, "\n")
      for (i=1;i<=n;i++) {
        if (L[i] ~ /^Version: /)  { ver=L[i]; sub(/^Version: /,"",ver) }
        if (L[i] ~ /^Filename: /) { fn=L[i];  sub(/^Filename: /,"",fn) }
        if (L[i] ~ /^SHA256: /)   { sha=L[i]; sub(/^SHA256: /,"",sha) }
      }
      if (ver!="" && fn!="" && sha!="") print ver "\t" fn "\t" sha
    }' "$TMP/Packages"
)
[[ ${#PKG_ROWS[@]} -gt 0 ]] || die "could not parse grok-bot from index."

LATEST_ROW="$(printf '%s\n' "${PKG_ROWS[@]}" | sort -V | tail -n1)"
IFS=$'\t' read -r VERSION FILENAME SHA256 <<<"$LATEST_ROW"

if [[ -n "$DEB_OVERRIDE" ]]; then
  [[ -f "$DEB_OVERRIDE" ]] || die "deb not found: $DEB_OVERRIDE"
  LOCAL_SHA="$(sha256sum "$DEB_OVERRIDE" | awk '{print $1}')"
  MATCH=""
  for row in "${PKG_ROWS[@]}"; do
    IFS=$'\t' read -r v f s <<<"$row"
    if [[ "$s" == "$LOCAL_SHA" ]]; then
      MATCH="$row"
      VERSION="$v"
      FILENAME="$f"
      SHA256="$s"
      break
    fi
  done
  [[ -n "$MATCH" ]] || die "local deb SHA256 is not in the signed Packages index."
fi

[[ "$VERSION"  =~ ^[0-9][0-9A-Za-z.+~]*(-[0-9A-Za-z.+~]+)?$ ]] || die "refusing suspicious version '$VERSION'."
[[ "$SHA256"   =~ ^[0-9a-f]{64}$ ]]                 || die "refusing suspicious sha256."
[[ "$FILENAME" =~ ^pool/[A-Za-z0-9._/+-]+\.deb$ ]]  || die "refusing suspicious filename '$FILENAME'."

h "Latest available: ${Y}${VERSION}${Z}"
STAMP="$DEST/.app-version"
INSTALLED="$(cat "$STAMP" 2>/dev/null || echo none)"
h "Currently installed: ${Y}${INSTALLED}${Z}"
if [[ "$INSTALLED" == "$VERSION" && $FORCE -eq 0 ]]; then
  ok "Already up to date. Use --force to reinstall."
  exit 0
fi

DEB="$TMP/$(basename "$FILENAME")"
if [[ -n "$DEB_OVERRIDE" ]]; then
  h "Using local $(basename "$DEB_OVERRIDE") ..."
  cp -a "$DEB_OVERRIDE" "$DEB"
else
  CANDIDATES=(
    "$HOME/Downloads/$(basename "$FILENAME")"
    "$PWD/$(basename "$FILENAME")"
  )
  USED_LOCAL=""
  for c in "${CANDIDATES[@]}"; do
    if [[ -f "$c" ]]; then
      got="$(sha256sum "$c" | awk '{print $1}')"
      if [[ "$got" == "$SHA256" ]]; then
        h "Using already-downloaded $(basename "$c") ..."
        cp -a "$c" "$DEB"
        USED_LOCAL=1
        break
      fi
    fi
  done
  if [[ -z "$USED_LOCAL" ]]; then
    h "Downloading $(basename "$FILENAME") ..."
    curl -fSL -# -o "$DEB" "$REPO/$FILENAME"
  fi
fi

h "Verifying .deb SHA256 (chained to signed Release) ..."
echo "$SHA256  $DEB" | sha256sum -c - >/dev/null
ok "OK"

h "Extracting ..."
( cd "$TMP" && ar x "$DEB" && tar -xf data.tar.* )

[[ -x "$TMP/opt/Grok Bot/grok-bot" ]] || die "extracted tree is missing grok-bot."

if pgrep -f '/opt/Grok Bot/grok-bot' >/dev/null 2>&1; then
  h "Stopping running Grok Bot ..."
  pkill -f '/opt/Grok Bot/grok-bot' || true
  sleep 1
fi

# Debian postinst: SUID chrome-sandbox only when user namespaces are missing.
# The install path has a space, so Chromium cannot fall back to SUID sandbox
# anyway. Keep userns when it works.
SANDBOX_MODE=0755
if ! { [[ -L /proc/self/ns/user ]] && unshare --user true; }; then
  SANDBOX_MODE=4755
fi

h "Installing to $DEST (needs sudo) ..."
sudo env \
  DEST="$DEST" \
  SRC="$TMP" \
  VERSION="$VERSION" \
  BIN="$BIN" \
  APPDIR="$APPDIR" \
  ICONROOT="$ICONROOT" \
  SANDBOX_MODE="$SANDBOX_MODE" \
  bash -euc '
  rm -rf "$DEST"
  mkdir -p "$DEST"
  cp -a "$SRC/opt/Grok Bot/." "$DEST/"
  chown -R root:root "$DEST"
  chmod "$SANDBOX_MODE" "$DEST/chrome-sandbox"
  printf "%s\n" "$VERSION" > "$DEST/.app-version"

  rm -f "$BIN"
  cat > "$BIN" <<EOF
#!/bin/sh
# Hyprland / sway / COSMIC: persist sign-in in the encrypted keyring.
export ELECTRON_OZONE_PLATFORM_HINT="\${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
exec "$DEST/grok-bot" --password-store=gnome-libsecret "\$@"
EOF
  chmod 0755 "$BIN"

  mkdir -p "$APPDIR"
  if [[ -f "$SRC/usr/share/applications/grok-bot.desktop" ]]; then
    sed "s|^Exec=.*|Exec=$BIN %U|" \
      "$SRC/usr/share/applications/grok-bot.desktop" > "$APPDIR/grok-bot.desktop"
  fi

  for sz in 16 24 32 48 64 128 256 512; do
    src="$SRC/usr/share/icons/hicolor/${sz}x${sz}/apps/grok-bot.png"
    if [[ -f "$src" ]]; then
      install -Dm644 "$src" "$ICONROOT/${sz}x${sz}/apps/grok-bot.png"
    fi
  done

  update-desktop-database "$APPDIR" 2>/dev/null || true
  gtk-update-icon-cache -q "$ICONROOT" 2>/dev/null || true
'

SB="$(stat -c '%A %U:%G' "$DEST/chrome-sandbox")"
h "chrome-sandbox: $SB  (mode $SANDBOX_MODE)"
ok "Installed Grok Bot ${VERSION}"
h "Launch with: ${Y}grok-bot${Z}  or the Grok Bot app menu entry"
