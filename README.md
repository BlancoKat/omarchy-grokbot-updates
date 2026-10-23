# Grok Bot → Omarchy Update menu

Omarchy can **install** Grok Bot under Install → AI, but there is no **Update → Grok Bot** row. System updates via Update → Omarchy only move as fast as the Omarchy package mirror, so newer Cursor builds can sit unreleased there while the signed apt channel already has them.

This repo adds the missing Update menu entry and keeps Grok Bot current from Cursor's GPG-signed apt repository.

## What you get

| Piece | Role |
|---|---|
| **Update → Grok Bot** | New Omarchy menu row (`Super + Space`) |
| `omarchy-update-grok-bot` | Same action from a terminal |
| `update-grok-bot` | Direct updater (idempotent; `--force` reinstalls) |

After install, Grok Bot lives under `/opt/Grok Bot` with a Hyprland-friendly launcher at `/usr/local/bin/grok-bot`.

## Install (on Omarchy)

```sh
git clone https://github.com/BlancoKat/omarchy-grokbot-updates.git
cd omarchy-grokbot-updates
./install.sh
```

Then open **Omarchy menu → Update → Grok Bot**.

If Grok Bot was installed earlier via **Install → AI** (pacman package `grok-bot`), the first Update run migrates you to Cursor's signed `/opt` build so the new menu entry can keep tracking releases.

## Update

```sh
# From the menu:
#   Super + Space → Update → Grok Bot

# Or:
omarchy-update-grok-bot
update-grok-bot          # same updater
update-grok-bot --force  # reinstall current
```

## Uninstall

Menu wiring only (leaves the app installed):

```sh
./uninstall-menu.sh
```

App itself:

```sh
./uninstall-grok-bot.sh
```

## Trust

Fingerprint of the Anysphere key the Debian package ships:

```
380F F4BC DC34 A4BD 92A3  5653 42A1 772E 62E4 92D6
Anysphere Inc <security@anysphere.co>
```

Every update checks InRelease against that key, then the Packages SHA256, then the `.deb` SHA256.

## Requirements

Omarchy (Arch) x86_64. Needs `curl`, `ar`, `tar`, `gpg`, `sha256sum`, sudo, and the usual GTK/NSS stack (`gtk3`, `nss`, `libsecret`, `gnome-keyring`, `libnotify`, `libxss`, `alsa-lib`, `mesa`).

## Disclaimer

Unofficial Omarchy menu extension. Grok Bot is Cursor / xAI's. These scripts unpack their signed package and expose Update → Grok Bot in the Omarchy menu.
