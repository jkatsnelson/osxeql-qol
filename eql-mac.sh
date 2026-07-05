#!/usr/bin/env bash
# eql-mac.sh — one command to EverQuest Legends on Apple Silicon: free & native
# (open-source Wine + DXMT/Metal, no CrossOver). Self-contained: it installs
# Rosetta 2 and osxEQL.app for you, adds the libs osxEQL is missing, runs
# Daybreak's installer, and does the bootstrapper->real-launcher hand-off that a
# vanilla osxEQL fresh install can't. Verified end-to-end on macOS 26.4 /
# Apple Silicon (dbg.txt: "CRender::InitDevice completed successfully").
#
# YOU PROVIDE: an Apple Silicon Mac, a Daybreak / EQ Legends account, and the
# official EQLegends_setup.exe (download it while logged in at
# https://www.everquest.com — it's account-gated, we can't fetch it for you).
#
# USAGE
#   ./eql-mac.sh setup ~/Downloads/EQLegends_setup.exe   # do everything -> login screen
#   ./eql-mac.sh launch                                   # (re)open the launcher to log in / patch / Play
#   ./eql-mac.sh play                                     # tune display + open launcher; click Play to enter
#   ./eql-mac.sh doctor                                   # health check
set -uo pipefail

OSXEQL_DMG_URL="${OSXEQL_DMG_URL:-https://github.com/sowoky/osxEQL/releases/download/v0.2.0/osxEQL-0.2.0.dmg}"
APP="${OSXEQL_APP:-/Applications/osxEQL.app}"
WD="$APP/Contents/Resources/Wine"
OH="$HOME/Library/Application Support/osxEQL"
PREFIX="$OH/prefix"
IGAMES="$PREFIX/drive_c/users/Public/Daybreak Game Company/Installed Games"
GAME="$IGAMES/EverQuest Legends"
MANGLED="$IGAMES/C:"                       # where the bootstrapper mis-drops the real launcher
DESKTOP="osxEQL,1280x960"
HERE="$(cd "$(dirname "$0")" && pwd)"

