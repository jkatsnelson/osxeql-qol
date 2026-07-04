#!/usr/bin/env bash
# install-maps.sh — community maps (Brewall's / Good's) into the EQ maps/ folder.
# Classic EQ ships no in-game maps; these are a huge QoL win. Additive, reversible,
# re-runnable, and works before OR after the game is downloaded. Does NOT run wine.
#
# STRATEGY
#   1. Download a maps zip to qol/staged/maps/ (tens of MB — within budget).
#   2. If the game dir exists, ditto the staged maps into <game>/maps/ (merge,
#      never delete the client's own files). Otherwise leave them staged;
#      install.sh copies them in when the game appears (copy-on-present).
#
# SOURCE: overridable via env MAPS_URL. Defaults try a couple of known community
#   hosts; if all fail (offline / URL rot) we keep whatever is already staged and
#   exit with a clear message rather than a hard failure.
#
# CAVEAT (honest): these packs target modern/live EverQuest's full zone list.
#   EQ Legends is pre-Kunark; extra zone maps are harmless but unused, and a few
#   zone short-names could differ on the Legends build. In-game, point the map
#   window at this directory (Options/Map > map source). Untested against EQL's
#   exact zone set.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/common.sh"
qol_init

STAGE_MAPS="$QOL_STAGE/maps"
mkdir -p "$STAGE_MAPS"

# Candidate sources (Good's maps mirror + Brewall). Override with MAPS_URL=...
CANDIDATES=(
  "${MAPS_URL:-}"
  "https://www.eqmaps.info/wp-content/uploads/GoodsCurrentZips/MapsCurrent.zip"
  "https://raw.githubusercontent.com/adamjhensley/eq-maps/master/maps.zip"
)

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qol-maps.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
got=""
hdr "Fetching community maps"
for url in "${CANDIDATES[@]}"; do
  [ -n "$url" ] || continue
  log "  trying $url"
  if curl -fsSL --retry 2 -o "$TMP/maps.zip" "$url" 2>/dev/null; then got="$url"; break; fi
done

if [ -n "$got" ]; then
  # Extract only *.txt map files, flatten into STAGE_MAPS.
  /usr/bin/unzip -oqq "$TMP/maps.zip" -d "$TMP/x" || true
  n=0
  while IFS= read -r -d '' f; do cp "$f" "$STAGE_MAPS/"; n=$((n+1)); done \
    < <(/usr/bin/find "$TMP/x" -type f -name '*.txt' -print0)
  ok "staged $n map files from $got -> $STAGE_MAPS"
  record stage "$STAGE_MAPS"
else
  existing="$(/usr/bin/find "$STAGE_MAPS" -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${existing:-0}" -gt 0 ]; then
    warn "no source reachable; keeping $existing already-staged maps."
  else
    fail "no maps source reachable and nothing staged. Set MAPS_URL=<zip> and re-run."
    exit 1
  fi
fi

hdr "Installing into game dir (if present)"
if game_present; then
  dst="$(game_dir)/maps"; mkdir -p "$dst"
  # merge-copy; never delete client files. Track each file we add for uninstall.
  while IFS= read -r -d '' f; do
    b="$(basename "$f")"
    if [ ! -e "$dst/$b" ]; then cp "$f" "$dst/$b"; record create "$dst/$b"; fi
  done < <(/usr/bin/find "$STAGE_MAPS" -type f -name '*.txt' -print0)
  ok "maps installed -> $dst ($(/usr/bin/find "$dst" -name '*.txt' | wc -l | tr -d ' ') total)"
  log "  In-game: open the Map window and set its map-source directory to this folder."
else
  warn "game dir absent — maps staged only. They install automatically once you download the game and re-run ./install.sh."
fi
