# Zeal on EverQuest Legends via osxEQL — honest assessment

**Verdict: don't. This repo does NOT ship a Zeal installer, and you should not try
Zeal on EverQuest Legends.** Not primarily because of Wine/DXMT — because Zeal targets
a *different game client* and EQ Legends is an *official commercial server* where
injecting a memory-reading DLL risks a ban. If you still want to experiment, the
"how you would try it, and why it will probably fail" section is at the bottom. This
is an EXPERIMENTAL / NEGATIVE assessment, cited.

---

## What Zeal actually is

[Zeal](https://github.com/CoastalRedwood/Zeal) is a client-side quality-of-life mod
for EverQuest. Key facts, from its own docs:

- It targets **the legacy (2002) "Titanium"-era EverQuest client** used by
  **Project Quarm** and **TAKP** (The Al'Kabor Project) players. These are
  **third-party EQEMU *emulator* servers**, not Daybreak's official servers.
- It loads by **injection**: a DLL renamed with the **`.asi`** extension is dropped in
  the EQ root directory and loaded via the old client's Miles Sound System / ASI
  plugin mechanism. It then patches into the client's render/processing loop.
- It **hooks the client's DirectX (DirectX-9-era) rendering and DirectInput** to draw
  an in-process overlay.
- Features: an **integrated map** with zoom/markers, camera/third-person improvements,
  custom keybinds, nameplate/gauge/loot-window tweaks, floating combat text, enhanced
  chat/tells, alarms/timers, etc.
- Its own docs note that **anti-virus scanners flag it** because of the injection
  method (expected for any DLL injector).

### Repo status (verified during build)

- The originally-cited **`github.com/iamclint/Zeal` now 404s** (both the web page and
  the GitHub API) — that repo has been moved or taken down.
- The **active, maintained continuation is
  [`CoastalRedwood/Zeal`](https://github.com/CoastalRedwood/Zeal)** (MIT, C++, latest
  release **v1.4.3**, published 2026-07-04). Its own description is literally
  *"Takp client qol tool"* — i.e. built for the TAKP emulator client, not EQ Legends.

---

## Why it does not fit EverQuest Legends — three independent blockers

**1. Wrong client entirely (the fundamental blocker).**
EQ Legends runs Daybreak's **modern 64-bit, DirectX 11** client — that is the whole
reason osxEQL uses **DXMT (D3D11→Metal)**. Zeal is built for the **32-bit,
DirectX-9-era 2002 Titanium** client. The two are completely different binaries:
different bitness, different DirectX version, different memory layout and function
offsets. Zeal's `.asi` loader, its D3D9/DirectInput hooks, and every memory-offset
feature it has are pinned to the Titanium binary. There is **nothing for it to attach
to** in `eqgame.exe` on EQ Legends — this failure is upstream of any Wine/DXMT
question.

**2. Even if the client matched, the graphics hook fights DXMT.**
Zeal draws its overlay by hooking the D3D device's present path. On this stack the
"D3D11 device" is **DXMT translating to Metal**. An injector expecting a real
Direct3D device to render into would, against DXMT's implementation, most likely
no-op, render nothing, or crash the client. This is the secondary risk that would
bite *if* blocker #1 somehow didn't.

**3. Wrong server type — real ban risk.**
Zeal is explicitly built and *sanctioned for specific emulator servers* (Project
Quarm allows it; TAKP). **EQ Legends is an official, paid, commercial Daybreak
product.** Injecting a DLL that reads and modifies the game client's memory on an
official server is squarely the kind of third-party software that commercial MMO
EULAs prohibit, and it carries a genuine **account-ban risk**. Don't run an emulator
mod on a live retail account.

---

## And you probably don't even want it here

Zeal's single biggest draw is that it **adds maps to a client that has none** —
classic EQ shipped without in-game maps, which is why the emulator community built
Zeal and the Brewall/Good map packs.

**EQ Legends already has in-game maps** ("Compact Maps," with a selectable map-source
directory) baked into its modern client. So the headline reason to want Zeal is
already solved natively. The other QoL wins that overlap with Zeal are covered by
this repo or the base game:

- **Maps** → EQL's built-in Compact Maps, plus community map packs via this repo's
  `install-maps.sh` (drop into the client's `maps/` folder).
- **Readable UI / big-screen skins** → see [`UI-AND-CURSOR.md`](UI-AND-CURSOR.md).
- **Double cursor** → StealthPointer (see the same doc).
- **Brightness** → see [`BRIGHTNESS.md`](BRIGHTNESS.md).

---

## If you insist on experimenting (do this at your own risk)

Documented for completeness — **expected outcome: it won't attach, or it'll crash,
and you're risking your account.** No installer is shipped for exactly these reasons.

1. **Accept the ban risk.** This is an official Daybreak server. Assume a
   memory-injecting mod can get you flagged. Use a throwaway/expendable stance, never
   your main.
2. **Back up the prefix first.** Copy
   `~/Library/Application Support/osxEQL/prefix/` somewhere safe so you can restore.
3. **Understand it likely can't even load.** The `.asi` mechanism and Zeal's offsets
   assume the Titanium client. On EQ Legends' D3D11 64-bit client there is no correct
   place for it to hook. Do not expect the overlay to appear.
4. **Never `wineserver -k` to recover.** If a launch hangs, quit cleanly and relaunch
   — killing wineserver can corrupt the bottle (a documented osxEQL footgun).
5. **Watch for launcher instability.** Injection under Wine leans on
   `WINEDLLOVERRIDES` / loader behavior that osxEQL's clean one-shot launch is not
   tuned for; expect it to destabilize the start.

---

## Honesty / what's unverified

- **Not tested on osxEQL.** No end-to-end attempt was run (and shouldn't be, on a live
  account). The blockers above are reasoned from Zeal's documented target client +
  injection model vs. EQ Legends' known modern D3D11 client, not from a live trial.
- The `iamclint/Zeal → CoastalRedwood/Zeal` handoff was confirmed by GitHub API +
  live HTTP checks during build; the technical details are from Zeal's own readme.
- Whether Daybreak actively runs anti-cheat that would *detect* an injector on EQ
  Legends is unconfirmed — but a EULA violation + ban risk stands regardless of
  detection.

## Sources

- Active Zeal repo (verified HTTP 200): <https://github.com/CoastalRedwood/Zeal>
  (MIT, v1.4.3, "Takp client qol tool")
- Original `iamclint/Zeal` — now **404** (moved/removed), verified during build.
- Zeal readme — target client (legacy 2002 Titanium), `.asi` injection, features,
  Quarm/TAKP emulator servers, AV-flagging (verified HTTP 200):
  <https://quarm.guide/2024/11/24/zeal-readme/>
- Third-party programs for Project Quarm (context that Zeal is an emulator-server
  tool, verified HTTP 200): <https://quarm.guide/third-party-programs>
- Zeal distributed for Quarm via EQ UI site:
  <https://www.eqinterface.com/downloads/fileinfo.php?id=6960> (403 to bots; live in a
  browser)
- EQ Legends uses the modern 64-bit DirectX 11 client (why DXMT is used):
  <https://www.eqprogression.com/legends/faq/>,
  <https://www.everquest.com/news/eq-directx11-api-port-live>
- EQ Legends has in-game Compact Maps natively: <https://eqlwiki.com/index.php/Main_Page>
