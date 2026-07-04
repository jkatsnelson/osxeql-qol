# osxeql-qol

Player-facing **quality-of-life** helpers for running **EverQuest Legends on a Mac**
via [osxEQL](https://github.com/sowoky/osxEQL) (open-source Wine + DXMT on Apple
Silicon) — plus the **missing runtime libraries** I had to add to get osxEQL's
launcher to initialize at all.

Separate from osxEQL on purpose: osxEQL is the *compat layer*; this is the
*personal-taste + gap-filling* layer on top.

> **Status, up front and honest (macOS 26.4.1, M-series):**
> EverQuest Legends is **not yet playable** through osxEQL v0.2.0 on a clean
> machine. Daybreak's **LaunchPad** (a Chromium/CEF app) crashes on startup.
> This repo gets it **much** further — from *dies in 2s* to *fully initializes
> Vulkan + fonts* — by supplying two libraries osxEQL forgot to bundle. But a
> **deeper CEF/RPC crash remains unsolved** (`RPC_S_SERVER_UNAVAILABLE`), so you
> still can't reach the login screen. Everything below is labeled **verified**
> or **not working** — no marketing.

## The headline finding: osxEQL is missing two runtime libraries

osxEQL bundles DXMT (Direct3D 11 → Metal) for the **game**, but its
`Contents/Resources/Wine/lib/` is missing what the **launcher** needs:

| Missing lib | Who needs it | Symptom without it |
|---|---|---|
| `libvulkan.1.dylib` (MoltenVK) | LaunchPad's CEF/Chromium GPU compositor | `err:vulkan:vulkan_init_once Failed to load libvulkan.1.dylib` → instant exit |
| `libfreetype.6.dylib` + `libpng16.16.dylib` (x86_64) | Wine's font backend | `Wine cannot find the FreeType font library` → no text / early exit |

Homebrew's copies are **arm64** — the wrong arch for osxEQL's **x86_64** (Rosetta)
Wine. And they must live in the **Wine tree** (that's where Wine's `dlopen()`
searches), not `~/lib` — modern macOS dyld ignores `~/lib` and strips `DYLD_*`
across the wine exec chain (both confirmed empirically). `fix-runtime-libs.sh`
fetches the correct **x86_64 Homebrew bottles** and installs them there.

**Verified:** after running it, `vulkan-fail = 0` and `freetype-miss = 0`; Wine
loads MoltenVK 1.4.1 and enumerates fonts. **This is filed upstream** — it's an
osxEQL bug, and the right long-term fix is for osxEQL to bundle these.

## Known issues (what's still broken)

- **LaunchPad still exits ~6–9s after init.** With Vulkan + fonts fixed, the next
  failure is `dispatch_exception code=6ba (RPC_S_SERVER_UNAVAILABLE)` → SEH unwind
  → process exit, with no window ever painted. Tried and did **not** help:
  keeping the display awake (`caffeinate`), CEF flags
  (`--no-sandbox --disable-gpu --in-process-gpu`). This looks like an unsolved
  CEF-on-Wine path; osxEQL's own `STATUS.md` admits a cold LaunchPad login was
  never verified end-to-end. **Under investigation.** Until it's solved, the game
  can't be downloaded/played, and the map/config helpers below can only *stage*.

## Quick start

```sh
git clone <this-repo> && cd osxeql-qol
./doctor.sh                 # read-only health check (safe anytime)
./fix-runtime-libs.sh       # add the missing Vulkan + FreeType libs (edits the app; reversible)
./install.sh                # stage maps + config; reconciles into the game dir once it exists
```

## What's in the box

| Component | What it does | Status |
|---|---|---|
| `fix-runtime-libs.sh` | Fetches x86_64 MoltenVK + freetype + libpng and installs them into osxEQL's Wine tree. `--revert` removes them. | **verified** (Wine loads them; vulkan/freetype errors gone) — but see Known issues |
| `install-maps.sh` | Brewall/Good community **maps** into the client `maps/` (classic EQ has none). Stages until the game exists. | plumbing **verified**; can't reach the game dir yet (LaunchPad blocked) |
| `install-config.sh` + `apply-eqclient-tuning.py` | A sane **`dxmt.conf`** + **CRLF/latin-1-safe, idempotent `eqclient.ini`** tuning that never touches osxEQL's window-size pins. | tuning byte-safety/idempotency **verified**; effect in-game **untested** (blocked) |
| `doctor.sh` | Read-only health check: Rosetta, quarantine, `macdrv_functions`, the runtime libs, prefix, game dir, maps, disk. | **verified** |
| `helpers/brightness.md` | The "it's SO DARK" levers that actually work under Wine/DXMT (Enhanced Vision slider, not the dead hardware-gamma slider). | guidance |
| `helpers/install-stealthpointer.sh` | Fixes the macOS double-cursor (StealthPointer, F1/F2). | **untested** |
| `helpers/zeal.md` | Honest note: Zeal is likely broken under DXMT — not installed. | assessment |
| `install.sh` / `uninstall.sh` | Idempotent orchestrator; `uninstall.sh` reverts everything incl. the added libs. | **verified** (file ops) |

## Uninstall

```sh
./uninstall.sh                    # revert config/maps changes
./fix-runtime-libs.sh --revert    # remove the 3 libs added to the app bundle
```

## License

MIT (see `LICENSE`). Unofficial; not affiliated with Daybreak Game Company,
Game Jawn, osxEQL, DXMT, or MoltenVK.
