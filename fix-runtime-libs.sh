#!/usr/bin/env bash
# fix-runtime-libs.sh — give osxEQL's x86_64 Wine the unix libraries it is
# MISSING, so its launcher (Daybreak "LaunchPad", a Chromium/CEF app) can
# initialize its GPU + font backends.
#
# VERIFIED on macOS 26.4.1 / Apple Silicon, osxEQL v0.2.0:
#   BEFORE — LaunchPad dies ~2s after start. Wine logs:
#     err:vulkan:vulkan_init_once Failed to load libvulkan.1.dylib ... (no such file)
#     "Wine cannot find the FreeType font library" (x11, printed 6-11x)
#   AFTER placing the libs below into the Wine tree:
#     vulkan-fail = 0, freetype-miss = 0; Wine loads Vulkan + enumerates fonts.
#
# ROOT CAUSE: osxEQL v0.2.0 bundles DXMT (D3D11->Metal, for the GAME) but its
# Contents/Resources/Wine/lib is missing:
#   - libvulkan.1.dylib   (MoltenVK)  — CEF/Chromium renders its UI via Vulkan
#   - libfreetype.6.dylib + libpng16.16.dylib (x86_64) — Wine's font backend
# The maintainer's own machine has these from other tooling (Vulkan SDK / brew),
# which is why it works there but not on a clean install.
#
# WHY THE WINE TREE (not ~/lib): the bundled Wine is x86_64 (Rosetta). Its
# dlopen() for these leaf names searches the Wine tree (.../Wine/lib/) and
# /usr/local/lib — NOT ~/lib. (Modern macOS dyld dropped ~/lib from the default
# fallback, and strips DYLD_* for the wine exec chain, so ~/lib / env tricks do
# not work. Confirmed empirically.) So we drop x86_64 dylibs straight into the
# Wine tree, which is exactly where wine looks. Homebrew's arm64 dylibs are the
# wrong arch and cannot load into the x86_64 wine — we fetch Intel bottles.
#
# HONESTY — READ THIS: this makes Wine LOAD Vulkan + fonts (verified). It does
# NOT, by itself, make LaunchPad fully work: after this fix LaunchPad still
# exits ~6-9s later on a separate, deeper CEF/RPC failure
# (dispatch_exception code=6ba RPC_S_SERVER_UNAVAILABLE) that is currently
# UNRESOLVED (and appears to be an unverified path upstream). So this is a
# necessary-but-not-sufficient fix. See README "Known issues".
#
# This edits /Applications/osxEQL.app (adds 3 dylibs to Resources/Wine/lib).
# Additive + reversible: `./fix-runtime-libs.sh --revert` removes exactly them.
set -uo pipefail

APP="${OSXEQL_APP:-/Applications/osxEQL.app}"
WD="$APP/Contents/Resources/Wine"; LIBD="$WD/lib"
OH="$HOME/Library/Application Support/osxEQL"
MANIFEST="$OH/qol/runtime-libs.manifest"
LIBS="libvulkan.1.dylib libfreetype.6.dylib libpng16.16.dylib"

[ -d "$LIBD" ] || { echo "ERROR: osxEQL Wine tree not found at $LIBD" >&2; exit 1; }
mkdir -p "$OH/qol"

if [ "${1:-}" = "--revert" ]; then
  echo "Reverting bundled runtime libs…"
  for f in $LIBS; do [ -f "$LIBD/$f" ] && { rm -f "$LIBD/$f"; echo "  removed $LIBD/$f"; }; done
  rm -f "$MANIFEST"; echo "done."; exit 0
fi

# Idempotent: if all three are present AND x86_64, nothing to do.
have_all=1
for f in $LIBS; do
  { [ -f "$LIBD/$f" ] && file "$LIBD/$f" | grep -q x86_64; } || have_all=0
done
if [ "$have_all" = 1 ] && [ "${1:-}" != "--force" ]; then
  echo "All runtime libs already present (x86_64). Use --force to re-fetch."
  printf '%s\n' $LIBS | sed "s#^#$LIBD/#" > "$MANIFEST"; exit 0
fi

GHCR_TOKEN="QQ=="                    # Homebrew anonymous ghcr.io bottle token
TAGS="sequoia sonoma ventura"        # x86_64 (Intel) macOS bottle tags
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

fetch_bottle() { # $1=formula -> extracts cellar tree into $TMP
  local f="$1" j u="" t
  j="$(curl -fsSL "https://formulae.brew.sh/api/formula/$f.json")" || { echo "  ! API fetch failed: $f" >&2; return 1; }
  for t in $TAGS; do
    u="$(printf '%s' "$j" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin)['bottle']['stable']['files'].get('$t',{}).get('url',''))")"
    [ -n "$u" ] && break
  done
  [ -n "$u" ] || { echo "  ! no x86_64 bottle for $f (tags: $TAGS)" >&2; return 1; }
  echo "  fetching $f  (x86_64 / $t)…"
  curl -fsSL -H "Authorization: Bearer $GHCR_TOKEN" -o "$TMP/$f.tgz" "$u" || return 1
  tar xzf "$TMP/$f.tgz" -C "$TMP"
}

echo "== fetching x86_64 runtime libraries =="
fetch_bottle molten-vk || exit 1
fetch_bottle freetype   || exit 1
fetch_bottle libpng     || exit 1

mvk="$(/usr/bin/find "$TMP" -name libMoltenVK.dylib   | head -1)"
ft="$( /usr/bin/find "$TMP" -name 'libfreetype.6.dylib' | head -1)"
pg="$( /usr/bin/find "$TMP" -name 'libpng16.16.dylib'   | head -1)"
for v in "$mvk" "$ft" "$pg"; do
  [ -f "$v" ] || { echo "ERROR: an extracted dylib is missing" >&2; exit 1; }
  file "$v" | grep -q x86_64 || { echo "ERROR: $v is not x86_64" >&2; exit 1; }
done

echo "== installing into $LIBD =="
: > "$MANIFEST"
install_one() { cp "$1" "$LIBD/$2"; chmod u+w "$LIBD/$2"; echo "$LIBD/$2" >> "$MANIFEST"; }
install_one "$mvk" libvulkan.1.dylib      # MoltenVK exposes the Vulkan entry points wine needs
install_one "$ft"  libfreetype.6.dylib
install_one "$pg"  libpng16.16.dylib

install_name_tool -id libvulkan.1.dylib               "$LIBD/libvulkan.1.dylib"   2>/dev/null || true
install_name_tool -id libfreetype.6.dylib             "$LIBD/libfreetype.6.dylib" 2>/dev/null || true
install_name_tool -id @loader_path/libpng16.16.dylib  "$LIBD/libpng16.16.dylib"   2>/dev/null || true
op="$(otool -L "$LIBD/libfreetype.6.dylib" | awk '/libpng16/{print $1; exit}')"
[ -n "$op" ] && install_name_tool -change "$op" @loader_path/libpng16.16.dylib "$LIBD/libfreetype.6.dylib" 2>/dev/null || true
# Ad-hoc re-sign (wine itself is unsigned, but keep the modified dylibs valid).
codesign -f -s - "$LIBD/libvulkan.1.dylib" "$LIBD/libfreetype.6.dylib" "$LIBD/libpng16.16.dylib" 2>/dev/null || true

echo "== done =="
for f in $LIBS; do echo "  $f  $(lipo -archs "$LIBD/$f" 2>/dev/null)"; done
echo
echo "Wine will no longer fail to load Vulkan or FreeType. NOTE: LaunchPad may"
echo "still exit on a separate CEF/RPC issue — see README 'Known issues'."
