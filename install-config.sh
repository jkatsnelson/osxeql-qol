#!/usr/bin/env bash
# install-config.sh — place a good dxmt.conf + apply eqclient.ini tuning.
# Additive, reversible, re-runnable. Does NOT run wine.
#
# dxmt.conf must sit in the game dir (DXMT reads $PWD/dxmt.conf; the launcher
# cd's there). eqclient.ini only exists after the first clean logout.
#
# GRACEFUL DEGRADATION
#   * Game dir missing  -> stage dxmt.conf under qol/staged; install.sh copies it
#     into the game dir the moment the game appears (copy-on-present). No error.
#   * eqclient.ini missing -> the tuner prints a note and no-ops (exit 0).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/common.sh"
qol_init

hdr "dxmt.conf"
src="$HERE/dxmt.conf"
if game_present; then
  dst="$(game_dir)/dxmt.conf"
  backup_once "$dst"                       # if the user/game already had one
  cp "$src" "$dst"; record create "$dst"
  ok "installed $dst"
else
  cp "$src" "$QOL_STAGE/dxmt.conf"; record stage "$QOL_STAGE/dxmt.conf"
  warn "game dir absent — staged at $QOL_STAGE/dxmt.conf (will install when game appears)"
fi

hdr "eqclient.ini tuning"
if eqclient_present; then
  # tuner writes its own <ini>.qol-bak and is idempotent
  /usr/bin/python3 "$HERE/apply-eqclient-tuning.py" "$(eqclient_ini)" "$@"
  record tuned "$(eqclient_ini)"
else
  warn "eqclient.ini not created yet — launch EQ once, quit cleanly, then re-run install-config.sh (or ./install.sh)."
fi
