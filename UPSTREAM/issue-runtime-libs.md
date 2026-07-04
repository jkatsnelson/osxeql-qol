# LaunchPad won't start on a clean machine: `Wine/lib` is missing `libvulkan.1.dylib` (MoltenVK) and an x86_64 FreeType

**TL;DR:** On a fresh install of osxEQL v0.2.0 (no Vulkan SDK, no Intel Homebrew), Daybreak's LaunchPad exits ~2s after launch. Two libraries the launcher needs aren't bundled in `Contents/Resources/Wine/lib/`: **`libvulkan.1.dylib` (MoltenVK)** and an **x86_64 `libfreetype.6.dylib` (+`libpng16.16.dylib`)**. Adding them (x86_64) makes Wine initialize Vulkan + fonts cleanly. A **separate** CEF/RPC crash still remains after that (details below) — this issue is really two findings.

## Environment
- Mac mini, Apple Silicon, **macOS 26.4.1 (Tahoe)**, Rosetta 2 present
- Fresh osxEQL **v0.2.0** DMG → `/Applications`, quarantine cleared
- No Vulkan SDK, no CrossOver, no `/usr/local` (Intel) Homebrew — i.e. a genuinely clean box
- Installer ran fine; `C:\LaunchPad.exe` present; `macdrv_functions` exported ✔

## Symptom
Launch osxEQL → LaunchPad process starts (~2s) then exits within ~2–6s, no window. `logs/app-launch.log` contains **only** the FreeType warning, repeated — which hides the real cause because the launcher sets `WINEDEBUG=-all`.

## Diagnosis (`WINEDEBUG=+seh,+err,+font,+loaddll`)
Two missing unix libs:

```
err:vulkan:vulkan_init_once Failed to load libvulkan.1.dylib: dlopen(libvulkan.1.dylib ...): tried:
   '.../Contents/Resources/Wine/lib/wine/x86_64-unix/libvulkan.1.dylib' (no such file),
   '.../Contents/Resources/Wine/lib/libvulkan.1.dylib' (no such file),
   '/usr/local/lib/libvulkan.1.dylib' (no such file), '/usr/lib/...' (no such file) ...
err:vulkan:init_vulkan Failed to load Wine graphics driver supporting Vulkan   (×6)
```
LaunchPad is CEF/Chromium; its GPU/compositor needs Vulkan → MoltenVK. Not bundled.

```
Wine cannot find the FreeType font library.   (×6–11)
```
`win32u.so` `dlopen()`s `libfreetype.6.dylib` by leaf name. The app bundles none; Homebrew's is **arm64** — wrong arch for the **x86_64** (Rosetta) Wine.

Key detail: the dlopen search list **includes the Wine tree** (`.../Wine/lib/`) but **not** `~/lib`, and modern macOS strips `DYLD_*` across the wine exec chain — so the libs must be dropped directly into `Wine/lib/` (an `~/lib` + `DYLD_FALLBACK_LIBRARY_PATH` approach does **not** work on 26.x).

## Fix that works (verified)
Fetch the **x86_64** Homebrew bottles and place into `Contents/Resources/Wine/lib/`:
- `molten-vk` → copy `libMoltenVK.dylib` as **`libvulkan.1.dylib`**
- `freetype` → `libfreetype.6.dylib`, `libpng` → `libpng16.16.dylib` (rewrite freetype's libpng ref to `@loader_path`)

Result: `vulkan_init_once` succeeds, `cannot find the FreeType` count → **0**, Wine enumerates fonts. Repro/patch script: <https://github.com/jkatsnelson/osxeql-qol/blob/main/fix-runtime-libs.sh>

Suggested upstream fix: **bundle** these (x86_64) in the app, or fetch them during `engine/` staging. Happy to open a PR if you'd like it in a particular shape.

## The part that's still broken (separate)
With Vulkan + fonts fixed, LaunchPad now fully initializes but **still exits ~6–9s** later:
```
trace:seh:dispatch_exception code=6ba (RPC_S_SERVER_UNAVAILABLE) ... 
→ call_seh_handlers → RtlUnwindEx (STATUS_LONGJUMP ×253) → free_modref browseui.dll → exit
```
No window is ever painted. Did **not** help: `caffeinate` (display awake), CEF flags `--no-sandbox --disable-gpu --disable-gpu-compositing --in-process-gpu`. This looks like the unverified cold-LaunchPad-login path `STATUS.md` mentions. Flagging it here in case you (or anyone) have hit `RPC_S_SERVER_UNAVAILABLE` from LaunchPad's CEF before — happy to gather more traces.

---
*Filed with reproduction + a working partial-fix script. Not affiliated with Daybreak/Game Jawn. 🤖 diagnosis assisted by Claude Code.*
