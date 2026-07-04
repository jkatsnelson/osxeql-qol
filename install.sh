#!/usr/bin/env bash
# install.sh — osxeql-qol orchestrator. Idempotent, additive, re-runnable.
#
# Runs the QoL components in a sensible order, then does a "copy-on-present" pass
# that installs anything previously staged (dxmt.conf, maps, skins) into the game
# dir the moment the game exists. Safe to run repeatedly — run it again after you
# download the game, or after any clean logout, to reconcile.
#
# Only fix-fonts runs wine (one-shot wineboot self-check). Everything else is
# file-only. Nothing here edits or re-signs /Applications/osxEQL.app.
#
# USAGE
#   ./install.sh                 # fonts + config + maps + copy-on-present
#   ./install.sh fonts config    # only the named components
#   ./install.sh --all           # above + StealthPointer
#   ./install.sh --skip-fonts    # everything except fonts (no wine at all)
#   Components: fonts config maps stealthpointer
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/common.sh"
qol_init

DEFAULT=(fonts config maps)
want=(); skip=(); all=0
for a in "$@"; do
  case "$a" in
    --all) all=1 ;;
    --skip-*) skip+=("${a#--skip-}") ;;
    fonts|config|maps|stealthpointer) want+=("$a") ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
[ ${#want[@]} -gt 0 ] || want=("${DEFAULT[@]}")
[ "$all" -eq 1 ] && want=(fonts config maps stealthpointer)
# bash 3.2 (macOS default) errors on "${empty[@]}" under set -u; guard both arrays.
run() {
  local s w
  for s in ${skip[@]+"${skip[@]}"}; do [ "$s" = "$1" ] && return 1; done
  for w in ${want[@]+"${want[@]}"}; do [ "$w" = "$1" ] && return 0; done
  return 1
}

log "osxeql-qol installer — game present: $(game_present && echo yes || echo 'no (staging)')"

run fonts          && { hdr "== runtime libs (vulkan + fonts) =="; bash "$HERE/fix-runtime-libs.sh" || warn "fix-runtime-libs reported an issue (see above)"; }
run config         && { hdr "== config =="         ; bash "$HERE/install-config.sh"; }
run maps           && { hdr "== maps =="           ; bash "$HERE/install-maps.sh" || warn "maps: no source reachable"; }
run stealthpointer && { hdr "== stealthpointer ==" ; bash "$HERE/helpers/install-stealthpointer.sh"; }

# ---- copy-on-present reconcile: staged -> game dir -------------------------
hdr "== reconcile (copy-on-present) =="
if game_present; then
  g="$(game_dir)"
  if [ -f "$QOL_STAGE/dxmt.conf" ] && [ ! -f "$g/dxmt.conf" ]; then
    cp "$QOL_STAGE/dxmt.conf" "$g/dxmt.conf"; record create "$g/dxmt.conf"; ok "dxmt.conf -> game dir"
  fi
  if [ -d "$QOL_STAGE/maps" ]; then
    mkdir -p "$g/maps"; n=0
    while IFS= read -r -d '' f; do b="$(basename "$f")"; [ -e "$g/maps/$b" ] || { cp "$f" "$g/maps/$b"; record create "$g/maps/$b"; n=$((n+1)); }; done \
      < <(/usr/bin/find "$QOL_STAGE/maps" -type f -name '*.txt' -print0)
    [ "$n" -gt 0 ] && ok "maps -> game dir (+$n)" || ok "maps already in game dir"
  fi
  if [ -d "$QOL_STAGE/uifiles" ]; then
    while IFS= read -r -d '' d; do b="$(basename "$d")"; [ -e "$g/uifiles/$b" ] || { mkdir -p "$g/uifiles"; /usr/bin/ditto "$d" "$g/uifiles/$b"; record create "$g/uifiles/$b"; ok "skin $b -> game dir"; }; done \
      < <(/usr/bin/find "$QOL_STAGE/uifiles" -maxdepth 1 -mindepth 1 -type d -print0)
  fi
  # eqclient tuning (now that a login may have generated the ini)
  eqclient_present && /usr/bin/python3 "$HERE/apply-eqclient-tuning.py" "$(eqclient_ini)" >/dev/null || true
else
  warn "game not downloaded yet — everything is staged under $QOL_STAGE."
  warn "Log in via osxEQL, download the game, quit cleanly, then re-run: ./install.sh"
fi

hdr "Done. Health check:"
bash "$HERE/doctor.sh" || true
