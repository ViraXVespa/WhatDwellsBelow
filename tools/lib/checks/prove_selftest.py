"""`check.py prove --selftest`: one throwaway repo whose head commit makes every kind of drift the prove must flag.

Base -> head: a tool path is deleted while a task resume line still runs it, a subcommand and a flag are dropped
while a doc names them, a data key is dropped while its reader still asks for it, a const is dropped (another moves) while a doc names both, a func and a common-word const vanish while a doc ticks them, a group is dropped while a shot
flow and its own script still ask for it (a res:// path naming it is no node ref), a lib signature changes under an untouched importer, a docstring changes under an untouched doc
(REVIEW) and under a doc line repeating its pin name (STALE), a new comment makes a claim about an untouched tool
(CLAIM), and a UI script changes only a comment. The checks: each DRIFT / STALE / CLAIM / REVIEW line appears, the
comment-only script is cosmetic (a `#` line in a shader string is not), and the plan picks the selftests (changed tool, importer of the changed lib),
textsize for the UI script and task check.
"""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

import agent_log
import check_prove

MAIN = 'if __name__ == "_' '_main__":\n    main()\n'  # split so tool-cli does not take this file for a tool
BASE = {
    "tools/ent.py": 'COMMANDS = [("a", "x/run_a", "A"), ("b", "x/run_b", "B")]\n',
    "tools/open_x.py": '"""Old launcher."""\n',
    "tools/lib/x/run_a.py": '"""Run A: pins grok_web_wN and grok_build_wN."""\nimport lib_y\nap.add_argument("--gone", help="old")\nap.add_argument("--selftest")\nCFG = "d.json"\nv = cfg.get("oldkey")\n',
    "tools/lib/x/run_b.py": '"""Run B."""\nimport lib_y\nlib_y.helper(1)\nap.add_argument("--selftest")\n' + MAIN,
    "tools/lib/x/lib_y.py": '"""Lib Y."""\ndef helper(a):\n    return a\n',
    "tools/lib/x/week_zz.py": '"""Week ZZ."""\n',
    "tools/data/d.json": '{"keep": 1, "oldkey": 2}\n',
    "tools/data/shot-flows/f.json": '{"steps": [{"op": "click", "group": "hud_items"}]}\n',
    "scripts/ui/hud.gd": 'extends Node\nconst OLD_REV := 3\nfunc _ready():\n\tadd_to_group("hud_items")\n',
    "scripts/ui/bar.gd": 'extends Node\nconst MOVED_REV := 1\nconst NEEDED := [1]\n',
    "scripts/ui/warm.gd": 'extends Node\nvar s = load("res://scripts/ui/hud_items.gd")  # warm hud_items\n',
    "scripts/ui/frame_a.gd": 'extends Node\nfunc dress(b):\n\tpass\n',
    "scripts/ui/frame_b.gd": 'extends Node\nfunc dress(b):\n\tpass\n',
    "design/tasks/t.md": "id: t\nresume: python tools/open_x.py --task t\n\n## Body\n",
    "design/doc.md": "Run `ent.py a --gone` or `ent.py b`; `run_a.py` pins the week.\n`OLD_REV` and `MOVED_REV` gate old saves.\nEach `dress()` look; the `NEEDED` list (NEEDED when needed).\n",
    "design/pin.md": "Weekly pins\n\nCI runs `ent.py a`:\nit pins grok_web_wN and grok_build_wN.\n",
    "scripts/ui/menu.gd": 'extends Node\n# old note\nvar s := "a # b"\n',
    "scripts/ui/glow.gd": 'extends Node\nconst CODE := """\n#define K 1\n"""\n',
}
HEAD = {
    "tools/ent.py": 'COMMANDS = [("a", "x/run_a", "A")]\n',
    "tools/open_x.py": None,
    "tools/lib/x/run_a.py": '"""Run A: pins grok_build_wN only."""\nimport lib_y\n# week_zz creates the web pin\nap.add_argument("--selftest")\nCFG = "d.json"\nv = cfg.get("oldkey")\n',
    "tools/lib/x/lib_y.py": '"""Lib Y."""\ndef helper(a, b):\n    return a + b\n',
    "tools/data/d.json": '{"keep": 1}\n',
    "scripts/ui/hud.gd": 'extends Node\nconst MOVED_REV := 1\nfunc _ready():\n\tprint(get_tree().get_nodes_in_group("hud_items"))\n',
    "scripts/ui/bar.gd": 'extends Node\n',
    "scripts/ui/frame_a.gd": 'extends Node\nfunc dress_up(b):\n\tpass\n',
    "scripts/ui/frame_b.gd": 'extends Node\nfunc dress_up(b):\n\tpass\n',
    "scripts/ui/menu.gd": 'extends Node\n## new note\n\nvar s := "a # b"  # trailing\n',
    "scripts/ui/glow.gd": 'extends Node\nconst CODE := """\n#define K 2\n"""\n',
}
WANT_DRIFT = ["removed path tools/open_x.py (tools/open_x.py) still named at design/tasks/t.md:2",
              "removed subcommand ent.py b (tools/ent.py) still named at design/doc.md:1",
              "removed flag --gone (tools/lib/x/run_a.py) still named at design/doc.md:1",
              'removed data key oldkey (tools/data/d.json) still named at tools/lib/x/run_a.py:6',
              "removed const/var OLD_REV (scripts/ui/hud.gd) still named at design/doc.md:2",
              "removed function dress (scripts/ui/frame_a.gd) still named at design/doc.md:3",
              "removed const/var NEEDED (scripts/ui/bar.gd) still named at design/doc.md:3",
              "removed node/group hud_items (scripts/ui/hud.gd) still named at tools/data/shot-flows/f.json:1",
              "removed node/group hud_items (scripts/ui/hud.gd) still named at scripts/ui/hud.gd:4",
              "STALE   tools/lib/x/run_a.py docstring/help changed (line 1); design/pin.md:4",
              "CLAIM   tools/lib/x/run_a.py:3 new comment names week_zz (tools/lib/x/week_zz.py)"]
