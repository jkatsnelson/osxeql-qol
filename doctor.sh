#!/usr/bin/env bash
# doctor.sh — read-only health check for osxEQL + osxeql-qol.
#
# STATIC ONLY: it never launches wine/wineserver and never edits the app bundle.
# Prints PASS / WARN / FAIL for each check plus a summary. Safe to run repeatedly,
# before or after the ~7 GB game client is downloaded.
#
# Exit status: 0 unless a hard FAIL was found (then 1). WARNs never fail the run.
#
# Overridable via env: OSXEQL_APP, OSXEQL_HOME (see lib/common.sh).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/common.sh"

fails=0; warns=0

# Informational line — does NOT affect exit status or the WARN count.
note() { printf "  ${_c_b}info${_c_reset} %b\n" "$*"; }

# ---- 1. platform: Apple Silicon + macOS >= 13 ------------------------------
hdr "1. Platform (Apple Silicon + macOS 13+)"
arch="$(uname -m)"
osver="$(/usr/bin/sw_vers -productVersion 2>/dev/null || echo 0)"; osmaj="${osver%%.*}"
if [ "$arch" != "arm64" ]; then
  fail "CPU is '$arch', not arm64 — osxEQL requires Apple Silicon (M1+)"; fails=$((fails+1))
elif ! [ "${osmaj:-0}" -ge 13 ] 2>/dev/null; then
  fail "macOS $osver is older than 13.0 (app LSMinimumSystemVersion is 13.0)"; fails=$((fails+1))
else
  ok "Apple Silicon ($arch), macOS $osver"
fi

# ---- 2. Rosetta 2 (x86_64 translation) -------------------------------------
hdr "2. Rosetta 2"
# pgrep oahd is fast but oahd may be idle; the oah runtime dir is a static
# presence signal. Avoid running an x86_64 binary here — on a machine WITHOUT
# Rosetta that would pop the macOS install dialog, which a doctor must not do.
if rosetta_present || [ -d /Library/Apple/usr/libexec/oah ]; then
  ok "Rosetta 2 present (the x86_64 Wine + eqgame.exe require it)"
else
  warn "Rosetta 2 not detected — install: softwareupdate --install-rosetta --agree-to-license"; warns=$((warns+1))
fi

# ---- 3. app present + quarantine cleared -----------------------------------
hdr "3. osxEQL.app present + un-quarantined"
if ! app_present; then
  fail "osxEQL.app not found / not executable at $OSXEQL_APP"; fails=$((fails+1))
else
  # Gatekeeper blocks on the quarantine xattr. Check the bundle root plus the two
  # files macOS actually execs (launcher + wine loader): a zip-extracted app can
  # carry quarantine on inner files even when the root looks clean.
  q=""
  for f in "$OSXEQL_APP" "$OSXEQL_LAUNCHER" "$OSXEQL_WINE_DIR/bin/wine"; do
    [ -e "$f" ] || continue
    /usr/bin/xattr -p com.apple.quarantine "$f" >/dev/null 2>&1 && { q="$f"; break; }
  done
  if [ -n "$q" ]; then
    fail "com.apple.quarantine set ($q) — Gatekeeper will block launch. Fix once: xattr -dr com.apple.quarantine \"$OSXEQL_APP\""; fails=$((fails+1))
  else
    ok "app present, quarantine cleared"
  fi
fi

# ---- 4. Wine exports macdrv_functions (the #1 DXMT predictor) ---------------
hdr "4. DXMT Metal bridge (macdrv_functions)"
if wine_has_macdrv; then
  ok "winemac.so exports macdrv_functions — DXMT can attach a CAMetalLayer"
else
  fail "winemac.so lacks macdrv_functions — DXMT cannot render ('Failed to create metal view'). This Wine build is unusable."; fails=$((fails+1))
fi

# ---- 5. x86_64 freetype for the (x86_64) Wine ------------------------------
hdr "5. FreeType for x86_64 Wine (font rendering)"
if [ -f "$QOL_LIB/libfreetype.6.dylib" ]; then
  af="$(/usr/bin/file "$QOL_LIB/libfreetype.6.dylib" 2>/dev/null)"
  case "$af" in
    *x86_64*) ok "x86_64 freetype closure staged ($QOL_LIB/libfreetype.6.dylib)" ;;
    *) fail "staged freetype is NOT x86_64 — x86_64 Wine can't dlopen it: $af"; fails=$((fails+1)) ;;
  esac
else
  ftc="$(freetype_missing_count)"
  warn "no x86_64 freetype staged — Windows/dialog/launcher text may fall back (EQ's own texture fonts are unaffected). Run ./fix-fonts.sh${ftc:+ — last wineboot logged $ftc 'cannot find FreeType' complaint(s)}"; warns=$((warns+1))
fi

