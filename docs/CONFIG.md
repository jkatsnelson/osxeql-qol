# CONFIG — `dxmt.conf` + `eqclient.ini` tuning

Two safe, reversible tweaks that make EverQuest Legends run and read better under
osxEQL (Wine + DXMT) on Apple Silicon. Neither runs wine; neither touches the app
bundle. Install both with `./install-config.sh` (or the umbrella `./install.sh`).

- **`dxmt.conf`** → the DXMT (D3D11→Metal) renderer's config, dropped next to
  `eqgame.exe` in the EQ Legends install dir.
- **`apply-eqclient-tuning.py`** → CRLF/latin-1-safe, idempotent tuning of
  `eqclient.ini` (only exists after your first clean logout).

---

## `dxmt.conf`

DXMT reads `$PWD/dxmt.conf`. osxEQL's launcher `cd`s into the game dir before
launch, so the file lives at:

```
$OSXEQL_HOME/prefix/drive_c/users/Public/Daybreak Game Company/Installed Games/EverQuest Legends/dxmt.conf
```

`install-config.sh` copies it there. If the game isn't downloaded yet it stages
the file at `$OSXEQL_HOME/qol/staged/dxmt.conf`; the next `./install.sh` copies
it into the game dir the moment that dir appears ("copy-on-present"). DXMT
re-reads the file at **each launch** — there is no live reload, so relaunch after
editing.

### Defaults we ship (all safe)

