#!/usr/bin/env python3
"""apply-eqclient-tuning.py — CRLF/latin-1-safe, idempotent eqclient.ini tuning.

EQ's eqclient.ini is CRLF line endings + latin-1/Windows-1252. sed/regex without
\\r silently no-op, and a UTF-8 re-encode corrupts the Windows-1252 bytes, so we
do the byte-safe dance the osxEQL launcher does: read bytes, decode latin-1,
rewrite in place, encode latin-1. latin-1 is a total 1:1 byte codec, so every
byte (including 0x80-0x9F Windows-1252 punctuation) round-trips untouched; we only
ever match/replace ASCII key names and ASCII values. No BOM is ever written and
each line keeps its own CR.

SAFETY MODEL
  * DEFAULT = modify-if-present only. We never inject a key the client build does
    not already emit. A key absent from your generated ini is reported and left
    for you to set in-game (some are UI/character state, not eqclient.ini keys).
  * Format-preserving: when a key IS present we match the value's existing shape
    (int vs float-with-N-decimals vs TRUE/FALSE) so we never corrupt the client's
    on-disk format or its value range. A value whose format we don't recognize is
    skipped, not overwritten.
  * We deliberately DO NOT touch Fullscreen / Width / Height / WindowedWidth /
    WindowedHeight — the osxEQL launcher pins those to the virtual desktop on
    every launch and mouse input desyncs if they disagree (project gotcha #4).
  * A one-time backup is written to <ini>.qol-bak before the first edit. This is
    the suffix uninstall.sh / doctor.sh / lib/common.sh key off of.
  * The client rewrites eqclient.ini on clean logout, so re-run this after a play
    session if you want the template values back. It is fully idempotent.

GRACEFUL DEGRADATION
  * With no path arg we compute the eqclient.ini under $OSXEQL_HOME (mirroring the
    launcher's prefix detection). If it does not exist yet (game not downloaded /
    never logged in), we print a "log in first" note and exit 0 — not an error.

USAGE
  apply-eqclient-tuning.py [path/to/eqclient.ini] [--add-missing] [--dry-run]
    (no path) -> default eqclient.ini under $OSXEQL_HOME
    --add-missing  create the small set of keys we are certain of (MaxFPS/MaxBGFPS)
                   inside [Defaults] if absent; never invents speculative keys.
    --dry-run      report the plan, write nothing (no backup either).
"""
import os
import re
import sys


class T:
    """A tuning target. kind drives how the value is formatted on write."""
    __slots__ = ("kind", "value", "add_ok", "why")

    def __init__(self, kind, value, add_ok, why):
        self.kind = kind      # "int" | "float" | "bool" | "ratio"
        self.value = value    # semantic target (ratio is a 0..1 fraction)
        self.add_ok = add_ok  # may be CREATED under --add-missing
        self.why = why


# Curated, conservative QoL set. Only MaxFPS/MaxBGFPS are add_ok (we know their
# name, [Defaults] section, and integer format). Everything else is
# modify-if-present: applied only if the client already wrote the key, in the
# format the client used. Clip-plane and chat-font live in-game (see docs/CONFIG.md).
TUNING = {
    "MaxFPS":                     T("int",   60,   True,  "cap foreground FPS (cool, quiet, plenty for EQ)"),
    "MaxBGFPS":                   T("int",   30,   True,  "cap background FPS (saves heat/battery when unfocused)"),
    "Gamma":                      T("float", 1.5,  False, "brightness-adjacent; usually absent on the DX11 client"),
    "ShowDynamicLights":          T("bool",  True, False, "render dynamic light sources (torches/spells help in the dark)"),
    "SpellParticleDensity":       T("ratio", 0.5,  False, "moderate spell particle density"),
    "EnvironmentParticleDensity": T("ratio", 0.5,  False, "moderate environment particle density"),
    "ActorParticleDensity":       T("ratio", 0.5,  False, "moderate actor particle density"),
}

# Keys the launcher owns; we refuse to touch them even if asked.
PROTECTED = {"Fullscreen", "Width", "Height", "WindowedWidth", "WindowedHeight"}

ADD_SECTION = "Defaults"  # EQ's main key section; where add_ok keys are inserted

INT_RE = re.compile(r"^-?\d+$")
FLOAT_RE = re.compile(r"^-?\d+\.\d+$")
BOOL_RE = re.compile(r"^(TRUE|FALSE)$", re.I)


def _decimals(s):
    return len(s.split(".", 1)[1]) if "." in s else 6


def coerce(t, existing):
    """Format t's target to match `existing`'s shape. Return str, or None to skip."""
    e = existing.strip()
    if t.kind == "int":
        if INT_RE.match(e):
            return str(int(t.value))
        if FLOAT_RE.match(e):
            return format(float(t.value), "." + str(_decimals(e)) + "f")
        return None
    if t.kind == "float":
        if FLOAT_RE.match(e):
            return format(float(t.value), "." + str(_decimals(e)) + "f")
        return None  # don't fabricate a float into a non-float field
    if t.kind == "bool":
        if BOOL_RE.match(e):
            return "TRUE" if t.value else "FALSE"
        return None
    if t.kind == "ratio":
        if FLOAT_RE.match(e):
            d = _decimals(e)
            hi = 1.0 if float(e) <= 1.0 else 100.0
            return format(t.value * hi, "." + str(d) + "f")
        if INT_RE.match(e):
            if int(e) <= 1:
                return None  # 0/1 int field can't express a mid fraction safely
            return str(int(round(t.value * 100)))
        return None
    return None