say(){ printf '\033[1;33m==>\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---- prerequisites --------------------------------------------------------
ensure_rosetta(){
  arch -x86_64 /usr/bin/true 2>/dev/null && return 0
  say "installing Rosetta 2 (needed for the x86_64 Wine runtime)…"
  softwareupdate --install-rosetta --agree-to-license || die "Rosetta install failed."
}
ensure_osxeql(){
  [ -d "$WD" ] && { say "osxEQL.app present."; return 0; }
  say "installing osxEQL.app from the official release…"
  local dmg; dmg="$(mktemp -t osxEQL).dmg"
  curl -# -fL -o "$dmg" "$OSXEQL_DMG_URL" || die "couldn't download osxEQL DMG."
  local mp; mp="$(hdiutil attach "$dmg" -nobrowse -readonly | grep -o '/Volumes/.*' | tail -1)"
  [ -n "$mp" ] || die "couldn't mount the DMG."
  rm -rf "$APP"; cp -R "$mp/osxEQL.app" /Applications/ || die "couldn't copy to /Applications (need admin)."
  hdiutil detach "$mp" >/dev/null 2>&1
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null
  rm -f "$dmg"
  [ -d "$WD" ] || die "osxEQL install looks incomplete."
  say "osxEQL.app installed."
}

# ---- wine plumbing --------------------------------------------------------
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
promote(){ # rename the mangled "C:" folder into the real game dir
  [ -d "$MANGLED" ] || return 0
  [ -f "$GAME/LaunchPad.exe" ] && { rm -rf "$MANGLED"; return 0; }
  rm -rf "$GAME" 2>/dev/null; mv "$MANGLED" "$GAME" && say "promoted the real launcher: 'C:' -> 'EverQuest Legends'"
}

# ---- commands -------------------------------------------------------------
cmd_libs(){ [ -x "$HERE/fix-runtime-libs.sh" ] || die "fix-runtime-libs.sh missing."; say "adding MoltenVK + FreeType…"; bash "$HERE/fix-runtime-libs.sh"; }

cmd_install(){ # $1 = EQLegends_setup.exe
  local setup="${1:-}"
  [ -n "$setup" ] || die "usage: ./eql-mac.sh setup <path-to-EQLegends_setup.exe>  (get it from https://www.everquest.com while logged in)"
  [ -f "$setup" ] || die "installer not found: $setup"
  wine_env; wake; kill_wine; clean_winetemp
  mkdir -p "$OH/logs"                          # fresh prefix has no logs/ dir yet
  if [ ! -f "$PREFIX/system.reg" ]; then
    say "creating the Wine prefix…"; WINEARCH=win64 "$WD/bin/wine" wineboot --init >/dev/null 2>&1; "$WD/bin/wineserver" -w
  fi
  local m="$WD/lib/wine/x86_64-windows/winemetal.dll"
  [ -f "$m" ] && [ ! -f "$PREFIX/drive_c/windows/system32/winemetal.dll" ] && cp "$m" "$PREFIX/drive_c/windows/system32/winemetal.dll"
  say "running Daybreak's installer (silent)…"
  ( cd "$PREFIX/drive_c" && "$WD/bin/wine" "$setup" /S ) >"$OH/logs/install.log" 2>&1
  "$WD/bin/wineserver" -w
  [ -f "$PREFIX/drive_c/LaunchPad.exe" ] || [ -f "$GAME/LaunchPad.exe" ] || die "installer didn't produce LaunchPad — see $OH/logs/install.log"
  say "installer done."
}

cmd_launch(){
  wine_env; wake; kill_wine; clean_winetemp; mkdir -p "$OH/logs"
  promote
  if [ -f "$GAME/LaunchPad.exe" ]; then
    say "opening the real launcher — log in, let it patch/download, then hit Play."
    start_rpcss
    ( cd "$GAME"; nohup "$WD/bin/wine" explorer "/desktop=$DESKTOP" "C:\\users\\Public\\Daybreak Game Company\\Installed Games\\EverQuest Legends\\LaunchPad.exe" >"$OH/logs/launcher.log" 2>&1 & disown )
    return 0
  fi
  [ -f "$PREFIX/drive_c/LaunchPad.exe" ] || die "no launcher found — run: ./eql-mac.sh setup <EQLegends_setup.exe>"
  # First run: the bootstrapper fetches the real launcher into "C:/" then crashes.
  # Run it, wait for the real launcher to land, then promote + launch it — automatically.
  say "first run: fetching the real launcher (the bootstrapper crashes on purpose; that's expected)…"
  start_rpcss
  ( cd "$PREFIX/drive_c"; nohup "$WD/bin/wine" explorer "/desktop=$DESKTOP" 'C:\LaunchPad.exe' >"$OH/logs/bootstrap.log" 2>&1 & disown )
  local i
  for i in $(seq 1 90); do
    [ -f "$MANGLED/LaunchPad.libs/libcef.dll" ] && { say "real launcher downloaded."; break; }
    sleep 1
  done
  kill_wine
  promote
  [ -f "$GAME/LaunchPad.exe" ] || die "the bootstrapper didn't leave a launcher behind — see $OH/logs/bootstrap.log (try: ./eql-mac.sh launch again)"
  wake; start_rpcss
  say "opening the real launcher — log in, download the ~6.9 GB client, then hit Play."
  ( cd "$GAME"; nohup "$WD/bin/wine" explorer "/desktop=$DESKTOP" "C:\\users\\Public\\Daybreak Game Company\\Installed Games\\EverQuest Legends\\LaunchPad.exe" >"$OH/logs/launcher.log" 2>&1 & disown )
}

tune_eqclient(){
  local ini="$GAME/eqclient.ini"; [ -f "$ini" ] || return 0
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
}

cmd_play(){
  [ -f "$GAME/eqgame.exe" ] || die "the game isn't installed yet — run ./eql-mac.sh launch, log in, and let it download first."
  tune_eqclient
  say "opening the launcher — click Play to enter the game (eqgame -> DXMT/Metal)."
  cmd_launch
}

cmd_setup(){ ensure_rosetta; ensure_osxeql; cmd_libs; cmd_install "${1:-}"; cmd_launch; }
cmd_doctor(){ [ -x "$HERE/doctor.sh" ] && bash "$HERE/doctor.sh" || echo "doctor.sh missing"; }

[ -d "$WD" ] || case "${1:-}" in setup|"") ;; *) die "osxEQL.app not installed — run: ./eql-mac.sh setup <EQLegends_setup.exe>";; esac
case "${1:-}" in
  setup)   shift; cmd_setup "${1:-}" ;;
  libs)    ensure_osxeql; cmd_libs ;;
  install) shift; ensure_osxeql; cmd_install "${1:-}" ;;
  launch)  cmd_launch ;;
  play)    cmd_play ;;
  doctor)  cmd_doctor ;;
  *) sed -n '2,25p' "$0" ;;
esac
