"""Hub bake inputs: what the committed hub_light.png was baked from, so a light or Layout change without a rebake fails.

tools/data/hub_bake_inputs.json records the HUB_BAKE_STAMP of the png and a hash of every bake input at bake time:
each light/camp code file (comments and blank lines dropped, the HUB_BAKE_STAMP line ignored) and each layout_spec.gd
const on its own, except spec_skip (numbers the bake never reads). tools/bake.py camp records it after a bake;
`tools/bake.py check --record` re-records without a rebake (only when the change cannot move the light: say why in
the PR). tools/bake.py check FAILs on any input that differs from the record.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

REC = "tools/data/hub_bake_inputs.json"
SPEC = "scripts/world/camp/layout_spec.gd"
STAMP_RE = re.compile(r'^const HUB_BAKE_STAMP := ')

def _norm(text: str) -> str:
    keep = [ln.strip() for ln in text.splitlines()]
    return "\n".join(ln for ln in keep if ln and not ln.startswith("#") and not STAMP_RE.match(ln))

def _h(text: str) -> str:
    return hashlib.sha256(_norm(text).encode("utf-8")).hexdigest()[:16]

def spec_consts(text: str) -> dict[str, str]:
    """layout_spec.gd top-level const NAME -> its source (continuation lines included, comments dropped)."""
    out: dict[str, list[str]] = {}
    cur = ""
    for ln in text.splitlines():
        m = re.match(r"const (\w+)", ln)
        if m:
            cur = m.group(1)
            out[cur] = [ln]
        elif cur and ln[:1] in ("\t", " ", "}", "]", ")"):
            out[cur].append(ln)
        else:
            cur = ""
    return {k: "\n".join(v) for k, v in out.items()}

def load(root: Path) -> dict:
    p = root / REC
    return json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}

def current(root: Path, rec: dict) -> dict[str, str]:
    """Input key -> hash now: code paths (globs allowed) and spec:NAME per layout_spec const."""
    got: dict[str, str] = {}
    for pat in rec.get("code", []):
        for p in sorted(root.glob(pat)):
            got[p.relative_to(root).as_posix()] = _h(p.read_text(encoding="utf-8"))
    spec = root / SPEC
    if spec.is_file():
        skip = set(rec.get("spec_skip", {}))
        for k, v in spec_consts(spec.read_text(encoding="utf-8")).items():
            if k not in skip:
                got["spec:" + k] = _h(v)
    return got

def record(root: Path, stamp: str) -> Path:
    rec = load(root)
    rec["stamp"] = stamp
    rec["inputs"] = current(root, rec)
    p = root / REC
    p.write_text(json.dumps(rec, indent=1) + "\n", encoding="utf-8")
    return p

def problems(root: Path, stamp: str) -> list[str]:
    """FAIL lines: no record, a record for another stamp, or inputs changed since the bake."""
    rec = load(root)
    if not rec.get("inputs"):
        return [f"FAIL {REC} missing: rebake with tools/bake.py camp (it records the bake inputs)"]
    if rec.get("stamp") != stamp:
        return [f"FAIL {REC} stamp {rec.get('stamp')} != HUB_BAKE_STAMP {stamp}: the png was rebaked without recording "
                "its inputs; use tools/bake.py camp"]
    old, now = rec["inputs"], current(root, rec)
    diff = sorted(k for k in old.keys() | now.keys() if old.get(k) != now.get(k))
    return [f"FAIL hub bake input changed since the bake: {k} ({'new' if k not in old else 'gone' if k not in now else 'edited'}): "
            "rebake with tools/bake.py camp, or if it cannot move the light, tools/bake.py check --record and say why"
            for k in diff]

def selftest(tmp: Path) -> list[str]:
    bad: list[str] = []
    (tmp / "tools/data").mkdir(parents=True)
    (tmp / "scripts/world/camp").mkdir(parents=True)
    (tmp / "scripts/graphics").mkdir(parents=True)
    spec, code = tmp / SPEC, tmp / "scripts/graphics/hub_cast.gd"
    spec.write_text('## doc\nconst FENCE := {\n\t"h": 1.05,\n}\nconst DRAW := {"lamp": 2}\nconst LAMP_R := 1.8\n')
    code.write_text('extends Object\n## reach\nconst REACH := 6.0\n')
    (tmp / REC).write_text(json.dumps({"code": ["scripts/graphics/hub_*.gd"], "spec_skip": {"DRAW": "draw order"}}))
    if not problems(tmp, "aa"):
        bad.append("no recorded inputs passed")
    record(tmp, "aa")
    if problems(tmp, "aa"):
        bad.append("a fresh record fails: " + str(problems(tmp, "aa")))
    if not problems(tmp, "bb"):
        bad.append("a record for another stamp passed")
    code.write_text('extends Object\n## reach, longer comment\n\nconst REACH := 6.0\n')
    spec.write_text(spec.read_text().replace('"lamp": 2', '"lamp": 3'))
    if problems(tmp, "aa"):
        bad.append("a comment edit or a spec_skip const (DRAW) asked for a rebake")
    spec.write_text(spec.read_text().replace("1.05", "1.2"))
    if not any("spec:FENCE" in p for p in problems(tmp, "aa")):
        bad.append("a layout_spec FENCE height change without a rebake passed")
    code.write_text('extends Object\nconst REACH := 7.0\n')
    if not any("hub_cast.gd" in p for p in problems(tmp, "aa")):
        bad.append("a hub light code change without a rebake passed")
    return bad
