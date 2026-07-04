# UI & Cursor — double cursor, readable text, big-screen skins

Two different mouse problems get confused under Wine. Fix the right one:

| Symptom | Cause | Fix |
|---|---|---|
| **Two cursors** — the macOS arrow floats on top of the in-game cursor | The native macOS pointer draws over Wine's | **StealthPointer** (below) |
| **Clicks land off-target** — cursor is offset ~½ inch from where you point | `eqclient.ini` resolution ≠ the Wine virtual-desktop size | Handled automatically by osxEQL's launcher (`Fullscreen=0` + matched `Width/Height/WindowedWidth/WindowedHeight`). Don't fight it; don't resize the window mid-game. |

They're independent — you may need both.

---

## Double cursor → StealthPointer

[StealthPointer](https://github.com/Alien4042x/StealthPointer) is a tiny free macOS
menubar app that hides the native macOS cursor with a global hotkey, so only the
in-game cursor is visible:

- **F1** — hide the macOS cursor (do this once you're in-game)
- **F2** — show it again (for alt-tabbing back to macOS)

Both hotkeys are customizable in its menubar settings.

### Install

From the repo root:

```sh
./install-stealthpointer.sh
```

The script queries StealthPointer's latest GitHub release, verifies the download URL
resolves, downloads the `.dmg` to `~/Downloads`, and **opens it so you can drag
`StealthPointer.app` into Applications yourself**. It deliberately does **not**
auto-install into `/Applications` — you make that call. If the GitHub API can't be
reached it prints the releases page URL so you can grab it by hand.

After installing, launch StealthPointer, then grant it **Accessibility** permission
when macOS asks (System Settings → Privacy & Security → Accessibility) — global
hotkeys need it. Then F1 in-game.

> Verified during build: the latest release is **StealthPointer 1.0.3**, asset
> `StealthPointer.dmg` (~450 KB), and its download URL returns HTTP 200. The app is
> a normal signed-or-drag macOS app, not something injected into EQ.

### CrossOver alternative (not this stack)

If you were on CrossOver instead of osxEQL, the equivalent is Wine config → Graphics
tab → "Automatically capture mouse in full-screen." That doesn't apply to osxEQL's
raw Wine bottle — use StealthPointer.

---

## Readable text & big-screen UI

At the default **1280×960** virtual desktop the stock UI is usually fine. If text is
too small on a large/Retina display, in increasing order of effort:

### 1. Chat font size (easiest)

```
/chatfontsize 7
```

Range 1–10, default 5; 7–9 is comfortable on a big screen. (The osxeql-qol tuner
seeds a conservative `ChatFontSize=4` in `eqclient.ini`; override it live to taste.)
Right-click any chat window for its font / background / filter properties.

### 2. Built-in UI scale (partial)

The Options window has a UI-scale slider (also `/ui scale`). **It only scales the
newly-converted windows** — most of the legacy XML UI has element sizes hardcoded, so
this alone won't rescue everything at high resolution. Useful, not a cure.

### 3. Large-screen custom skin (the real fix)

Download a skin built for high resolutions from **eqinterface.com** (e.g. a
grimGUI-style skin by grimmier), then stage it with the helper:

```sh
./helpers/install-ui-skin.sh ~/Downloads/SomeSkin.zip SomeSkin
```

In-game:

```
/loadskin SomeSkin 1
```

To revert: `/loadskin default 1`. The helper drops the skin into the client's
`uifiles/` (or stages it under `qol/staged/uifiles/` until the game dir exists) and
is fully reversible.

### 4. Lower the effective resolution (blunt instrument)

A smaller virtual-desktop resolution enlarges *everything* but softens the 3D
(it's upscaled). osxEQL fixes the window size at launch, so changing resolution means
relaunching. Prefer the skin + chat-font route first.

---

## Notes / honesty

- **Skins are a taste + licensing choice, so this repo bundles none** — you supply
  the zip/folder. EQL uses Daybreak's modern UI engine; most eqinterface skins target
  the same client family, but a given skin may only partially apply. Untested against
  the EQL beta build specifically; if a skin misbehaves, `/loadskin default 1`
  reverts cleanly.
- **eqinterface.com blocks automated fetchers** (returns HTTP 403 to `curl`/bots), so
  its pages couldn't be auto-verified during build — but it's the long-standing
  canonical EQ UI-mod site and loads normally in a real browser.
- Don't over-scale. The point is legibility, not a giant UI.

## Sources

- StealthPointer: <https://github.com/Alien4042x/StealthPointer> (release verified
  HTTP 200 during build)
- macOS double-cursor context (CrossOver):
  <https://www.codeweavers.com/compatibility/crossover/tips/king-of-seas/macos-cursor-overlays-in-game-cursor>
- UI scaling is partial / use `/chatfontsize` + custom skin:
  <https://www.redguides.com/community/threads/interface-scaling-my-eyes-are-killing-me.92716/>,
  <https://www.everquest.com/news/eq-new-ui-engine-launch>
- Custom skins: <https://www.eqinterface.com> (403 to bots; live in a browser)
