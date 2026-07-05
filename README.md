# osxeql-qol — EverQuest Legends on your Mac, native & free

Play **EverQuest Legends** on Apple Silicon — no CrossOver, no Parallels, no subscription.
Open-source **Wine + DXMT** (DirectX 11 → Metal). This repo gets a **fresh, from-scratch
install** working end-to-end — install → login → download → in-game — and adds
quality-of-life on top.

> **Verified in-game** on macOS 26.4.1 / Apple Silicon: fresh install → Daybreak login →
> 6.9 GB client download → `eqgame.exe` rendering through DXMT/Metal
> (`dbg.txt`: `CRender::InitDevice completed successfully`).
>
> 🔥 **Website / guide:** https://claude.ai/code/artifact/989e8c3d-40d8-4357-856d-397c89221b43

Built on [**osxEQL**](https://github.com/sowoky/osxEQL) by u/sowoky, [**DXMT**](https://github.com/3Shain/dxmt) by 3Shain, and **MoltenVK**. This is the layer on top: the fresh-install fixes + QoL.

## Why this exists

osxEQL is excellent at *playing* EQ Legends once the game is installed. But a **clean
first-time install** couldn't get from download to login — the launcher crashed before you
could sign in. It came down to three walls, and this repo clears all three automatically.

| Wall | What's wrong on a fresh install | Fix |
|---|---|---|
| **Runtime libs** | Wine tree ships no `libvulkan.1.dylib` (MoltenVK) or x86_64 FreeType; the CEF launcher needs Vulkan, Wine needs FreeType | drop x86_64 MoltenVK + freetype into `Contents/Resources/Wine/lib/` |
| **RPC service** | `rpcss` never starts → `RPC_S_SERVER_UNAVAILABLE` | start it before launch |
| **The bootstrapper** | First-run `LaunchPad.exe` loads Daybreak's `npdg` download plugin, which **crashes under Wine** — but first downloads the *real* CEF launcher into a mangled folder literally named `C:` | rename `Installed Games/C:` → `EverQuest Legends`, run the **real** launcher directly |

**Why nobody hit this before:** the author (and early users) already had the game installed
and run `eqgame` directly, so they never triggered the fresh-download bootstrapper crash.
osxEQL's own `STATUS.md` notes the cold end-to-end was never verified. This is that missing
first-run piece.

## Quickstart

**You provide:** an Apple Silicon Mac, a Daybreak / EQ Legends account, and the official
`EQLegends_setup.exe` — download it while logged in at [everquest.com](https://www.everquest.com)
(it's account-gated, so grab it yourself). **The script does the rest** — it installs Rosetta 2
and osxEQL.app for you; no manual setup.

```sh
git clone https://github.com/jkatsnelson/osxeql-qol && cd osxeql-qol
chmod +x eql-mac.sh

# one command: installs Rosetta + osxEQL, adds MoltenVK+FreeType, runs the installer,
# does the bootstrapper -> real-launcher hand-off, and opens the real login screen.
./eql-mac.sh setup ~/Downloads/EQLegends_setup.exe

# then: log in in the launcher window, let it download the ~6.9 GB client, and hit Play.
# (need to re-open it later? ./eql-mac.sh launch  —  tune display + open: ./eql-mac.sh play)
```

`eql-mac.sh` subcommands: `setup <installer>` · `launch` · `play` · `doctor`.
Keep your Mac awake during the download (the script pins `caffeinate`).

## What's in the box

| File | What it does |
|---|---|
| `eql-mac.sh` | **The flagship** — the whole fresh-install recipe in one command |
| `fix-runtime-libs.sh` | Fetches x86_64 MoltenVK + freetype + libpng into the Wine tree (`--revert` to undo) |
| `pimp-ui.sh` + `docs/UI-FIRST-LOGIN.md` | Clean **`default_modern` skin** + readable/windowed display, and a 5-minute first-login UI polish guide (maps, chat tabs, hotbars, brightness, Zeal notes) |
| `install-maps.sh` | Community maps installer — **note:** EQ Legends already bundles labeled, community-quality maps, so this is usually a no-op |
| `install-config.sh` + `apply-eqclient-tuning.py` | Sane `dxmt.conf` + CRLF/latin-1-safe `eqclient.ini` tuning |
| `doctor.sh` | Read-only health check (Rosetta, quarantine, the libs, prefix, disk, DXMT symbol) |
| `helpers/brightness.md` | The "it's SO DARK" guide — the in-engine **Enhanced Vision** slider works under DXMT; the old hardware-gamma slider doesn't |
| `helpers/install-stealthpointer.sh` | Fixes the macOS double-cursor (F1/F2) |
| `website.html` / `docs/` | The landing page (also deployable as GitHub Pages) |
| `drafts/` | Reddit post drafts; `UPSTREAM/` — PR drafts for osxEQL |

## Honest caveats

This is a community **workaround**, not an official port. It routes around a first-run DRM
bootstrapper that crashes under Wine — you still log into your own legitimate account and
download the real client from Daybreak. Things can break with game/macOS updates; keep the
Mac awake during the download; expect the occasional relaunch. Nothing here is cracked or
bypasses payment.

## Uninstall

```sh
./uninstall.sh                    # revert config/maps
./fix-runtime-libs.sh --revert    # remove the libs added to the app bundle
```

## Credits & license

MIT (see `LICENSE`). Deep thanks to **u/sowoky** (osxEQL), **3Shain** (DXMT), and the
**MoltenVK** team. Unofficial; not affiliated with Daybreak Game Company, Game Jawn,
CodeWeavers, or Apple. EverQuest is a trademark of Daybreak Game Company.