| key | value | why |
|---|---|---|
| `d3d11.preferredMaxFrameRate` | `60` | Metal/CoreAnimation frame pacing. Only hits refresh-rate divisors — pick a clean divisor of your panel (60 or 30; 120/60 on a 120 Hz display). `0` = uncapped. 60 keeps a fanless Mac cool. |
| `dxmt.shaderMetalVersion` | `320` | Metal 3.2 (macOS 15+). macOS 26 supports it. `310` = Metal 3.1 (macOS 14). Omit the line to let DXMT auto-pick the newest supported. |
| `dxgi.handleAltTab` | `True` | Let DXMT handle cmd/alt+tab inside the Wine virtual desktop (Wine can't natively). |

### Situational keys (shipped commented — enable only for the symptom)

| key | when to enable |
|---|---|
| `d3d11.maxFeatureLevel = 11_1` | EQ is an old D3D11 engine; if you see 12_x-path glitches, cap to `11_1` (or `11_0`) for stability. |
| `d3d11.defuseFma = True` | shimmering / precision artifacts. |
| `d3d11.ignoreMapFlagNoWait = True` | client throws `DXGI_ERROR_WAS_STILL_DRAWING` / hitches on Map. |
| `d3d11.metalSpatialUpscaleFactor = 1.5` | MetalFX spatial upscaling. **Inert** unless you also set env `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` in the launcher. |

### There is no gamma/brightness key in DXMT

Don't look for one — DXMT has none. On this DX11 client the darkness lever is
**in-game Options → Display → Advanced** ("Enhanced Vision" slider + "Advanced
Lighting" toggle, both shader-based so they work under Wine regardless of
fullscreen) plus macOS display brightness. See `helpers/brightness.md`.

### Related launcher env (out of scope for this file)

`WINEMSYNC=1` (Mach-semaphore sync) is the correct low-overhead sync primitive
for this CrossOver-derived Wine and would reduce CPU overhead — but it's a
**launcher env var**, not a `dxmt.conf` key, so it belongs in the app launcher
(app-owned; this repo doesn't edit the bundle). `WINEESYNC` is Linux-only and
does nothing on macOS.

---

## `eqclient.ini` tuning

`eqclient.ini` is **CRLF line endings + latin-1/Windows-1252**, and only exists
after your first clean logout (the client writes it on exit). `sed`/regex without
`\r` silently no-op on it, and a UTF-8 re-encode corrupts its high bytes — so this
is a Python tool that reads bytes, decodes latin-1, edits, and re-encodes latin-1.
Every byte round-trips; no BOM is ever added; each line keeps its own CR.

### Run it

```sh
# default: the eqclient.ini under $OSXEQL_HOME (prints a "log in first" note if absent)
./apply-eqclient-tuning.py

# explicit path / dry run / also create the few keys we're certain of
./apply-eqclient-tuning.py "<path>/eqclient.ini"
./apply-eqclient-tuning.py "<path>/eqclient.ini" --dry-run
./apply-eqclient-tuning.py "<path>/eqclient.ini" --add-missing
```

`install-config.sh` and `install.sh` call it for you once the ini exists.

### Safety model

- **Modify-if-present by default.** We never inject a key the client build doesn't
  already emit. A key that's absent is reported ("set in-game") and left alone.
- **Format-preserving.** When a key is present we match its existing shape
  (integer vs float-with-N-decimals vs `TRUE`/`FALSE`) so we never change the
  client's on-disk format or value range. A value in a shape we don't recognize is
  **skipped, not overwritten** (e.g. a `Gamma` stored as a bare int, or a boolean
  stored as `0/1`).
- **Launcher-owned keys are off-limits.** We never touch `Fullscreen`, `Width`,
  `Height`, `WindowedWidth`, `WindowedHeight` — the osxEQL launcher pins those to
  the virtual-desktop size on every launch, and mouse input desyncs if they
  disagree (project gotcha #4).
- **Backed up once** to `eqclient.ini.qol-bak` before the first edit (the suffix
  `uninstall.sh` restores from). **Idempotent** — run it as many times as you like;
  re-running after a play session re-applies the template (the client resets keys
  on logout).

### Keys we tune (when present)

| key | target | note |
|---|---|---|
| `MaxFPS` | `60` | foreground frame cap (cool, quiet, plenty for EQ). *Also added by `--add-missing`.* |
| `MaxBGFPS` | `30` | background frame cap (heat/battery when unfocused). *Also added by `--add-missing`.* |
| `Gamma` | `1.5` | brightness-adjacent. Usually **absent** on the DX11 client (removed in favor of Enhanced Vision) → simply skipped. |
| `ShowDynamicLights` | `TRUE` | render dynamic light sources (torches/spells help you see in the dark). |
| `SpellParticleDensity` | half | moderate density. Half of the detected range (`50` for 0-100 ints, `0.5` for 0-1 floats). |
| `EnvironmentParticleDensity` | half | moderate density. |
| `ActorParticleDensity` | half | moderate density. |

`--add-missing` only creates `MaxFPS`/`MaxBGFPS` (inside `[Defaults]`) — the only
keys whose exact name, section, and format we're certain of without the real file
in front of us. It never invents speculative keys.

### Do these in-game instead (not reliable `eqclient.ini` keys)

- **Readable chat text:** `/chatfontsize 7` (range 1-10; default 5). Chat font is
  per-window UI state, not a stable `eqclient.ini` key.
- **Draw distance / FPS:** Options → Display **Clip Plane** slider (21 levels). The
  slider-to-ini mapping isn't safely editable blind, so tune it live.
- **Darkness:** Options → Display → Advanced → **Enhanced Vision** + **Advanced
  Lighting** (see above). Raise macOS brightness; turn off Night Shift/True Tone.
- **Blocky textures / stutter (DX11):** Texture Quality **Low**, Mip Mapping
  **off**, "least memory usage"; and the `Memory512.ini` + `GraphicsMemoryMode=2`
  fix documented by the EQ community.
- **Models:** Options → Display per-race/sex "Load … Model" checkboxes (Luclin vs
  classic).

---

## Uninstall / revert

`./uninstall.sh` restores `eqclient.ini` from `eqclient.ini.qol-bak` and removes the
`dxmt.conf` we added (per the manifest). `--purge` also clears staging. The client
rewriting `eqclient.ini` on logout is normal — re-run `install-config.sh` to
re-apply.

## Test

`./test/test-config.sh` proves byte-safety (CRLF + Windows-1252 high bytes
preserved, no BOM), idempotency, one-time backup, launcher-key protection,
`dxmt.conf` parsing, and `install-config.sh` stage/copy behavior — all against a
synthetic fixture in a scratch dir, nothing under wine.
