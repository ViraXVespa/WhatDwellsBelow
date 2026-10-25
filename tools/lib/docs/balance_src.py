"""Balance source model for `docs.py tunable`: defaults (scripts/data/balance/vars_*.gd, enemies.gd, tunables.gd
constants), slider rows (schema_a/b.gd, enemies.gd append_schema), debug-menu categories (val_cat_map.gd) and the
docs they map to (one vars_<system>.gd per design/tunables*.md). Edits stay in memory until `Src.write`, which
refuses any live script over the 10 KB Bot cap.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import bot_gate_lib

CAP = bot_gate_lib.SHIP_BYTES
BAL = "scripts/data/balance"
SYSTEMS = ("main", "combat", "world", "economy")
DOC = {"main": "tunables.md", "combat": "tunables-combat.md", "world": "tunables-world.md", "economy": "tunables-economy.md"}
SCHEMAS = (f"{BAL}/schema_a.gd", f"{BAL}/schema_b.gd")
ENEMIES = f"{BAL}/enemies.gd"
TCONST = "scripts/data/tunables.gd"
CATMAP = "scripts/debug/debug_menu/val_cat_map.gd"
## val_cat_map.gd category -> system (the doc that owns that kind of number).
CAT_SYS = {
    "main": ("Camera", "Ground", "Lighting"),
    "combat": ("Player", "Movement", "Combat", "Cover", "Aim & Lock", "Adrenaline", "Great Axe", "Staff", "Bow",
               "Gathering & Props", "Loot & Drops", "Consumables"),
    "world": ("Enemy Melee Stats", "Enemy Ranged Stats", "Enemy AI", "Enemy Spawns", "Level Scaling", "Dungeon Layout"),
    "economy": ("XP & Skills", "Gear", "Set Bonuses", "Forge & Affixes", "Shops & Quests"),
}
## Balance members that are not tunables (an add must not shadow them).
RESERVED = {"schema", "getv", "setv", "snapshot", "f", "apply_defense", "enemy_stats", "T", "Pref", "Schema", "Enemies", "Access"}
VAR_RE = re.compile(r"^var ([a-z0-9_]+)\s*(?::\s*(\w+)\s*)?:?=\s*(.+?)\s*$")
ROW_RE = re.compile(r'^(\s*)\["([a-z0-9_]+)",\s*([-0-9.e]+),\s*([-0-9.e]+),\s*([-0-9.e]+)\],?\s*$')
EROW_RE = re.compile(r'^(\s*)rows\.append\(\["e_%s_([a-z]+)" % id,\s*([-0-9.e]+),\s*([-0-9.e]+),\s*([-0-9.e]+)\]\)\s*$')
EDEF_RE = re.compile(r'^\s*"([a-z]+)": \{(.*)\},?\s*$')
KEY_RE = re.compile(r"^[a-z][a-z0-9_]*[a-z0-9]$")

class Fail(Exception):
    """A refused edit; the message says what to do instead."""

@dataclass
class Var:
    key: str
    system: str  # main|combat|world|economy, or "enemy"
    path: str
    line: int
    type: str  # float|int|bool
    expr: str
    value: object  # float|int|bool, None when not a literal

@dataclass
class Row:
    key: str
    path: str
    line: int
    lo: float
    hi: float
    step: float
    shared: int = 1  # enemy stat rows cover every enemy id

def num(text: str) -> float:
    return float(text)

def fmt(kind: str, v: object) -> str:
    """GDScript literal for a value of `kind`."""
    if kind == "bool":
        return "true" if v else "false"
    if kind == "int":
        return str(int(v))
    s = repr(float(v))
    if "e" in s or "E" in s:
        s = f"{float(v):.10f}".rstrip("0")
    if "." not in s:
        s += ".0"
    return s + ("0" if s.endswith(".") else "")

def parse_value(kind: str, raw: str) -> object:
    t = raw.strip().lower()
    if kind == "bool":
        if t in ("true", "1", "1.0", "on"):
            return True
        if t in ("false", "0", "0.0", "off"):
            return False
        raise Fail(f"{raw!r} is not a bool (true/false)")
    try:
        f = float(t)
    except ValueError:
        raise Fail(f"{raw!r} is not a number") from None
    if kind == "int":
        if f != int(f):
            raise Fail(f"{raw!r} is not an int (the key is typed int)")
        return int(f)
    return f

def literal(expr: str) -> tuple[str, object] | None:
    e = expr.strip()
    if e in ("true", "false"):
        return "bool", e == "true"
    if re.fullmatch(r"-?\d+", e):
        return "int", int(e)
    if re.fullmatch(r"-?\d+\.\d*(e-?\d+)?|-?\d+e-?\d+", e):
        return "float", float(e)
    return None

class Src:
    def __init__(self, root: Path):
        self.root = root
        self._text: dict[str, str] = {}
        self.dirty: set[str] = set()

    def lines(self, rel: str) -> list[str]:
        if rel not in self._text:
            self._text[rel] = (self.root / rel).read_bytes().decode("utf-8")
        return self._text[rel].splitlines(keepends=True)

    def put(self, rel: str, lines: list[str]) -> None:
        self._text[rel] = "".join(lines)
        self.dirty.add(rel)

    def set_line(self, rel: str, i: int, text: str) -> None:
        ls = self.lines(rel)
        nl = "\r\n" if ls[i].endswith("\r\n") else "\n"
        ls[i] = text.rstrip("\r\n") + nl
        self.put(rel, ls)

    def insert(self, rel: str, i: int, text: str) -> None:
        """Insert `text` as line index i (0 = top)."""
        ls = self.lines(rel)
        nl = "\r\n" if ls and ls[0].endswith("\r\n") else "\n"
        if i > 0 and not ls[i - 1].endswith(("\n", "\r\n")):
            ls[i - 1] += nl
        ls.insert(i, text + nl)
        self.put(rel, ls)

    def size(self, rel: str) -> int:
        return len(("".join(self.lines(rel))).encode("utf-8"))

    def write(self, dry: bool = False) -> list[str]:
        """Write every edited file (cap-checked first: nothing is written when one would exceed it)."""
        over = [(r, self.size(r)) for r in sorted(self.dirty) if r.startswith("scripts/") and r.endswith(".gd") and self.size(r) > CAP]
        if over:
            r, n = over[0]
            raise Fail(f"{r} would be {n} B (cap {CAP} B, +{n - (self.root / r).stat().st_size} B); nothing written. "
                       f"Split it first: one cluster per PR (python tools/check.py script-cap --sweep); vars.gd chains one "
                       f"vars_<system>.gd per design/tunables*.md, so a full system file splits by section the same way")
        if not dry:
            for r in sorted(self.dirty):
                (self.root / r).write_bytes(self._text[r].encode("utf-8"))
        return sorted(self.dirty)

    # --- readers -------------------------------------------------------------------------------------------
    def vars(self) -> dict[str, Var]:
        out: dict[str, Var] = {}
        consts = self.consts()
        for s in SYSTEMS:
            rel = f"{BAL}/vars_{s}.gd"
            for i, ln in enumerate(self.lines(rel)):
                m = VAR_RE.match(ln.rstrip("\r\n").lstrip("\ufeff"))
                if not m:
                    continue
                key, typ, expr = m.group(1), m.group(2), m.group(3)
                lit = literal(expr)
                val = lit[1] if lit else None
                ref = re.fullmatch(r"T\.([A-Z0-9_]+)", expr)
                if ref and ref.group(1) in consts:
                    val = consts[ref.group(1)][1]
                    lit = lit or (consts[ref.group(1)][2], val)
                kind = typ or (lit[0] if lit else "float")
                if key in out:
                    raise Fail(f"{key} is declared twice: {out[key].path} and {rel}")
                out[key] = Var(key, s, rel, i, kind, expr, val)
        return out

    def consts(self) -> dict[str, tuple[int, object, str]]:
        out = {}
        for i, ln in enumerate(self.lines(TCONST)):
            m = re.match(r"^const ([A-Z0-9_]+)\s*(?::\s*\w+\s*)?:?=\s*(.+?)\s*$", ln.rstrip("\r\n"))
            lit = literal(m.group(2)) if m else None
            if lit:
                out[m.group(1)] = (i, lit[1], lit[0])
        return out

    def enemies(self) -> dict[str, Var]:
        out: dict[str, Var] = {}
        for i, ln in enumerate(self.lines(ENEMIES)):
            m = EDEF_RE.match(ln.rstrip("\r\n"))
            if not m:
                continue
            for st, v in re.findall(r'"([a-z]+)": (-?[0-9.]+)', m.group(2)):
                k = f"e_{m.group(1)}_{st}"
                out[k] = Var(k, "enemy", ENEMIES, i, "float", v, float(v))
        return out

    def rows(self) -> dict[str, Row]:
        out: dict[str, Row] = {}
        for rel in SCHEMAS:
            for i, ln in enumerate(self.lines(rel)):
                m = ROW_RE.match(ln.rstrip("\r\n"))
                if m:
                    out[m.group(2)] = Row(m.group(2), rel, i, num(m.group(3)), num(m.group(4)), num(m.group(5)))
        stat_rows = {}
        for i, ln in enumerate(self.lines(ENEMIES)):
            m = EROW_RE.match(ln.rstrip("\r\n"))
            if m:
                stat_rows[m.group(2)] = (i, num(m.group(3)), num(m.group(4)), num(m.group(5)))
        ids = sorted({k.split("_")[1] for k in self.enemies()})
        for st, (i, lo, hi, step) in stat_rows.items():
            for eid in ids:
                out[f"e_{eid}_{st}"] = Row(f"e_{eid}_{st}", ENEMIES, i, lo, hi, step, shared=len(ids))
        return out

    def defaults(self) -> dict[str, Var]:
        return {**self.vars(), **self.enemies()}

    def cat_rules(self) -> tuple[list[str], list[tuple[str, str]], int]:
        """(categories, [prefix, category] rules, line index of `const RULES` opener)."""
        text = "".join(self.lines(CATMAP)).replace("\r\n", "\n")
        cats = re.findall(r'^\t"([^"]+)",$', text.split("const RULES", 1)[0], re.M)
        rules = re.findall(r'^\t\["([a-z0-9_]+)", "([^"]+)"\],$', text, re.M)
        opener = next(i for i, ln in enumerate(self.lines(CATMAP)) if ln.startswith("const RULES"))
        return cats, rules, opener

    def category(self, key: str) -> str:
        return next((c for p, c in self.cat_rules()[1] if key.startswith(p)), "Other")

def cat_system(cat: str) -> str | None:
    return next((s for s, cs in CAT_SYS.items() if cat in cs), None)

def check_range(key: str, kind: str, lo: float, hi: float, step: float, value: object) -> None:
    if not lo < hi:
        raise Fail(f"{key}: min {lo} must be below max {hi}")
    if not 0 < step <= hi - lo:
        raise Fail(f"{key}: step {step} must be > 0 and <= max - min ({hi - lo})")
    if kind == "bool" and (lo, hi, step) != (0.0, 1.0, 1.0):
        raise Fail(f"{key} is a bool: its slider row must be 0.0, 1.0, 1.0")
    if value is not None and not lo <= float(value) <= hi:
        raise Fail(f"{key}: default {value} is outside [{lo}, {hi}]; change the default or widen the range")

def row_text(indent: str, key: str, lo: float, hi: float, step: float) -> str:
    return f'{indent}["{key}", {fmt("float", lo)}, {fmt("float", hi)}, {fmt("float", step)}],'
