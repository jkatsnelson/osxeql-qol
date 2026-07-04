# Reddit posts — drafts (review before posting)

> Placeholder repo URL used throughout: `https://github.com/jkatsnelson/osxeql-qol` — confirm before posting.
> Nothing here has been posted. These are drafts for you to review and send yourself.

---

## Draft 1 — Reply to u/sowoky's r/EQLegends thread
*(thread: "created something so you can play EQL on mac OSX without paying for crossover")*

This is awesome, thank you for building osxEQL — Wine-from-LGPL-source + 3Shain's DXMT with zero CrossOver is exactly the right approach, and playing on it feels great.

Small thing I ran into and figured I'd share back: on a totally FRESH install (no game files yet), vanilla osxEQL couldn't get me from download to login. Tracked it to three gaps:

1. The bundled Wine/lib was missing `libvulkan.1.dylib` (MoltenVK) and an x86_64 `libfreetype` — the CEF launcher needs Vulkan, Wine needs FreeType.
2. `rpcss` wasn't getting started, so RPC errors on launch.
3. The big one: first-run `LaunchPad.exe` is a bootstrapper that loads Daybreak's "npdg" download plugin, which crashes under Wine (`RPC_S_SERVER_UNAVAILABLE`). But before it dies it downloads the REAL CEF launcher into a mangled path — a literal folder named `C:` under `Installed Games/` (a Wine path-handling bug). Rename that folder to `EverQuest Legends` and run the real launcher directly, and it renders the actual login, downloads the ~6.9 GB client, and `eqgame.exe` comes up through DXMT/Metal. Verified in-game.

Makes sense nobody hit this — you (and most people) already had the game installed and ran `eqgame` directly, so the fresh-download bootstrapper crash never came up. Your STATUS.md even notes the cold end-to-end wasn't verified, so this is just the missing first-run piece.

I packaged the fixes + some QoL (community maps, brightness/Enhanced-Vision notes, StealthPointer for the double-cursor, a `doctor.sh` health check) into a one-command script here: https://github.com/jkatsnelson/osxeql-qol — all credit to you, 3Shain (DXMT), and MoltenVK. Cheers!

---

## Draft 2 — Standalone r/EQLegends post

**Title:** Play EQ Legends on your Mac, free & native — full fresh-install guide + tools (Apple Silicon, no CrossOver)

Short version: you can now install EQ Legends from scratch on an Apple Silicon Mac and play it natively — no CrossOver, no license fee. This builds directly on u/sowoky's excellent osxEQL. I got the cold, first-time install-and-download path working end to end and packaged the fixes + some quality-of-life extras.

This is unofficial and not affiliated with Daybreak Game Company or Game Jawn.

