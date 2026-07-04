# UI skins & readable text

At the default 1280×960 virtual desktop the stock UI is usually fine. If text is
too small on a large display, in order of effort:

1. **Chat text:** `/chatfontsize 7` (range 1–10, default 5). Our eqclient tuner
   sets `ChatFontSize=4` as a conservative default; bump it in-game to taste.

2. **Built-in UI scale:** Options window scale slider or `/ui scale`. **Only scales
   newly-converted windows** — most legacy XML UI is hardcoded, so this alone won't
   fix everything.

3. **Custom large-screen skin (the real fix):** download a skin built for high
   resolutions from <https://www.eqinterface.com> (e.g. a "grimGUI"-style skin),
   then:
   ```
   ./helpers/install-ui-skin.sh ~/Downloads/SomeSkin.zip SomeSkin
   ```
   In-game: `/loadskin SomeSkin 1`. The helper stages into the client's `uifiles/`
   (or under `qol/staged/uifiles/` until the game exists) and is fully reversible.

## Notes / honesty

- Skins are a taste + licensing choice, so this repo bundles none — you supply the
  zip/folder.
- **Untested against the EQ Legends build specifically.** EQL uses Daybreak's modern
  UI engine; most eqinterface skins target the same client family, but a given skin
  may only partially apply. If a skin misbehaves, `/loadskin default 1` reverts.
- Don't over-scale: a lower virtual-desktop resolution also enlarges the UI but
  softens the 3D — changing resolution means relaunching (osxEQL pins the window at
  launch).
