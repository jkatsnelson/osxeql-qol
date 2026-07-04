# Upstream PR drafts for sowoky/osxEQL

Three PRs that make a **fresh install** of osxEQL actually work end-to-end (verified in-game
on macOS 26.4.1 / Apple Silicon). Suggested landing order: **A → C → B** (A and C touch the
same launch block in `app/launcher.sh`, so the second to land needs a trivial rebase).

Nothing here has been opened. Review, then submit from your account.

---

## PR A — Fix fresh-install launch: promote the real launcher out of the mangled "C:" folder

**Problem.** A cold install (fresh prefix → `EQLegends_setup.exe /S` → open launcher) never
reaches a usable launcher. `docs/STATUS.md` flags this as unverified. On a truly fresh box
the app opens, lives ~6–9s, never paints, and exits.

**Root cause.** On a fresh install, `C:\LaunchPad.exe` (the `BOOT_LP`/`BOOT_WINPATH` that
`app/launcher.sh` calls) is a **bootstrapper**, not the real launcher. It loads Daybreak's
`npdg0act.dll` download plugin, which crashes under this Wine
(`dispatch_exception code=6ba RPC_S_SERVER_UNAVAILABLE`; npdg loads/unloads 3× then the
process dies without painting). But *before* dying it downloads the **real** CEF launcher
(`libcef.dll` + web login UI) into a folder **literally named `C:`** under
`…/Installed Games/` (a Wine path bug on the `C:\…` destination):

```
<prefix>/drive_c/users/Public/Daybreak Game Company/Installed Games/C:/LaunchPad.exe
```

Renaming `Installed Games/C:` → `Installed Games/EverQuest Legends` and launching that
directly works end-to-end: login renders, the 6.9 GB client downloads, **Play** spawns
`eqgame` with DXMT (`dbg.txt`: `CRender::InitDevice completed successfully`).

**Fix.** In `app/launcher.sh`, after the installer step, detect the mangled
`Installed Games/C:/LaunchPad.exe`; if present and `GAME_LP` isn't, `mv` it into place, then
prefer `GAME_LP`. Idempotent (no-op once the real game dir exists). At the shell layer `:` in
a filename is an ordinary byte — `mv` handles it with the existing double-quotes.

### Diff (`app/launcher.sh`)

```diff
@@
 BOOT_LP="$WINEPREFIX/drive_c/LaunchPad.exe"           # where EQLegends_setup.exe /S lands it
 BOOT_WINPATH='C:\LaunchPad.exe'
+# Fresh-install path bug: C:\LaunchPad.exe is only a *bootstrapper* (it loads
+# Daybreak's npdg0act.dll, which crashes under this Wine with
+# RPC_S_SERVER_UNAVAILABLE and exits without painting). Before dying it downloads
+# the REAL CEF launcher into a folder literally named "C:" under Installed Games
+# — Wine mangles the "C:\..." path the installer writes. promote_real_launcher()
+# renames it into place so we launch the working launcher, not the crasher.
+MANGLED_DIR="$(dirname "$GAME_DIR")/C:"
+MANGLED_LP="$MANGLED_DIR/LaunchPad.exe"
 EQL_URL="https://www.everquest.com/"
@@
     "$WINE" "$setup" /S >"$OSXEQL_HOME/logs/install.log" 2>&1
     "$WINESERVER" -w 2>/dev/null
-    if [ ! -f "$BOOT_LP" ]; then
+    if [ ! -f "$BOOT_LP" ] && [ ! -f "$MANGLED_LP" ] && [ ! -f "$GAME_LP" ]; then
         alert "Daybreak's installer finished but LaunchPad wasn't found. See logs/install.log in ~/Library/Application Support/osxEQL."
         exit 1
     fi
 }
+
+# ---- promote the real CEF launcher out of the mangled "C:" folder ----------
+promote_real_launcher(){
+    [ -f "$MANGLED_LP" ] || return 0
+    [ -f "$GAME_LP" ]    && return 0
+    mv "$MANGLED_DIR" "$GAME_DIR" 2>>"$LOG"
+}
@@
 # ---- decide what to launch ------------------------------------------------
-if [ -f "$GAME_LP" ]; then
-    fix_eqclient
-    LP_WINPATH="$GAME_WINDIR\\LaunchPad.exe"
-elif [ -f "$BOOT_LP" ]; then
-    LP_WINPATH="$BOOT_WINPATH"
-else
-    run_installer
-    LP_WINPATH="$BOOT_WINPATH"
-fi
+# Fresh box: nothing installed yet -> run Daybreak's installer first.
+if [ ! -f "$GAME_LP" ] && [ ! -f "$BOOT_LP" ] && [ ! -f "$MANGLED_LP" ]; then
+    run_installer
+fi
+# Prefer the real launcher, de-mangling it if the installer left it under "C:".
+promote_real_launcher
+if [ -f "$GAME_LP" ]; then
+    fix_eqclient
+    LP_WINPATH="$GAME_WINDIR\\LaunchPad.exe"
+else
+    LP_WINPATH="$BOOT_WINPATH"
+fi
```

