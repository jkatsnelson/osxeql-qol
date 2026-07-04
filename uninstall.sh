#!/usr/bin/env bash
# uninstall.sh — revert everything osxeql-qol did, using the manifest.
#
# Reverses the manifest in LIFO order:
#   create <path>  -> delete <path>            (files we added)
#   backup <path>  -> restore <path> from <path>.qol-bak, remove the .qol-bak
#   stage  <path>  -> (left alone by default; --purge removes qol/ staging too)
#   tuned  <path>  -> restore eqclient.ini from its .qol-bak if present
#
# Does NOT run wine and does NOT touch /Applications/osxEQL.app. The freetype
# closure we dropped in ~/lib is removed (and any arm64 original we shifted aside
# is restored). Re-runnable; missing paths are skipped quietly.
#
# USAGE
#   ./uninstall.sh            # revert changes, keep qol/ staging + downloaded maps
#   ./uninstall.sh --purge    # also delete qol/ (staging, closure copy, manifest)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/common.sh"

purge=0; [ "${1:-}" = "--purge" ] && purge=1
[ -f "$QOL_MANIFEST" ] || { warn "no manifest at $QOL_MANIFEST — nothing recorded to revert."; }

if [ -f "$QOL_MANIFEST" ]; then
  hdr "Reverting recorded changes"
  # LIFO so game-dir copies revert before staging, backups restore last.
  /usr/bin/tail -r "$QOL_MANIFEST" | while IFS=$'\t' read -r action path; do
    [ -n "${path:-}" ] || continue
    case "$action" in
      create)
        if [ -e "$path" ]; then rm -rf "$path" && ok "removed $path"; fi ;;
      backup|tuned)
        if [ -f "$path$QOL_BAK" ]; then
          cp -p "$path$QOL_BAK" "$path" && rm -f "$path$QOL_BAK" && ok "restored $path"
        fi ;;
      stage)
        [ "$purge" -eq 1 ] && { rm -rf "$path" && ok "unstaged $path"; } || true ;;
    esac
  done
fi

# Belt-and-suspenders: ensure the ~/lib closure is gone even if manifest was lost.
for lib in libfreetype.6.dylib libpng16.16.dylib; do
  if [ -f "$HOME/lib/$lib" ]; then
    case "$(file "$HOME/lib/$lib" 2>/dev/null)" in
      *x86_64*) rm -f "$HOME/lib/$lib" && ok "removed ~/lib/$lib" ;;
    esac
  fi
  [ -f "$HOME/lib/$lib.qol-bak" ] && mv "$HOME/lib/$lib.qol-bak" "$HOME/lib/$lib" && ok "restored ~/lib/$lib"
done
[ -d "$HOME/lib" ] && rmdir "$HOME/lib" 2>/dev/null && ok "removed empty ~/lib" || true

# Remove the x86_64 runtime libs added to the app's Wine tree (vulkan + freetype + libpng).
if [ -x "$HERE/fix-runtime-libs.sh" ]; then
  hdr "Reverting bundled runtime libs (Wine tree)"
  bash "$HERE/fix-runtime-libs.sh" --revert || true
fi

if [ "$purge" -eq 1 ]; then
  hdr "Purging qol/ staging"
  rm -rf "$QOL_HOME" && ok "removed $QOL_HOME"
else
  log "Kept staging + downloaded maps under $QOL_HOME (use --purge to remove)."
fi

log "The Vulkan/FreeType libs added to the app's Wine tree were reverted above."
hdr "Uninstall complete."
