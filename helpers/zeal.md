# Zeal under osxEQL (Wine + DXMT) — assessment

**Short answer: experimental / likely-broken. This repo does NOT install Zeal.**
Treat it as an opt-in experiment you do at your own risk, not a supported QoL step.

## What Zeal is

[Zeal](https://github.com/iamclint/Zeal) is a client-side mod for the live Daybreak
EverQuest client. It ships as a DLL (historically loaded as a proxy / injected into
`eqgame.exe`) that hooks the game's DirectX device and DirectInput and draws an
ImGui overlay (nameplate tweaks, maps, tells, buff timers, etc.).

## Why it is unlikely to work cleanly here

1. **It hooks the D3D device to draw its overlay.** On this stack the "D3D11 device"
   is **DXMT translating to Metal**. Zeal's present/overlay hooks expect a real
   D3D device it can render into; against DXMT's implementation those hooks may
   no-op, render nothing, or crash the client. This is the single biggest risk.
2. **Injection under Wine is fragile.** Proxy-DLL / injected-ASI loading depends on
   Wine's loader honoring the same search/override behavior the mod assumes;
   `WINEDLLOVERRIDES` juggling can destabilize the launch, and osxEQL's launcher
   is tuned for a clean one-shot start.
3. **EQ Legends is a NEW, separate client build.** Zeal targets live EQ's binary
   layout/offsets. Even on native Windows, a mod pinned to live-EQ builds is not
   guaranteed to match the Legends client. Memory-offset features would need
   Legends-specific support that may not exist.

## Honest verdict

- **Not verified** on osxEQL by this repo — no end-to-end test was run.
- Overlay/rendering features: **expected to fail or crash** under DXMT.
- The safer QoL wins that overlap with Zeal's value are already covered here:
  community **maps** (`install-maps.sh`), a readable **UI skin**
  (`install-ui-skin.sh`), **StealthPointer** for the cursor, and eqclient tuning.
- If you still want to try it: do it on a throwaway launch, keep a backup of the
  prefix, and never `wineserver -k` to recover — quit cleanly and relaunch.