# ---- 6. Wine prefix present + LaunchPad staged -----------------------------
hdr "6. Wine prefix + LaunchPad staged"
if [ ! -f "$WINEPREFIX_DETECTED/system.reg" ]; then
  warn "no wine prefix yet at $WINEPREFIX_DETECTED — the app creates it (wineboot) on first launch"; warns=$((warns+1))
else
  boot_lp="$WINEPREFIX_DETECTED/drive_c/LaunchPad.exe"     # where EQLegends_setup.exe /S stages it
  inst_lp="$(game_dir)/LaunchPad.exe"                      # once the client is installed
  if [ -f "$inst_lp" ]; then
    ok "prefix present; LaunchPad installed in the game dir"
  elif [ -f "$boot_lp" ]; then
    ok "prefix present; bootstrap LaunchPad.exe staged at C:\\LaunchPad.exe"
  else
    warn "prefix present but no LaunchPad.exe (bootstrap or installed) — first run stages it from EQLegends_setup.exe"; warns=$((warns+1))
  fi
fi

# ---- 7. game client downloaded? (informational) ----------------------------
hdr "7. EverQuest Legends client"
gd="$(game_dir)"; eqgame="$gd/eqgame.exe"
if [ -f "$eqgame" ]; then
  ok "client installed (eqgame.exe present)"
else
  note "client not downloaded yet — expected until you log in via LaunchPad and let it download (~7 GB). QoL stages now + copies on-present."
fi

# ---- 8. community maps (Brewall/Good) --------------------------------------
hdr "8. Community maps"
gm="$gd/maps"; sm="$QOL_STAGE/maps"
if [ -d "$gm" ]; then
  ok "maps in game dir: $(/usr/bin/find "$gm" -type f 2>/dev/null | wc -l | tr -d ' ') file(s)"
elif [ -d "$sm" ]; then
  ok "maps staged (copy-on-present): $(/usr/bin/find "$sm" -type f 2>/dev/null | wc -l | tr -d ' ') file(s)"
else
  warn "no community maps — classic EQ has none in-game (big QoL win). Run ./install-maps.sh"; warns=$((warns+1))
fi

# ---- 9. stale winetemp loader dirs (silent-death bug) ----------------------
hdr "9. Runtime hazards (stale winetemp)"
st="$(stale_winetemp)"
if [ -n "$st" ]; then
  fail "stale winetemp with a DANGLING ntdll.so — silently kills launch ('nothing happens'). rm -rf:"; printf '        %s\n' $st; fails=$((fails+1))
else
  ok "no stale winetemp dirs (dangling ntdll.so symlinks)"
fi

# ---- 10. free disk vs the ~7 GB the client needs ---------------------------
hdr "10. Free disk space"
df_gib="$(disk_free_gib)"
if ! [ "${df_gib:-x}" -ge 0 ] 2>/dev/null; then
  warn "could not determine free disk space"; warns=$((warns+1))
elif [ -f "$eqgame" ]; then
  ok "disk free: ${df_gib} GiB (client already installed)"
elif [ "$df_gib" -lt 7 ]; then
  fail "disk free ${df_gib} GiB — below the ~7 GiB the client download needs"; fails=$((fails+1))
elif [ "$df_gib" -lt 12 ]; then
  warn "disk free ${df_gib} GiB — enough for the ~7 GiB client but tight (recommend >= 12 GiB)"; warns=$((warns+1))
else
  ok "disk free: ${df_gib} GiB — enough for the ~7 GiB client download"
fi

# ---- QoL extras (non-blocking, part of osxeql-qol) -------------------------
hdr "QoL extras"
if game_present; then
  [ -f "$gd/dxmt.conf" ] && ok "dxmt.conf present in game dir" || { warn "dxmt.conf not in game dir — run ./install-config.sh"; warns=$((warns+1)); }
else
  [ -f "$QOL_STAGE/dxmt.conf" ] && ok "dxmt.conf staged (copy-on-present)" || { warn "dxmt.conf not staged — run ./install-config.sh"; warns=$((warns+1)); }
fi
if [ -d /Applications/StealthPointer.app ] || [ -d "$HOME/Applications/StealthPointer.app" ]; then
  ok "StealthPointer installed (macOS double-cursor fix)"
else
  warn "StealthPointer not installed — ./helpers/install-stealthpointer.sh (fixes the macOS double cursor)"; warns=$((warns+1))
fi

# ---- summary ---------------------------------------------------------------
hdr "Summary"
if [ "$fails" -eq 0 ]; then
  ok "$fails FAIL, $warns WARN"
  [ "$warns" -eq 0 ] && ok "all clear" || note "no blockers; review WARN items for degraded/optional features"
else
  fail "$fails FAIL, $warns WARN — fix the FAIL items above before launching"
fi
[ "$fails" -eq 0 ]