WANT_REVIEW = ["signature of helper() changed in tools/lib/x/lib_y.py; caller tools/lib/x/run_b.py:3",
               "tools/lib/x/run_a.py docstring/help changed (line 1); design/doc.md names it"]
WANT_PLAN = ["python3 tools/ent.py a --selftest", "python3 tools/lib/x/run_b.py --selftest", "python3 tools/shots.py textsize --gate",
             "python3 tools/docs.py task check"]

def _commit(root: Path, files: dict, msg: str) -> str:
    for rel, text in files.items():
        p = root / rel
        if text is None:
            p.unlink()
            continue
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    g = lambda *a: subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, check=True).stdout.strip()
    g("add", "-A")
    g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", msg)
    return g("rev-parse", "HEAD")

def main() -> int:
    bad: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        base = _commit(root, BASE, "base")
        head = _commit(root, HEAD, "head")
        a = check_prove.analyse(root, base, head)
        steps = [cmd for _, cmd, _ in check_prove.plan(root, a, False)]
        for want, got, kind in [(w, a["drift"], "DRIFT") for w in WANT_DRIFT] + [(w, a["review"], "REVIEW") for w in WANT_REVIEW]:
            if not any(want in g for g in got):
                bad.append(f"missing {kind}: {want}")
        for want in WANT_PLAN:
            if want not in steps:
                bad.append(f"plan lacks: {want}")
        if a["cosmetic"] != {"scripts/ui/menu.gd"}:
            bad.append(f"cosmetic {sorted(a['cosmetic'])} != ['scripts/ui/menu.gd']")
        if len(a["drift"]) != len(WANT_DRIFT):
            bad.append(f"drift count {len(a['drift'])} != {len(WANT_DRIFT)}: " + " | ".join(a["drift"]))
    for b in bad:
        print(b)
    return agent_log.emit_result("FAIL" if bad else "PASS", checks=len(WANT_DRIFT) + len(WANT_REVIEW) + len(WANT_PLAN) + 2, bad=len(bad))