---

## PR C — Start rpcss so the launcher's RPC/COM calls resolve

**Problem.** The minimal prefix never brings up `rpcss.exe`, so the CEF launcher's (and the
download plugin's) RPC/COM calls fail with `RPC_S_SERVER_UNAVAILABLE` (`code=6ba`).

**Fix.** Start `rpcss.exe` in the background just before the launch `exec`. Idempotent
(Wine's rpcss is a singleton).

### Diff (`app/launcher.sh`)

```diff
@@
 cd "$GAME_DIR" 2>/dev/null || cd "$WINEPREFIX/drive_c"
+# rpcss provides the RPC/COM endpoint mapper the CEF launcher + Daybreak's
+# download plugin call; the minimal prefix doesn't auto-start it, giving
+# RPC_S_SERVER_UNAVAILABLE (dispatch_exception code=6ba). Start it (singleton;
+# a second start is a no-op) and let it settle before we launch.
+"$WINE" rpcss.exe >/dev/null 2>&1 &
+"$WINESERVER" -w 2>/dev/null || true
 # LaunchPad in a wine virtual desktop (avoids its splash-window deadlock).
 exec "$WINE" explorer "/desktop=osxEQL,${OSXEQL_W}x${OSXEQL_H}" "$LP_WINPATH" >"$LOG" 2>&1
```

---

## PR B — Bundle x86_64 MoltenVK + FreeType into the Wine tree

**Problem.** On a machine that isn't the dev's (no Vulkan SDK, arm64-only Homebrew, or no
Homebrew), `Contents/Resources/Wine/lib/` ships no `libvulkan.1.dylib`, no
`libMoltenVK.dylib`, and no x86_64 `libfreetype.6.dylib`/`libpng16.16.dylib`. The CEF
launcher drives its UI over Vulkan and Wine needs FreeType; on the dev's box these are
silently satisfied by Intel Homebrew in `/usr/local/lib`, on a clean box they're missing.

**Why the obvious fix fails.** These are host dylibs Wine `dlopen`s by leaf name from its own
tree. `~/lib` + `DYLD_*` does **not** work on current macOS (DYLD_* stripped; `~/lib` not in
the default dyld fallback). They must live in `Contents/Resources/Wine/lib/`.

**Fix.** Add `engine/fetch-runtime-libs.sh` (below) that pulls the **x86_64** Homebrew
bottles for `molten-vk`, `vulkan-loader`, `freetype`, `libpng` from ghcr, stages the dylibs
into the Wine tree's `lib/`, repoints FreeType's libpng dep to `@loader_path`, stages
MoltenVK's ICD manifest, and ad-hoc-signs them. Run it before `packaging/build-app.sh` so the
libs ship in the DMG. A one-line `launcher.sh` change exports `VK_ICD_FILENAMES` (a normal
env var — survives where DYLD_* wouldn't).

*(Full `engine/fetch-runtime-libs.sh` script + the `VK_ICD_FILENAMES` launcher diff are
included in this repo's `fix-runtime-libs.sh` — the runtime version — and can be adapted to
the `engine/` build-time flow. Tradeoff: fetch-at-stage-time vs. committing 4 prebuilt
dylibs under `packaging/`. The fetch-script keeps "the list IS the artifact" per the
project's `install-skills.sh` style.)*

---

## Already open (separate)

A docs PR fixing `docs/ARCHITECTURE.md` §4's stale launch snippet (it still shows
`export WINELOADER=…` and `WINEPREFIX=…/prefix-cx`, both contradicting the shipped
`launcher.sh`). PRs A–C don't need to touch it.
