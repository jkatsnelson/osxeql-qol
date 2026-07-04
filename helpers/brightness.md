# Brightness / "it's SO DARK"

Classic-era EQ (which EQ Legends recreates, pre-Kunark) renders night and unlit
interiors near-black **on purpose**, gated by race night-vision. That is the game
working as designed — but here are the levers that actually work on the osxEQL
(Wine + DXMT) stack, in order of reliability.

## Do these, in order

1. **In-game engine controls (work windowed under DXMT).**
   Options → Display → **Advanced** → raise **"Enhanced Vision"** and toggle
   **"Use Advanced Lighting"** on/off to taste. These are shader-based, so unlike
   the old hardware-gamma slider they work regardless of fullscreen. Caveat from
   player reports: Enhanced Vision brightens dark *environments*, not the UI/sky;
   Advanced Lighting is hit-or-miss (can blow out the scene) — test both states.

2. **macOS-side brightness (most reliable Mac lever).**
   Raise system brightness (F1/F2 or Control Center). **Turn OFF Night Shift,
   True Tone, and auto-brightness** in System Settings → Displays — they warm and
   darken the panel and compound EQ's darkness.

3. **Lower fog** to brighten distances. In-game Options → Display fog/view sliders,
   or `FogScale` in eqclient.ini (our tuner sets `1.000000`; lower = less haze).

4. **Play the mechanic.** Carry a torch / lantern / Greater Lightstone / glowing
   item, or use a light spell. If you're picking a race, **Dark Elf = ultravision
   (best)**; any infravision race avoids the problem. Human/Barbarian/Erudite are
   night-blind by design.

## What NOT to rely on

- **`dxmt.conf` has no gamma/brightness key.** Don't look for one.
- **Old hardware `Gamma=` slider / `Gamma=` ini key.** Daybreak's DX11 port
  reportedly removed the hardware-gamma slider; even where a numeric `Gamma=` key
  exists, hardware gamma ramps only take effect in *exclusive* fullscreen, which
  Wine on macOS can't grant (you're windowed in a virtual desktop). Our tuner
  still sets `Gamma=1.8` **if the key is present** — harmless, but do not count on
  it. **Untested** which of these the EQL beta build actually exposes; open
  Options → Display → Advanced and use whatever is really there.

- **Disabling shaders** (`VertexShaders=0`, `*PixelShaders=0`) makes the world
  flat-bright but ugly. Last resort only; not recommended.
