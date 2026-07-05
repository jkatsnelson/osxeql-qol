# First-login UI — make Norrath look good

EQ's default UI is from 1999. A few minutes turns it into something clean and readable.
`./pimp-ui.sh` already did the part that lives in `eqclient.ini`; the rest is per-character
and takes 5 minutes in-game the first time.

## Already applied for you (`pimp-ui.sh`)
- **`default_modern` skin** — the stock modern layout (cleaner than `default`). EQ Legends
  ships three: `default`, `default_light`, `default_modern`. Switch anytime in-game with
  `/loadskin default_modern` (or `default`, `default_light`).
- **Windowed 1280×960** — no fullscreen-exclusive popup, mouse mapped 1:1.
- **Readable chat font + moderate particles.**
- **Maps:** EQ Legends already bundles labeled, community-quality maps — press **M**.

## The 5-minute in-game polish (per character)

Everything below saves automatically to `UI_<char>_<server>.ini` when you `/camp` or log out
cleanly, so you only do it once per character.

1. **UI scale** — `Options` (Alt+O) → **UI** tab → **UI Scale**. On a Retina panel bump it to
   ~**1.2–1.4** so windows aren't tiny. (Do this first; it resizes everything.)
2. **Map window** — press **M**. `/mapfilter` toggles POIs/labels; mouse-wheel zooms; it
   auto-follows you. Dock it in a corner and resize.
3. **Chat tabs** — right-click the chat window → **Add Tab** → make one for **Group/Guild**,
   one for **Combat**, one for **Main**. Right-click a tab → filters to route messages. Drag
   the edges to size; lock with the little padlock.
4. **Hotbars** — `/hotbutton` or open **Actions** (the button bar). You can have multiple
   bars — drag spells, disciplines, `/commands`, and social macros onto them. Pull a second
   bar out and stack it.
5. **Core windows** — drag **Target**, **Group**, **Buffs/Song window**, **Spell Gems**, and
   (if a caster/pet class) **Pet** somewhere sensible. Right-click a window title for
   background transparency + lock.
6. **Player window** — right-click it for **compact** vs. full; move your HP/mana/end bars up
   near your hotbars so you're not eye-darting.
7. **Brightness** (the classic "it's SO DARK" fix) — `Options` → **Display** → **Advanced** →
   raise **Enhanced Vision** and try **Advanced Lighting**. These are the shader-based
   controls that work under DXMT (the old hardware-gamma slider is dead under Wine). And yes —
   race night-vision + a torch/lantern still matter; that part's classic EQ by design.
8. **Lock it** — once it's arranged, `/loadskin default_modern 1` (the trailing `1` keeps your
   window positions). Log out cleanly so it saves.

## Want a totally custom look? (optional)
Third-party skins live at **eqinterface.com** (this client is Underfoot-era, so grab an
Underfoot/RoF-compatible UI). Install one by dropping its folder into
`…/Installed Games/EverQuest Legends/uifiles/<skinname>/`, then in-game: `/loadskin <skinname>`.
If a skin is missing a piece, EQ falls back to `default` for it — nothing breaks, and you can
always `/loadskin default_modern` to revert.

## Zeal — the big QoL mod (advanced / at your own risk)
[**Zeal**](https://github.com/iamclint/Zeal) is the modern EQ enhancement everyone uses on
live: in-game map overlay, nameplates, buff/cast timers, alarms, better camera, tells popups.
It's a genuine UI upgrade — **but read this first:**
- It's a **DLL injected into `eqgame`**. Under **Wine + DXMT it's untested** and could crash
  the client or fail to hook (Zeal targets the Windows DirectX client directly).
- **EQ Legends is a brand-new server.** Third-party software policy may differ from live EQ —
  **check the EQ Legends / Game Jawn rules before using anything injected**, so you don't risk
  your account.
- If you try it anyway: put `Zeal.dll` in the game folder and add it via `WINEDLLOVERRIDES`
  or a d3d9 proxy, then watch `dbg.txt`. Treat it as experimental until someone confirms it
  works on this stack — I didn't ship an installer for it precisely because it's unverified
  here.

TL;DR: `default_modern` + the layout above gets you 90% of the way with zero risk. Zeal is the
spicy 10% — worth it eventually, but verify it's allowed and that it hooks under DXMT first.
