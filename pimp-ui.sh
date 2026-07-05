#!/usr/bin/env bash
# pimp-ui.sh — set up a clean, readable EverQuest UI for a good first login.
# Applies safe, standard, per-install eqclient.ini tweaks (backs up first):
#   - loads the stock "default_modern" skin (cleaner than the 1999 default)
#   - windowed 1280x960 (kills the fullscreen-exclusive popup + mouse offset)
#   - larger chat font, moderate particle density
# EQ ships with good labeled maps already, so nothing to install there.
# In-game polish (UI scale, hotbars, window layout) is per-character — see
# docs/UI-FIRST-LOGIN.md. Reversible: your eqclient.ini.premod-bak is kept.
set -uo pipefail
OH="$HOME/Library/Application Support/osxEQL"
GAME="${EQ_GAME_DIR:-$OH/prefix/drive_c/users/Public/Daybreak Game Company/Installed Games/EverQuest Legends}"
INI="$GAME/eqclient.ini"
[ -f "$INI" ] || { echo "eqclient.ini not found — log in once so the game creates it, then re-run."; exit 0; }
cp "$INI" "$INI.premod-bak"
/usr/bin/python3 - "$INI" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,'rb').read().decode('latin-1')
if not re.search(r'(?im)^\[Defaults\]', s): s='[Defaults]\r\n'+s
want={'LoadUIName':'default_modern','ChatFontSize':'4','Fullscreen':'0',
      'WindowedWidth':'1280','WindowedHeight':'960','Width':'1280','Height':'960',
      'ShowSpellEffects':'TRUE','SpellParticleDensity':'50','EnvironmentParticleDensity':'50'}
for k,v in want.items():
    pat=re.compile(r'(?im)^(\s*'+re.escape(k)+r'\s*=).*?(\r?)$')
    s=pat.sub(lambda m:m.group(1)+v+(m.group(2) or '\r'),s) if pat.search(s) \
      else re.sub(r'(?im)^(\[Defaults\]\s*?\r?\n)', r'\1'+k+'='+v+'\r\n', s, count=1)
open(p,'wb').write(s.encode('latin-1'))
print("eqclient.ini tuned: default_modern skin, windowed 1280x960, readable chat")
PY
echo "Maps: EQ Legends ships labeled community-quality maps already ($(/bin/ls "$GAME/maps"/*.txt 2>/dev/null | wc -l | tr -d ' ') zones) — press M in-game."
echo "Next: log in, then see docs/UI-FIRST-LOGIN.md for the in-game layout polish."