### What it's built on
- **osxEQL** by u/sowoky — Wine (built from CrossOver's LGPL source) + **DXMT** (DirectX 11 → Metal, by 3Shain) + **MoltenVK**. All the hard work is theirs. osxEQL is great for playing once the game is installed.
- The gap I filled: a *fresh* install couldn't get from download to login. My repo automates the fix.

### Requirements
- Apple Silicon Mac (M1 or newer)
- macOS 13+ (tested on 26.4)
- Rosetta 2 installed
- A Daybreak / EQ Legends account + the official `EQLegends_setup.exe`
- ~10 GB free disk space

### Quickstart (one command)
```
git clone https://github.com/jkatsnelson/osxeql-qol
cd osxeql-qol
./eql-mac.sh setup ~/Downloads/EQLegends_setup.exe
```
It adds the missing libs, runs the installer, does the bootstrap bypass, and launches you to the real login screen. Log in → it downloads the ~6.9 GB client → hit Play → you're in.

### What it actually fixes
On a clean install, vanilla osxEQL hits three walls. The script handles all three:

1. **Missing libraries** — the bundled Wine/lib is missing `libvulkan.1.dylib` (MoltenVK) and an x86_64 `libfreetype`. The CEF launcher needs Vulkan; Wine needs FreeType. Script drops both into `Contents/Resources/Wine/lib/`.
2. **rpcss not started** — causes RPC errors. Script starts it before launch.
3. **The bootstrapper crash (the real blocker)** — first-run `LaunchPad.exe` is a bootstrapper that loads Daybreak's "npdg" download plugin, which crashes under Wine (`RPC_S_SERVER_UNAVAILABLE`). But before crashing it downloads the *real* CEF launcher into a mangled path: a literal folder named `C:` under `Installed Games/` (a Wine path-handling bug). The fix: rename that folder to `EverQuest Legends` and run the real launcher directly, skipping the crashy bootstrapper. Then the genuine Daybreak/Game Jawn login renders, the client downloads, and `eqgame.exe` renders via DXMT/Metal (`dbg.txt`: "CRender::InitDevice completed successfully"). Verified in-game.

**Why nobody hit this before:** u/sowoky and most early users already had the game installed and ran `eqgame` directly, so they never triggered the fresh-download bootstrapper crash. osxEQL's own STATUS.md notes the cold end-to-end (fresh login + download) was never verified — so this is the missing first-run piece for everyone starting clean.

### Quality-of-life extras
- **Community maps** (Brewall / Good) dropped in for you
- **Brightness guide** — the old hardware-gamma slider is dead under Wine, but EQ Legends' DX11 client has an in-engine "Enhanced Vision" slider under **Options → Display → Advanced** that works fine under DXMT. Classic race night-vision + light sources still apply.
- **StealthPointer** to deal with the macOS double-cursor
- A tuned `dxmt.conf`
- **`doctor.sh`** health check to catch a broken setup fast

### Honest caveats
- This is a **workaround**, not an official port. Things can break with game or macOS updates.
- It involves bypassing the first-run DRM bootstrapper (which crashes under Wine). You still log into your own legitimate account and download the real client from Daybreak.
- **Keep your Mac awake** during the ~6.9 GB download — sleep can interrupt it.
- You need a legit account and the official installer. This doesn't get you the game for free — it gets you playing on native Apple Silicon for free.

### Credits
Huge thanks to **u/sowoky** (osxEQL), **3Shain** (DXMT), and the **MoltenVK** team. I just found and smoothed over the fresh-install rough edges and bundled some conveniences.

Repo: https://github.com/jkatsnelson/osxeql-qol

Happy to help troubleshoot in the comments — post your `doctor.sh` output if you get stuck.

---

## Draft 3 — r/macgaming crosspost

**Title:** EverQuest Legends now runs natively on Apple Silicon — fresh install, free, no CrossOver

For any Mac EQ players (or the EQ-curious): EverQuest Legends now runs natively on Apple Silicon with a clean, from-scratch install — no CrossOver, no license fee.

It's built on u/sowoky's **osxEQL** (Wine from CrossOver's LGPL source + **3Shain's DXMT**, DirectX 11 → Metal, + **MoltenVK**). osxEQL already ran the game well once installed; the piece that was missing was the *first-time* install-and-download path, which hit a Wine bootstrapper crash. I tracked down the three issues (missing Vulkan/FreeType libs, rpcss not started, and a DRM bootstrapper that crashes but leaves the real launcher in a mangled `C:` folder) and packaged the fixes into a one-command script, plus QoL extras (community maps, a brightness/night-vision guide, StealthPointer for the double-cursor, a health-check script).

**Requirements:** Apple Silicon Mac, macOS 13+ (tested 26.4), Rosetta 2, a legit Daybreak/EQ Legends account + the official installer, ~10 GB free.

Full write-up and quickstart in my r/EQLegends post: [link once Draft 2 is live]

Repo: https://github.com/jkatsnelson/osxeql-qol

Unofficial; not affiliated with Daybreak or Game Jawn. All credit to sowoky, 3Shain, and MoltenVK — I just smoothed the fresh-install path.
