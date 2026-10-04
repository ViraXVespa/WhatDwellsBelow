"""Log parser for tools/bot_warnscan.py. Python 3 stdlib only.

Reads Godot stdout/stderr text and returns de-duplicated findings:
WARNING / ERROR / SCRIPT ERROR lines with their `at:` and backtrace lines,
plus leak, crash, deprecated and load-failure signatures that Godot prints
only once the game has really run.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

PREFIX = re.compile(r"^(?P<tag>(?:USER |SHADER )?(?:SCRIPT )?(?:ERROR|WARNING)):\s?(?P<msg>.*)$")
RES_REF = re.compile(r"(res://[^\s:()]+:\d+)")
CPP_AT = re.compile(r"^\s*at:\s*(?:.*?\()?([\w./-]+\.(?:cpp|h|mm|c):\d+)")
# Lines the smokes and the static harness print on purpose. Never findings.
BENIGN = re.compile(r"^(P\d+|LOAD|MAP|WARNSCAN|Godot Engine v)\b")

# (kind, regex on "TAG msg"). First match wins. Order matters.
KIND_RULES = [
    # Real-renderer runs on xvfb/software GL only; the project never sets vsync. Reported, never fails the gate.
    ("env-artifact", re.compile(r"Could not set V-Sync mode")),
    ("leak", re.compile(r"leaked at exit|Cannot get path of node as it is not in a scene tree|RID allocations .* leaked|RIDs? of type .* leaked|resources? still in use")),
    ("script-error", re.compile(r"^SCRIPT ERROR|^USER SCRIPT")),
    ("shader", re.compile(r"^SHADER|(?i:shader)")),
    ("deprecated", re.compile(r"(?i)\bdeprecated\b")),
    ("load-failure", re.compile(r"Failed to load|Resource file not found|Cannot open file|Parse Error")),
    ("engine-condition", re.compile(r'Condition ".*" is true')),
    ("warning", re.compile(r"^(USER )?WARNING")),
    ("error", re.compile(r"^(USER )?ERROR")),
]
# Non-prefixed lines worth a finding (leak details, crashes, odd stdout).
SIGNATURES = [
    ("leak", re.compile(r"^(Leaked instance:|Resource still in use:|Orphan StringName:|StringName: \d+ unclaimed|.*Pages in use exist at exit)")),
    ("crash", re.compile(r"handle_crash|Program crashed|Segmentation fault")),
    ("deprecated", re.compile(r"(?i)\bdeprecated\b")),
    ("load-failure", re.compile(r"^WARNSCAN: load_failed=|Failed to load|Parse Error|Compile Error")),
    ("engine-condition", re.compile(r'Condition ".*" is true')),
]
# Small, data-driven hints. Only patterns seen in real logs (or verified in a
# scratch copy). First match on the normalized message wins.
HINTS = [
    (r"declared but never used|never used in the function",
     "gdscript-law Warnings: unused local/param -> prefix `_` (keep params callers still pass)."),
    (r"is shadowing an already-declared",
     "gdscript-law Warnings: shadowed name -> rename (see the banned-names list)."),
    (r"^Integer division",
     "gdscript-law Warnings: write int(a / float(b)) when dropping the remainder is intended."),
    (r"ternary operator are not mutually compatible",
     "Not in gdscript-law yet: give both branches one type (cast one). Candidate new rule."),
    (r"ObjectDB instances? (?:was|were) leaked",
     "Objects alive at exit. Read the 'Leaked instance:' rows (engine --verbose is on by default): "
     "usually a node removed with remove_child() but never freed, or held by a static/autoload var."),
    (r"resources? still in use at exit",
     "A Resource is still referenced at exit: static var / preload cache / live node. "
     "See 'Resource still in use:' rows for the path."),
    (r"Cannot get path of node as it is not in a scene tree",
     "Side effect of leaked Node rows at exit (the leak dump asks nodes outside the tree for get_path). "
     "Goes away when the leaked nodes are freed."),
    (r"^Leaked instance: AudioStream",
     "Audio stream or playback still alive at exit: a player was not stopped/freed before quit."),
    (r"^Leaked instance: Node",
     "Node alive at exit: created but never freed, or removed from the tree without free()/queue_free()."),
    (r"^Leaked instance: GDScript",
     "Script objects stay alive while a leaked object or static var still references them. "
     "Match against the 'Resource still in use: res://scripts/...' row."),
    (r"^Orphan StringName|unclaimed string names",
     "Engine StringName left at exit; usually a side effect of the leaks above. Re-check after those are fixed."),
    (r"RIDs? (?:allocations )?(?:of type .*)?(?:were|was) leaked",
     "A server RID (physics/rendering) created in script was never freed with free_rid()."),
    (r"Not supported by this display server",
     "Headless display server has no keyboard layout query. Headless-only artifact; a fix is a game-code "
     "guard (user-named flow), not a log filter."),
    (r"Could not set V-Sync mode",
     "Real-renderer run on xvfb/software GL: the driver cannot change V-Sync. Environment artifact (the project never sets vsync); not game code."),
    (r"Resource file not found|Failed to load",
     "Missing or broken path: check the load()/preload() string and the .import file."),
    (r"Parse Error|Compile Error",
     "Script does not compile: fix the line named in `site`."),
]


def norm(s: str) -> str:
    s = re.sub(r"0x[0-9a-fA-F]+", "0x", s)
    s = re.sub(r"^(Orphan StringName:) .* (\(static:)", r"\1 <name> \2", s)
    s = re.sub(r":\d{6,}\b", ":ID", s)
    s = re.sub(r"\b\d+(?:\.\d+)?\b", "N", s)
    return re.sub(r"\s+", " ", s).strip()


@dataclass
class Finding:
    kind: str
    msg: str
    norm: str
    site: str
    stack: list[str] = field(default_factory=list)
    count: int = 0
    areas: dict[str, int] = field(default_factory=dict)
    first: str = ""
    samples: list[str] = field(default_factory=list)
    hint: str = ""
    runs: dict[str, set] = field(default_factory=dict)  # area tag -> run numbers that logged it

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.kind, self.norm, self.site)


def _kind(tag: str, msg: str) -> str:
    text = f"{tag} {msg}"
    for kind, rx in KIND_RULES:
        if rx.search(text):
            return kind
    return "error"


def _site(cont: list[str]) -> str:
    for line in cont:
        m = RES_REF.search(line)
        if m:
            return m.group(1)
    for line in cont:
        m = CPP_AT.match(line)
        if m:
            return m.group(1)
    return ""


def hint_for(f: Finding) -> str:
    text = f.norm
    for rx, hint in HINTS:
        if re.search(rx, text):
            return hint
    return ""


def parse_stream(text: str, area: str, stream: str) -> list[Finding]:
    """One Finding (count=1) per logged event. merge() de-duplicates."""
    lines = text.replace("\r\n", "\n").split("\n")
    out: list[Finding] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = PREFIX.match(line)
        kind = ""
        msg = ""
        if m:
            kind, msg = _kind(m.group("tag"), m.group("msg")), m.group("tag") + ": " + m.group("msg")
        elif line.strip() and not line[0].isspace() and not BENIGN.match(line):
            for k, rx in SIGNATURES:
                if rx.search(line):
                    kind, msg = k, line.strip()
                    break
            if not kind and stream == "err":
                kind, msg = "stderr-other", line.strip()
        if not kind:
            i += 1
            continue
        cont: list[str] = []
        j = i + 1
        while j < len(lines) and lines[j][:1].isspace() and lines[j].strip():
            cont.append(lines[j].rstrip())
            j += 1
        if kind == "warning" and any("GDScript::reload" in c for c in cont):
            kind = "gdscript-warning"
        f = Finding(kind, msg, norm(msg), _site(cont), cont[:8], 1, {area: 1},
                    f"{area} {stream}:{i + 1}", [msg])
        f.hint = hint_for(f)
        out.append(f)
        i = j
    return out


def merge(into: dict, found: list[Finding], run: int = 1) -> None:
    for f in found:
        for a in f.areas:
            f.runs.setdefault(a, set()).add(run)
        cur = into.get(f.key)
        if cur is None:
            into[f.key] = f
            continue
        for a, rs in f.runs.items():
            cur.runs.setdefault(a, set()).update(rs)
        cur.count += f.count
        for a, n in f.areas.items():
            cur.areas[a] = cur.areas.get(a, 0) + n
        for s in f.samples:
            if s not in cur.samples and len(cur.samples) < 3:
                cur.samples.append(s)


def run_failure(area: str, what: str) -> Finding:
    f = Finding("run-fail", what, norm(what), "", [], 1, {area: 1}, f"{area} runner")
    return f


def flake_label(f: Finding, ran: dict[str, int]) -> str:
    """'stable' = logged in every run of every re-run area; else 'flaky <area> n/m' (worst area). '' when no area it hit was re-run.

    `ran` maps area tag -> how many times that area ran."""
    multi = {a: rs for a, rs in f.runs.items() if ran.get(a, 1) > 1}
    if not multi:
        return ""
    area, rs = min(multi.items(), key=lambda kv: len(kv[1]) / ran[kv[0]])
    return "stable" if len(rs) >= ran[area] else f"flaky {area} {len(rs)}/{ran[area]}"


def mode_label(f: Finding) -> str:
    """'gui-only' / 'headless-only' when both renderers ran (area tags ending @gui are the real renderer)."""
    gui = [a for a in f.areas if a.endswith("@gui")]
    if gui and len(gui) == len(f.areas):
        return "gui-only"
    if not gui:
        return "headless-only"
    return ""


# Quick mode (--changed): path prefix -> areas that load that code. Longest prefix wins; unmapped
# scripts/scenes/project files fall back to QUICK_DEFAULT. static (compile everything) always runs.
CHANGED_MAP = [
    ("scripts/audio/", ["p1", "p2", "p8", "p9"]),
    ("scripts/combat/", ["p1", "p2", "p4"]),
    ("scripts/dungeon/", ["p3", "p4", "map-f1", "dungeon-load-timing"]),
    ("scripts/world/", ["p3", "p5", "p9", "dungeon-load-timing"]),
    ("scripts/ui/", ["p6", "p7", "p8"]),
    ("scripts/data/", ["p3", "p4", "p6"]),
    ("scripts/input/", ["p1", "p7"]),
    ("scripts/graphics/", ["p1", "p3", "p9"]),
    ("scripts/title", ["boot", "load-timing"]),
    ("scripts/app", ["p1", "p8", "load-timing"]),
    ("scripts/debug/", ["p1", "p7", "p9"]),
    ("scenes/", ["boot", "load-timing", "dungeon-load-timing"]),
]
QUICK_DEFAULT = ["p1", "p3", "p7"]
CODE_PREFIXES = ("scripts/", "scenes/", "project.godot", "assets/shaders/")


def changed_areas(paths: list[str]) -> list[str]:
    """Areas for a list of changed repo paths (posix). Only static when nothing code-like changed."""
    out: list[str] = []
    code = [p for p in paths if p.startswith(CODE_PREFIXES) and (p.endswith((".gd", ".tscn", ".tres", ".gdshader", ".godot")) or "/" not in p)]
    for p in code:
        hits = [(len(pre), areas) for pre, areas in CHANGED_MAP if p.startswith(pre)]
        for a in (max(hits)[1] if hits else QUICK_DEFAULT):
            if a not in out:
                out.append(a)
    return out + ["static"]
