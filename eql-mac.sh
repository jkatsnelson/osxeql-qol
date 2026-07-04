#!/usr/bin/env bash
# eql-mac.sh — the one-command path to EverQuest Legends on Apple Silicon,
# free & native (open-source Wine + DXMT/Metal, no CrossOver).
#
# This automates the full, VERIFIED recipe for a FRESH install — including the
# fixes that osxEQL v0.2.0 alone doesn't do, which is why a clean install of it
# can't currently download/play. Verified end-to-end on macOS 26.4 / Apple
# Silicon: fresh install -> login -> 6.9 GB download -> in-game
# (dbg.txt: "CRender::InitDevice completed successfully").
#
# WHAT VANILLA osxEQL IS MISSING (all handled here):
#   1. libvulkan.1.dylib (MoltenVK) + x86_64 libfreetype  — the CEF launcher
#      needs Vulkan; Wine needs an x86_64 FreeType. Neither is bundled.
#   2. rpcss isn't auto-started -> RPC_S_SERVER_UNAVAILABLE.
#   3. THE BIG ONE: the first-run "LaunchPad.exe" is a bootstrapper that loads
#      Daybreak's npdg download plugin, which CRASHES under Wine. But it first
#      downloads the REAL CEF launcher into a MANGLED path — a literal folder
#      named "C:" under Installed Games (a Wine path bug). We rename that to the
#      real game dir and run the REAL launcher directly, skipping the crash.
#
# USAGE
#   ./eql-mac.sh setup ~/Downloads/EQLegends_setup.exe   # libs + install + launch to login
#   ./eql-mac.sh launch                                   # (re)launch the real launcher to log in / patch
#   ./eql-mac.sh play                                     # launch the game (eqgame) once it's installed
#   ./eql-mac.sh doctor                                   # health check
#
# After `setup`, log in in the launcher window and hit Play. That's it.
set -uo pipefail

APP="${OSXEQL_APP:-/Applications/osxEQL.app}"
WD="$APP/Contents/Resources/Wine"
OH="$HOME/Library/Application Support/osxEQL"
PREFIX="$OH/prefix"
IGAMES="$PREFIX/drive_c/users/Public/Daybreak Game Company/Installed Games"
GAME="$IGAMES/EverQuest Legends"
DESKTOP="osxEQL,1280x960"
HERE="$(cd "$(dirname "$0")" && pwd)"

die(){ echo "ERROR: $*" >&2; exit 1; }
[ -d "$WD" ] || die "osxEQL not found at $APP (install the DMG first, then clear quarantine)."

wine_env(){
  export WINEPREFIX="$PREFIX" WINESERVER="$WD/bin/wineserver"
  export WINEDLLPATH="$WD/lib/wine/x86_64-windows:$WD/lib/wine/i386-windows"
  export WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG="${WINEDEBUG:--all}"
  unset WINELOADER
}
wake(){ pkill -f 'caffeinate -dimsu' 2>/dev/null; nohup caffeinate -dimsu >/dev/null 2>&1 & disown 2>/dev/null; }
kill_wine(){ "$WD/bin/wineserver" -k 2>/dev/null; pkill -9 -f 'winedevice|explorer.exe|LaunchPad|rpcss|eqgame' 2>/dev/null; sleep 2; }
clean_winetemp(){ rm -rf "${TMPDIR:-/tmp}"/winetemp-* 2>/dev/null; }
start_rpcss(){ nohup "$WD/bin/wine" rpcss.exe >/dev/null 2>&1 & disown; sleep 2; }

cmd_libs(){
  [ -x "$HERE/fix-runtime-libs.sh" ] && { echo "== adding MoltenVK + FreeType (fix-runtime-libs.sh) =="; bash "$HERE/fix-runtime-libs.sh"; return; }
  die "fix-runtime-libs.sh missing next to this script."
}