def canonical(t):
    """Format for a freshly ADDED key (only reached for add_ok int keys today)."""
    if t.kind == "int":
        return str(int(t.value))
    if t.kind == "float":
        return format(float(t.value), ".6f")
    if t.kind == "bool":
        return "TRUE" if t.value else "FALSE"
    if t.kind == "ratio":
        return str(int(round(t.value * 100)))
    return str(t.value)


def find_key(text, key):
    return re.search(
        r"(?im)^(\s*" + re.escape(key) + r"\s*=)([^\r\n]*)(\r?)$", text
    )


def set_value(text, key, newval):
    """Set KEY=newval in place (first hit), preserving the line's CR. -> (text, changed)."""
    m = find_key(text, key)
    if not m:
        return text, False
    if m.group(2) == newval:
        return text, False  # already the target -> idempotent no-op
    repl = m.group(1) + newval + (m.group(3) or "\r")
    return text[:m.start()] + repl + text[m.end():], True


def insert_into_section(text, section, add_lines):
    """Insert 'KEY=VAL' lines just after [section] (CRLF); append the section if absent."""
    block = "".join(l + "\r\n" for l in add_lines)
    m = re.search(r"(?im)^\[" + re.escape(section) + r"\]\r?$", text)
    if m:
        nl = text.find("\n", m.end())
        if nl == -1:
            return text + "\r\n" + block
        return text[:nl + 1] + block + text[nl + 1:]
    if text and not text.endswith("\n"):
        text += "\r\n"
    return text + "[" + section + "]\r\n" + block


def default_ini():
    home = os.environ.get("OSXEQL_HOME") or os.path.expanduser(
        "~/Library/Application Support/osxEQL"
    )
    prefix = os.path.join(home, "prefix")
    if not os.path.isfile(os.path.join(prefix, "system.reg")):
        alt = os.path.join(home, "prefix-cx")
        if os.path.isfile(os.path.join(alt, "system.reg")):
            prefix = alt
    return os.path.join(
        prefix, "drive_c", "users", "Public",
        "Daybreak Game Company", "Installed Games",
        "EverQuest Legends", "eqclient.ini",
    )


def main(argv):
    opts = set(a for a in argv if a.startswith("-"))
    args = [a for a in argv if not a.startswith("-")]
    known = {"--add-missing", "--dry-run", "-h", "--help"}
    unknown = opts - known
    if unknown:
        print("unknown option(s): " + " ".join(sorted(unknown)), file=sys.stderr)
        return 2
    if "-h" in opts or "--help" in opts:
        print(__doc__)
        return 0

    ini = args[0] if args else default_ini()
    add_missing = "--add-missing" in opts
    dry = "--dry-run" in opts

    if not os.path.isfile(ini):
        print("[eqclient] " + ini)
        print("[eqclient] not created yet — log in via osxEQL, quit cleanly once, "
              "then re-run. (no-op)")
        return 0

    raw = open(ini, "rb").read()
    text = raw.decode("latin-1")

    changed = []       # keys we rewrote
    added = []         # keys we created (--add-missing)
    absent = []        # keys not present (candidates for --add-missing)
    skipped_fmt = []   # present but in a shape we won't touch

    for key, t in TUNING.items():
        m = find_key(text, key)
        if m is None:
            absent.append(key)
            continue
        nv = coerce(t, m.group(2))
        if nv is None:
            skipped_fmt.append(key)
            continue
        text, ch = set_value(text, key, nv)
        if ch:
            changed.append(key)

    if add_missing:
        add_lines = []
        for key in list(absent):
            t = TUNING[key]
            if t.add_ok and key not in PROTECTED:
                add_lines.append(key + "=" + canonical(t))
                added.append(key)
        if add_lines:
            text = insert_into_section(text, ADD_SECTION, add_lines)
        absent = [k for k in absent if k not in added]

    still_absent = [k for k in absent]  # keys we won't add -> set in-game

    if dry:
        print("[eqclient] dry-run: " + ini)
        print("[eqclient] would change: " + (", ".join(changed) or "(none)"))
        if added:
            print("[eqclient] would add to [%s]: %s" % (ADD_SECTION, ", ".join(added)))
        if skipped_fmt:
            print("[eqclient] present but unexpected format (left alone): "
                  + ", ".join(skipped_fmt))
        if still_absent:
            print("[eqclient] absent (set in-game): " + ", ".join(still_absent))
        return 0

    if not changed and not added:
        print("[eqclient] already tuned — no changes.")
        if skipped_fmt:
            print("[eqclient] present but unexpected format (left alone): "
                  + ", ".join(skipped_fmt))
        if still_absent:
            print("[eqclient] absent (set in-game): " + ", ".join(still_absent))
        return 0

    bak = ini + ".qol-bak"
    if not os.path.exists(bak):
        with open(bak, "wb") as f:
            f.write(raw)

    with open(ini, "wb") as f:
        f.write(text.encode("latin-1"))

    if changed:
        print("[eqclient] tuned: " + ", ".join(changed))
    if added:
        print("[eqclient] added to [%s]: %s" % (ADD_SECTION, ", ".join(added)))
    if skipped_fmt:
        print("[eqclient] present but unexpected format (left alone): "
              + ", ".join(skipped_fmt))
    if still_absent:
        print("[eqclient] absent (set in-game): " + ", ".join(still_absent))
    print("[eqclient] backup: " + bak)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
