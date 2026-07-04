#!/usr/bin/env bash
# helpers/install-ui-skin.sh — stage a large-screen custom UI skin into uifiles/.
#
# EQ's built-in UI-scale slider only scales newly-converted windows; most legacy
# XML UI is hardcoded, so on a big display a custom skin (e.g. from eqinterface.com)
# is the real fix. This helper just drops a skin folder into the client's uifiles/
# so you can `/loadskin <name> 1` in-game. Additive + reversible.
#
# Because skins are a taste/licensing choice, this does NOT bundle one. Point it at
# a downloaded skin zip or an already-unzipped skin folder.
#
# GRACEFUL DEGRADATION: if the game dir is absent, the skin is staged under
# qol/staged/uifiles/<name> and copied in when the game appears.
#
# USAGE
#   install-ui-skin.sh <skin.zip | skin-folder> [skin-name]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/lib/common.sh"
qol_init

src="${1:-}"
[ -n "$src" ] || { echo "usage: install-ui-skin.sh <skin.zip|skin-folder> [name]"; exit 2; }
name="${2:-}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -f "$src" ]; then
  /usr/bin/unzip -oqq "$src" -d "$TMP/x"
  skindir="$(/usr/bin/find "$TMP/x" -maxdepth 2 -name 'EQUI.xml' -exec dirname {} \; | head -1)"
elif [ -d "$src" ]; then
  skindir="$src"
else
  fail "no such file/dir: $src"; exit 1
fi
[ -n "${skindir:-}" ] && [ -d "$skindir" ] || { fail "couldn't locate a skin (no EQUI.xml found)"; exit 1; }
[ -n "$name" ] || name="$(basename "$skindir")"

stage="$QOL_STAGE/uifiles/$name"; mkdir -p "$(dirname "$stage")"
/usr/bin/ditto "$skindir" "$stage"; record stage "$stage"
ok "skin staged: $stage"

if game_present; then
  dst="$(game_dir)/uifiles/$name"
  if [ -e "$dst" ]; then warn "skin '$name' already in uifiles/ — leaving it (uninstall to replace)"; else
    /usr/bin/ditto "$stage" "$dst"; record create "$dst"
    ok "installed -> $dst"
    log "  In-game, run:  /loadskin $name 1"
  fi
else
  warn "game dir absent — skin staged; re-run ./install.sh after downloading the game."
fi
