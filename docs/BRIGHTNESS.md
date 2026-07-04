# Brightness — "it's SO DARK, what do I do"

The definitive guide for EverQuest Legends on Mac via
[osxEQL](https://github.com/sowoky/osxEQL) (Wine + DXMT). Read the first section
once so you know *why* the obvious fix (the old gamma slider) does nothing here,
then use the ordered checklist.

---

## TL;DR

1. In-game: **Options → Display → Advanced → raise "Enhanced Vision"**, and try
   the **"Use Advanced Lighting"** toggle. This is the real brightness lever on
   this stack.
2. macOS: raise system brightness, and turn **Night Shift / True Tone /
   auto-brightness OFF**.
3. Lower fog (in-game fog/view sliders).
4. If you're still in the dark, that's the **game working as designed** — carry a
   torch/lantern/lightstone, or roll a night-vision race (**Dark Elf = ultravision**).

Do **not** hunt for a gamma slider in `dxmt.conf` (there isn't one) and don't count
on the classic in-game hardware-gamma slider (it's a no-op under Wine — see below).

---

## Why it's dark: two causes, and they stack

**(1) It's a deliberate game mechanic — the authentic part.**
EQ Legends recreates the pre-Kunark classic era, where night and unlit interiors
render near-black *on purpose*, gated by **race night-vision**:

- **Night-blind (see nothing in the dark):** Human, Barbarian, Erudite (Kerran too,
  per the EQL wiki). These races were *designed* to carry a light source.
- **Infravision (mobs glow reddish; modest help):** most non-human races — Dwarf,
  Gnome, Half-Elf, Halfling, High Elf, Wood Elf, Iksar, Ogre, Troll.
- **Ultravision (bright, purple-tinted, cuts through fog — the best):** **Dark Elf**
  (Froglok in some data). Note the common mix-up: a Dark Elf's edge is *ultra*vision,
  not infravision.

So a Human standing in Nektulos at night with no torch being unable to see is not a
bug — it's 1999. EQ Legends **keeps** this mechanic intact; light sources still
matter.

**(2) The classic way players cheated the dark doesn't work under Wine — the real
translation-layer limitation.**
The old fix was the in-game **Gamma slider**, which drove **hardware gamma ramps**
(`SetDeviceGammaRamp` / DXGI `SetGammaControl`). Two well-documented facts make that
a dead end on this stack:

- Hardware gamma only takes effect in **true exclusive fullscreen**. Even on native
  Windows, the EQ gamma slider is a no-op in windowed/borderless mode.
- osxEQL runs the game **windowed inside a Wine virtual desktop** (it must —
  exclusive fullscreen under Wine causes black-screen / mouse-desync). So the
  hardware-gamma path is off the table.

On top of that, Daybreak's 2025 **DirectX 11 API port removed the old hardware-gamma
slider** and replaced it with the shader-based **Enhanced Vision** control described
below. Players report the game got *darker* after that port. Because EQ Legends runs
that DX11 client (which is exactly why the stack uses DXMT = D3D11→Metal), the
Enhanced-Vision control — not the old gamma trick — is the correct lever.

> **Bottom line:** EQ Legends is *gentler and more adjustable* than an old
> Project-1999 Titanium client because the modern client gives you engine-side
> brightness controls. But the darkness mechanic itself is unchanged. Adjust it with
> the tools that actually work under Wine/DXMT, listed next.

---

## Fix it now — in order of reliability

### 1. In-engine "Enhanced Vision" (the correct lever) — works windowed

**Options → Display → Advanced.** Raise the **"Enhanced Vision"** brightness slider,
and toggle **"Use Advanced Lighting"** on and off to compare. These are rendered
**in-engine** (shader-based), not via hardware gamma ramps, so they work under
Wine/DXMT regardless of fullscreen state.

Caveats reported by players (worth knowing so you don't chase ghosts):

- Enhanced Vision brightens **dark environments**, but **not** the UI or the sky.
- Advanced Lighting is hit-or-miss — sometimes it does little, sometimes it blows out
  the scene. Test both states in an actually-dark zone at night.

### 2. macOS display brightness (the most reliable Mac-side lever)

This one doesn't depend on any gamma passthrough, so it always helps:

- Raise system brightness (F1/F2 or Control Center).
- **System Settings → Displays:** turn **Night Shift OFF**, **True Tone OFF**, and
  **auto-brightness OFF**. All three warm/darken the panel and *compound* EQ's
  darkness.

### 3. Lower fog to brighten the distance

Less haze = brighter, farther view. In-game: **Options → Display** fog/view-distance
sliders. In `eqclient.ini` the key is `FogScale` (the osxeql-qol tuner sets
`1.000000`; lower it for less haze). Safe and effective, and unlike gamma it actually
takes effect.

### 4. Play the mechanic (addresses the real cause)

- **Carry a light source:** torch, lantern, Greater/Lesser Lightstone, a glowing
  item (froglok crown, etc.), or a light spell. This is the intended answer for
  night-blind races.
- **Picking a race?** **Dark Elf** gets ultravision (the best), and any infravision
  race avoids the worst of it. Human / Barbarian / Erudite are night-blind by design
  — expect the dark if you roll one and don't carry a light.

---

## What NOT to rely on

- **`dxmt.conf` has no gamma or brightness key.** Don't look for one — DXMT's options
  are device-id spoofing, frame-rate, shader/feature-level, and alt-tab handling
  only.
- **The classic in-game hardware `Gamma` slider (and any `Gamma=` INI key).** The
  DX11 client reportedly removed the slider; even where a numeric `Gamma=` key
  survives, hardware gamma only takes effect in exclusive fullscreen, which you
  cannot get under Wine. The osxeql-qol tuner may still write `Gamma=1.8` *if the key
  is present* — harmless, but do not count on it doing anything.
- **CrossOver's `AllowGamma` trick** (`defaults write com.codeweavers.CrossOver
  AllowGamma always`). That re-enables hardware-gamma passthrough **in CrossOver
  bottles only**. osxEQL is a raw Wine bottle — there is no equivalent knob, so this
  does nothing here.
- **Disabling shaders** (`VertexShaders=0`, `*PixelShaders=0`) makes the world
  uniformly flat-bright but ugly and unlit. Last resort only; not recommended.

---

## Honesty / what's unverified

- The exact brightness control the **EQL beta build** ships (a shader "Enhanced
  Vision" slider vs. a legacy `Gamma=` key + "Enable gamma windowmode" checkbox)
  could not be verified against the live client during research — the sources
  disagree. The practical move is the same either way: **open Options → Display →
  Advanced and use whatever brightness control is actually there**, and treat the
  hardware-gamma path as dead under Wine.
- Enhanced Vision / Advanced Lighting behavior "under DXMT specifically" is from
  player reports on the main-game DX11 port (same client tech), not a direct test on
  osxEQL.

## Sources

- Race night-vision (classic): <https://wiki.project1999.com/Character_Races>,
  <https://everquest.allakhazam.com/wiki/EQ:Infravision>
- Race night-vision retained in EQL: <https://eqlwiki.com/Character_Races>
- DX11 port removed the gamma slider, added Enhanced Vision + Advanced Lighting:
  <https://forums.daybreakgames.com/eq/index.php?threads/bring-gamma-back-please.295600/>,
  <https://bhagpuss.blogspot.com/2020/07/change-my-gamma-everquest.html>
- Hardware gamma only in exclusive fullscreen:
  <https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgioutput-setgammacontrol>,
  <https://www.redguides.com/community/threads/unable-to-adjust-gamma-setting.36688/>
- DXMT config has no gamma key: <https://github.com/3Shain/dxmt/blob/main/dxmt.conf>
- CrossOver-only AllowGamma: <https://www.codeweavers.com/compatibility/crossover/forum/everquest>
