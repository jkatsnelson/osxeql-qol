#!/usr/bin/env bash
# helpers/install-stealthpointer.sh — fix the macOS double-cursor in EQ.
#
# Under Wine the native macOS arrow draws on top of the in-game cursor. StealthPointer
# (a tiny free menubar app) hides the macOS pointer: F1 hide in-game, F2 restore.
# This is SEPARATE from the eqclient resolution/mouse-offset fix; you may want both.
#
# Additive + reversible: installs a normal .app to ~/Applications (no sudo, no
# osxEQL edit). Uninstall = quit it and delete the .app.
#
# HONEST: this only downloads the latest GitHub release if one exists. We cannot
# verify the exact asset name here, so if resolution fails we print the manual URL
# rather than guessing. Not run/verified by the repo author on this machine.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/lib/common.sh"

REPO="Alien4042x/StealthPointer"
DEST="$HOME/Applications"; mkdir -p "$DEST"

if [ -d "$DEST/StealthPointer.app" ] || [ -d /Applications/StealthPointer.app ]; then
  ok "StealthPointer already installed."; exit 0
fi

hdr "Fetching StealthPointer (latest release)"
# Resolve a .zip/.dmg asset from the latest release via the GitHub API (no auth).
url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | /usr/bin/python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for a in d.get("assets",[]):
    n=a["name"].lower()
    if n.endswith(".zip") or n.endswith(".dmg"): print(a["browser_download_url"]); break' || true)"

if [ -z "${url:-}" ]; then
  warn "Could not resolve a release asset automatically."
  log  "  Install manually: https://github.com/$REPO/releases  (drag StealthPointer.app to ~/Applications)"
  exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "  downloading $url"
curl -fsSL -o "$TMP/sp.asset" "$url"
case "$url" in
  *.zip) /usr/bin/ditto -x -k "$TMP/sp.asset" "$TMP/x"
         app="$(/usr/bin/find "$TMP/x" -maxdepth 2 -name 'StealthPointer.app' | head -1)"
         [ -n "$app" ] && /usr/bin/ditto "$app" "$DEST/StealthPointer.app" ;;
  *.dmg) mnt="$(hdiutil attach -nobrowse -quiet "$TMP/sp.asset" | awk 'END{print $NF}')"
         /usr/bin/ditto "$mnt/StealthPointer.app" "$DEST/StealthPointer.app" 2>/dev/null || true
         hdiutil detach -quiet "$mnt" ;;
esac

if [ -d "$DEST/StealthPointer.app" ]; then
  /usr/bin/xattr -dr com.apple.quarantine "$DEST/StealthPointer.app" 2>/dev/null || true
  ok "installed $DEST/StealthPointer.app  (launch it, then F1 hides the macOS cursor in-game, F2 restores)"
else
  warn "download ok but StealthPointer.app not found in the asset — install manually from https://github.com/$REPO/releases"
fi
