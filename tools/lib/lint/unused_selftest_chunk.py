"""lint.py unused --selftest, chunk half: --paths globs, reach tags (type_here / cascade), --baseline diff,
--plan-out markers and the exact-only doc fixes after --apply. Throwaway roots only."""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

FIX = {
    "project.godot": '[application]\n[autoload]\nApp="*res://scripts/app.gd"\n',
    "scripts/app.gd": """extends Node
const Caller := preload("res://scripts/out/caller.gd")
const Start := preload("res://scripts/chunk/b.gd")
const A := preload("res://scripts/chunk/a.gd")
const C := preload("res://scripts/chunk2/c.gd")

func _ready() -> void:
	Caller.go(null)
	Start.start(null)
""",
    "scripts/out/caller.gd": "static func go(x) -> void:\n\tx.cascade_entry()\n",
    "scripts/chunk/a.gd": "static func cascade_entry() -> void:\n\tcascade_leaf()\n\nstatic func cascade_leaf() -> void:\n\tpass\n",
    "scripts/chunk/b.gd": "static func start(y) -> void:\n\ty.local_fn()\n",
    "scripts/chunk2/c.gd": "static func local_fn() -> void:\n\tpass\n",
}
DOC = """# Notes
- `CMod.dead_a` was the old facade entry.
| `CMod.dead_a` | `CMod.live_c` |
`CMod.dead_a` is still named in prose.
- `CMod.dead_a` opens a bullet
  with a continuation line.
- `gone_fn()` had no other def.
"""
MAP = "| System | Live files |\n|---|---|\n| Core | `scripts/app.gd`, `scripts/orphan.gd` |\n"

def _write(root: Path, files: dict) -> None:
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")

def run() -> list[str]:
    import list_unused_funcs as luf
    import unused_chunk as uc
    import unused_docfix
    bad: list[str] = []
    rx = uc.glob_re(["scripts/debug/shot_tool/**", "scripts/title*", "scripts/ui/progress_ui.gd", "scripts/combat"])
    for rel, want in (("scripts/debug/shot_tool/a/b.gd", True), ("scripts/debug/shot_tool.gd", False), ("scripts/title.gd", True),
                      ("scripts/title_x/t.gd", True), ("scripts/ui/progress_ui.gd", True), ("scripts/ui/progress_ui/x.gd", False),
                      ("scripts/combat/enemy/e.gd", True), ("scripts/combatx.gd", False)):
        if uc.in_chunk(rx, rel) != want:
            bad.append(f"chunk: glob match {rel} expected {want}")
    with tempfile.TemporaryDirectory(prefix="unused-chunk-st-") as tmp:
        root = Path(tmp)
        _write(root, FIX)
        luf.run(root, False, 0, quiet=True)
        blob = json.loads((root / "_logs/unused-funcs/unused-funcs.json").read_text(encoding="utf-8"))
        g, _rows = luf.analyse(root)
        ch = uc.build(root, g, blob, ["scripts/chunk", "scripts/chunk2"])
        tag = {r["name"]: r.get("reach", {}) for r in ch["rows"].get("ambiguous", [])}
        for name, want, site in (("cascade_entry", "cascade", "scripts/out/caller.gd:2"), ("cascade_leaf", "cascade", "scripts/out/caller.gd:2"),
                                 ("local_fn", "type_here", "scripts/chunk/b.gd:2")):
            got = tag.get(name, {})
            if got.get("tag") != want or not any(s.startswith(site) for s in got.get("sites", [])):
                bad.append(f"reach: {name} expected {want} via {site}, got {got.get('tag')} {got.get('sites')}")
        if "scripts/out/caller.gd" not in ch["reach"]["cascade_callers"]:
            bad.append(f"reach: cascade caller not named ({ch['reach']})")
        if any(r["rel"].startswith("scripts/out/") for v in ch["rows"].values() for r in v):
            bad.append("chunk: out-of-chunk row listed")
        why = "\n".join(uc.why_lines(g, blob, "a:cascade_leaf", ["scripts/chunk"]))
        if "-unresolved@scripts/out/caller.gd:2->" not in why or "-call@scripts/chunk/a.gd:2->" not in why:
            bad.append(f"why: edge kinds missing from path:\n{why}")
        before = json.loads(json.dumps(ch))
        before["rows"]["ambiguous"] = before["rows"]["ambiguous"] + [dict(rel="scripts/chunk/a.gd", name="old_fn", line=9)]
        before["counts"]["ambiguous"] += 1
        d = uc.diff(before, ch)
        if d["counts"]["ambiguous"] != [4, 3] or d["gone"] != ["ambiguous\tscripts/chunk/a.gd\told_fn"] or d["new"]:
            bad.append(f"baseline: diff wrong {d}")
        plan = root / "plan.md"
        plan.write_text("# Plan\nhand notes stay\n", encoding="utf-8")
        uc.write_plan(plan, uc.plan_md(ch, "4"), "4")
        how = uc.write_plan(plan, uc.plan_md(dict(ch, diff=d), "4"), "4")
        text = plan.read_text(encoding="utf-8")
        if how != "replaced" or text.count("<!-- unused-chunk 4 -->") != 1 or "hand notes stay" not in text or "| ambiguous | 4 | 3 |" not in text:
            bad.append(f"plan: marker block not replaced in place ({how})")
        if "scripts/out/caller.gd" not in text:
            bad.append("plan: cascade caller missing from the block")
        # exact-only doc fixes
        _write(root, {"design/notes.md": DOC, "design/code-map.md": MAP})
        stale = [dict(rel="design/notes.md", line=n, name="CMod.dead_a", why="qualified member removed from scripts/c.gd") for n in (2, 3, 4, 5)]
        stale.append(dict(rel="design/notes.md", line=7, name="gone_fn", why="no remaining GDScript def"))
        fixed, left = unused_docfix.fix(root, [("file", "scripts/orphan.gd", "orphan.gd"), ("unused", "scripts/c.gd", "gone_fn")], stale)
        doc = (root / "design/notes.md").read_text(encoding="utf-8")
        cmap = (root / "design/code-map.md").read_text(encoding="utf-8")
        if "old facade entry" in doc or "had no other def" in doc:
            bad.append("docfix: exact bullet lines not dropped")
        for keep in ("`CMod.live_c`", "still named in prose", "with a continuation line"):
            if keep not in doc:
                bad.append(f"docfix: touched a fuzzy/survivor line ({keep})")
        if "scripts/orphan.gd" in cmap or "`scripts/app.gd`" not in cmap:
            bad.append(f"docfix: code-map tick not removed exactly: {cmap!r}")
        if sorted(s["line"] for s in left) != [3, 4, 5]:
            bad.append(f"docfix: warnings left {[(s['line'], s['name']) for s in left]}, expected lines 3, 4, 5")
        if len(fixed) != 3:
            bad.append(f"docfix: expected 3 fixes (2 lines + 1 tick), got {len(fixed)}")
    return bad
