#!/usr/bin/env bash
# lib/common.sh — shared paths, EQ-dir detection, logging, and helpers for
# osxeql-qol. Source this; never execute it. All functions are read-only w.r.t.
# the osxEQL app bundle. Nothing here runs wine.
#
#   . "$(dirname "$0")/lib/common.sh"
#
# Design invariants (verified against osxEQL v0.2.0 launcher on 2026-07-03):
#   - The app bundle is at /Applications/osxEQL.app and must NOT be edited here.
#   - Runtime data lives at "$OSXEQL_HOME" (~/Library/Application Support/osxEQL).
#   - The active prefix is $OSXEQL_HOME/prefix, with a back-compat fallback to
#     prefix-cx *exactly* as the launcher chooses it.
#   - The game dir may NOT exist yet (game not downloaded). Every consumer must
#     tolerate that; helpers below return non-zero + empty rather than crashing.

set -u

# ---- constants -------------------------------------------------------------
OSXEQL_APP="${OSXEQL_APP:-/Applications/osxEQL.app}"
OSXEQL_WINE_DIR="$OSXEQL_APP/Contents/Resources/Wine"
OSXEQL_LAUNCHER="$OSXEQL_APP/Contents/MacOS/osxEQL"
OSXEQL_HOME="${OSXEQL_HOME:-$HOME/Library/Application Support/osxEQL}"

# Our own state, entirely under OSXEQL_HOME so it's additive + easy to purge.
QOL_HOME="$OSXEQL_HOME/qol"
QOL_LIB="$QOL_HOME/lib"                 # staged x86_64 freetype closure
QOL_STAGE="$QOL_HOME/staged"            # copy-on-present source for game-dir files
QOL_MANIFEST="$QOL_HOME/manifest.tsv"   # <action>\t<path>  — drives uninstall
QOL_LOG="$QOL_HOME/qol.log"

# Backup suffix distinct from the launcher's own ".osxeql-bak" so we never clash.
QOL_BAK=".qol-bak"

# ---- prefix + game-dir detection (mirrors launcher.sh precisely) -----------
detect_prefix() {
  # Echoes the active WINEPREFIX. Same rule the launcher uses.
  local p="$OSXEQL_HOME/prefix"
  if [ ! -f "$p/system.reg" ] && [ -f "$OSXEQL_HOME/prefix-cx/system.reg" ]; then
    p="$OSXEQL_HOME/prefix-cx"
  fi
  printf '%s\n' "$p"
}

WINEPREFIX_DETECTED="$(detect_prefix)"

game_dir() {
  # Echoes the EverQuest Legends install dir. ALWAYS echoes the canonical path
  # (so callers can stage toward it) but returns 1 if it does not exist yet.
  local g="$WINEPREFIX_DETECTED/drive_c/users/Public/Daybreak Game Company/Installed Games/EverQuest Legends"
  printf '%s\n' "$g"
  [ -d "$g" ]
}

game_present() { game_dir >/dev/null; }                 # true iff game dir exists
eqclient_ini() { printf '%s/eqclient.ini\n' "$(game_dir)"; }
eqclient_present() { [ -f "$(eqclient_ini)" ]; }        # only exists after 1st run

# ---- environment probes (all read-only, no wine) ---------------------------
rosetta_present() { /usr/bin/pgrep -q oahd; }
app_present() { [ -x "$OSXEQL_LAUNCHER" ]; }
app_quarantined() { /usr/bin/xattr -p com.apple.quarantine "$OSXEQL_APP" >/dev/null 2>&1; }

wine_has_macdrv() {
  # The single most important runtime invariant: DXMT needs this symbol.
  /usr/bin/nm -gU "$OSXEQL_WINE_DIR/lib/wine/x86_64-unix/winemac.so" 2>/dev/null \
    | /usr/bin/grep -q macdrv_functions
}

freetype_missing_count() {
  # Count of "Wine cannot find the FreeType" complaints in the most recent
  # wineboot log. Read-only; does NOT run wine. Echoes an integer (0 if no log).
  local log="$OSXEQL_HOME/logs/wineboot.log"
  [ -f "$log" ] || { echo 0; return; }
  /usr/bin/grep -c -i 'cannot find the FreeType' "$log" 2>/dev/null || echo 0
}

stale_winetemp() {
  # Echoes any $TMPDIR/winetemp-* dirs whose ntdll.so symlink dangles (the
  # "app does nothing on click" bug). Read-only.
  local d
  for d in "${TMPDIR:-/tmp}"/winetemp-*; do
    [ -L "$d/ntdll.so" ] && [ ! -e "$d/ntdll.so" ] && printf '%s\n' "$d"
  done
}

disk_free_gib() { df -g / 2>/dev/null | awk 'NR==2{print $4}'; }

# ---- manifest / backup helpers (make everything reversible) ----------------
qol_init() { mkdir -p "$QOL_HOME" "$QOL_LIB" "$QOL_STAGE"; : >>"$QOL_MANIFEST"; }

record() {                                                     # action, path (deduped)
  local line; line="$(printf '%s\t%s' "$1" "$2")"
  [ -f "$QOL_MANIFEST" ] && /usr/bin/grep -qxF "$line" "$QOL_MANIFEST" 2>/dev/null && return 0
  printf '%s\n' "$line" >>"$QOL_MANIFEST"
}

backup_once() {
  # Copy $1 -> $1$QOL_BAK the first time only; record it for uninstall.
  local f="$1"
  [ -f "$f" ] || return 0
  if [ ! -f "$f$QOL_BAK" ]; then
    cp -p "$f" "$f$QOL_BAK" && record backup "$f"
  fi
}

# ---- logging ---------------------------------------------------------------
_c_reset='\033[0m'; _c_g='\033[32m'; _c_y='\033[33m'; _c_r='\033[31m'; _c_b='\033[1m'
log()  { printf "%b\n" "$*" | tee -a "$QOL_LOG" >&2; }
ok()   { printf "  ${_c_g}ok${_c_reset}   %b\n" "$*"; }
warn() { printf "  ${_c_y}warn${_c_reset} %b\n" "$*"; }
fail() { printf "  ${_c_r}FAIL${_c_reset} %b\n" "$*"; }
hdr()  { printf "\n${_c_b}%b${_c_reset}\n" "$*"; }