cmd_install(){ # $1 = EQLegends_setup.exe
  local setup="${1:?usage: install <EQLegends_setup.exe>}"
  [ -f "$setup" ] || die "installer not found: $setup"
  wine_env; wake; kill_wine; clean_winetemp
  if [ ! -f "$PREFIX/system.reg" ]; then
    echo "== creating wine prefix =="; WINEARCH=win64 "$WD/bin/wine" wineboot --init >/dev/null 2>&1; "$WD/bin/wineserver" -w
  fi
  local src="$WD/lib/wine/x86_64-windows/winemetal.dll" sys32="$PREFIX/drive_c/windows/system32"
  [ -f "$src" ] && [ ! -f "$sys32/winemetal.dll" ] && cp "$src" "$sys32/winemetal.dll"
  echo "== running Daybreak installer (silent) =="
  ( cd "$PREFIX/drive_c" && "$WD/bin/wine" "$setup" /S ) >"$OH/logs/install.log" 2>&1
  "$WD/bin/wineserver" -w
  echo "installer done."
}

fix_bootstrap_path(){ # rename the mangled "C:" folder to the real game dir
  mkdir -p "$IGAMES"
  if [ -d "$IGAMES/C:" ] && [ ! -e "$GAME/LaunchPad.exe" ]; then
    rm -rf "$GAME" 2>/dev/null; mv "$IGAMES/C:" "$GAME" && echo "== fixed mangled path: 'C:' -> 'EverQuest Legends' =="
  fi
}

cmd_launch(){
  wine_env; wake; kill_wine; clean_winetemp
  fix_bootstrap_path
  mkdir -p "$OH/logs"
  local lp
  if [ -f "$GAME/LaunchPad.exe" ]; then
    lp="C:\\users\\Public\\Daybreak Game Company\\Installed Games\\EverQuest Legends\\LaunchPad.exe"
    echo "== launching the REAL launcher (post-bootstrap) =="
    cd "$GAME"
  elif [ -f "$PREFIX/drive_c/LaunchPad.exe" ]; then
    lp='C:\LaunchPad.exe'
    echo "== launching bootstrapper (first run; will download the real launcher, then re-run: ./eql-mac.sh launch) =="
    cd "$PREFIX/drive_c"
  else
    die "no LaunchPad found — run: ./eql-mac.sh install <EQLegends_setup.exe>"
  fi
  start_rpcss
  nohup "$WD/bin/wine" explorer "/desktop=$DESKTOP" "$lp" >"$OH/logs/launcher.log" 2>&1 & disown
  echo "Launcher starting — log in and hit Play. (log: $OH/logs/launcher.log)"
}

cmd_play(){
  [ -f "$GAME/eqgame.exe" ] || die "game not installed yet — launch the launcher, log in, and download first."
  wine_env; wake; kill_wine; clean_winetemp
  # windowed, matched to the desktop (avoids the fullscreen-exclusive popup + mouse offset)
  local ini="$GAME/eqclient.ini"
  if [ -f "$ini" ]; then
    /usr/bin/python3 - "$ini" <<'PY' 2>/dev/null || true
import sys,re
p=sys.argv[1]; s=open(p,'rb').read().decode('latin-1')
def setk(k,v,s):
    pat=re.compile(r'(?im)^(\s*'+re.escape(k)+r'\s*=).*?(\r?)$')
    return pat.sub(lambda m:m.group(1)+v+(m.group(2) or '\r'),s) if pat.search(s) else s
for k,v in (("Fullscreen","0"),("WindowedWidth","1280"),("WindowedHeight","960"),("Width","1280"),("Height","960")):
    s=setk(k,v,s)
open(p,'wb').write(s.encode('latin-1'))
PY
  fi
  start_rpcss
  cd "$GAME"
  echo "== launching the launcher; click Play to enter the game =="
  cmd_launch
}

cmd_setup(){ cmd_libs; cmd_install "${1:?usage: setup <EQLegends_setup.exe>}"; cmd_launch; }

cmd_doctor(){ [ -x "$HERE/doctor.sh" ] && bash "$HERE/doctor.sh" || echo "doctor.sh missing"; }

case "${1:-}" in
  libs)    cmd_libs ;;
  install) shift; cmd_install "$@" ;;
  launch)  cmd_launch ;;
  play)    cmd_play ;;
  setup)   shift; cmd_setup "$@" ;;
  doctor)  cmd_doctor ;;
  *) sed -n '2,33p' "$0" ;;
esac
