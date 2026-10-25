"""`docs.py tunable --selftest`: replays set / range / add / diff on a scratch copy of the balance sources, the
tunables docs, val_cat_map.gd and the changelog folder. The repo itself is never written (checked by hash).
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import shutil
import subprocess
import tempfile
from pathlib import Path

import agent_log
import balance_src as bs

COPY = ("project.godot", "scripts/data/balance", bs.TCONST, bs.CATMAP, "design/changelog") + tuple(f"design/{n}" for n in bs.DOC.values())

def _hash(root: Path) -> str:
    h = hashlib.sha256()
    for rel in COPY:
        p = root / rel
        for f in sorted(p.rglob("*") if p.is_dir() else [p]):
            if f.is_file():
                h.update(f.read_bytes())
    return h.hexdigest()

def _run(scratch: Path, *argv: str) -> tuple[int, str]:
    import tunables
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            rc = tunables.main([*argv[:1], *argv[1:], "--root", str(scratch)])
        except SystemExit as e:
            rc = int(e.code or 0) if not isinstance(e.code, str) else 2
    return rc, out.getvalue()

def main() -> int:
    root = agent_log.resolve_root(type("A", (), {"root": None})())
    before = _hash(root)
    checks: list[tuple[str, bool]] = []
    with tempfile.TemporaryDirectory(prefix="wdb-tunables-") as td:
        sc = Path(td)
        for rel in COPY:
            src, dst = root / rel, sc / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            (shutil.copytree if src.is_dir() else shutil.copy2)(src, dst)
        subprocess.run(["git", "init", "-q"], cwd=sc, check=False)

        def ok(name: str, cond: bool) -> None:
            checks.append((name, bool(cond)))

        def txt(rel: str) -> str:
            return (sc / rel).read_text(encoding="utf-8-sig")

        ok("diff clean on a copy", _run(sc, "diff")[0] == 0)
        rc, _ = _run(sc, "set", "special_mana", "30")
        ok("set float -> vars_combat", rc == 0 and "var special_mana := 30.0" in txt(f"{bs.BAL}/vars_combat.gd"))
        ok("set keeps diff clean (doc row follows)", _run(sc, "diff")[0] == 0)
        rc, out = _run(sc, "set", "special_mana", "500")
        ok("set outside slider fails", rc != 0 and "--range" in out)
        rc, _ = _run(sc, "set", "special_mana", "500", "--range")
        ok("set --range widens the row", rc == 0 and '["special_mana", 0.0, 500.0, 1.0]' in txt(f"{bs.BAL}/schema_a.gd"))
        _run(sc, "set", "special_mana", "30")
        ok("set bool rejects 2", _run(sc, "set", "axe_los", "2")[0] != 0)
        ok("set int rejects 1.5", _run(sc, "set", "gen_w", "1.5")[0] != 0)
        rc, _ = _run(sc, "set", "move_speed", "4.75")
        ok("set T.* ref edits tunables.gd", rc == 0 and "const MOVE_SPEED := 4.75" in txt(bs.TCONST))
        rc, _ = _run(sc, "set", "e_orc_hp", "120")
        ok("set e_* edits enemies.gd", rc == 0 and '"orc": {"hp": 120.0' in txt(bs.ENEMIES))
        ok("range: default must stay inside", _run(sc, "range", "special_mana", "0", "10")[0] != 0)
        rc, _ = _run(sc, "range", "special_mana", "0", "200", "5")
        ok("range min max step", rc == 0 and '["special_mana", 0.0, 200.0, 5.0]' in txt(f"{bs.BAL}/schema_a.gd"))
        rc, out = _run(sc, "range", "e_slime_hp", "5", "300")
        ok("range e_* edits the shared stat row", rc == 0 and '"e_%s_hp" % id, 5.0, 300.0, 1.0' in txt(bs.ENEMIES) and "12 enemies" in out)
        ok("range e_*: every enemy default checked", _run(sc, "range", "e_*_hp", "5", "100")[0] != 0)
        ok("diff clean after set/range", _run(sc, "diff")[0] == 0)
        rc, out = _run(sc, "add", "zz_selftest_gain", "--default", "0.5", "--range", "0", "2", "0.05", "--after", "special_mana",
                       "--note", "selftest key", "--cat", "Combat")
        vc = txt(f"{bs.BAL}/vars_combat.gd")
        ok("add: var after its neighbor", rc == 0 and "var special_mana := 30.0\nvar zz_selftest_gain := 0.5\n" in vc)
        ok("add: slider row", '["zz_selftest_gain", 0.0, 2.0, 0.05],' in txt(f"{bs.BAL}/schema_a.gd"))
        ok("add: debug-menu rule", '["zz_selftest_gain", "Combat"],' in txt(bs.CATMAP) and bs.Src(sc).category("zz_selftest_gain") == "Combat")
        ok("add: doc row with note", "| `zz_selftest_gain` |" in txt("design/tunables-combat.md") and "| 0.5 | selftest key |" in txt("design/tunables-combat.md"))
        ok("add: diff clean", _run(sc, "diff")[0] == 0)
        rc, _ = _run(sc, "set", "dash_cooldown", "1.2", "--changelog", "Dash recovers slower.", "--label", "9.9.9")
        ok("set --changelog adds one bullet", rc == 0 and "- Dash recovers slower." in txt("design/changelog/9.9.9.md"))
        rc, out = _run(sc, "list", "special_")
        ok("list prefix", rc == 0 and "special_mana\t30.0\tfloat\t[0.0..200.0 /5.0]\tcombat\tCombat" in out)
        ok("legacy doc get still works", _run(sc, "get", "special_mana")[0] == 0)
        ok("add duplicate fails", _run(sc, "add", "zz_selftest_gain", "--default", "1.0", "--range", "0", "2", "0.05", "--after", "special_mana")[0] != 0)
        ok("add e_* fails", _run(sc, "add", "e_slime_luck", "--default", "1.0", "--range", "0", "2", "0.05", "--system", "world", "--doc-after", "gen_w")[0] != 0)
        ok("add bad name fails", _run(sc, "add", "Bad-Key", "--default", "1.0", "--range", "0", "2", "0.05", "--system", "combat")[0] != 0)
        ok("add default out of range fails", _run(sc, "add", "zz_two", "--default", "5.0", "--range", "0", "2", "0.05", "--after", "special_mana")[0] != 0)
        rc, out = _run(sc, "add", "zz_unfiled", "--default", "1", "--range", "0", "4", "1")
        ok("add with no system fails as ambiguous", rc != 0 and "ambiguous" in out)
        vrel = sc / bs.BAL / "vars_world.gd"
        pad = vrel.read_text(encoding="utf-8")
        vrel.write_text(pad + "#" * (bs.CAP - len(pad.encode()) - 5) + "\n", encoding="utf-8")
        size0 = vrel.stat().st_size
        rc, out = _run(sc, "add", "gen_zz_big", "--default", "1.0", "--range", "0", "2", "0.05", "--system", "world", "--doc-after", "gen_w")
        ok("10 KB guard: refuses, writes nothing", rc != 0 and "would be" in out and vrel.stat().st_size == size0 and "gen_zz_big" not in txt(bs.CATMAP + "") + txt(f"{bs.BAL}/schema_b.gd"))
    ok("repo untouched", _hash(root) == before)
    bad = [n for n, c in checks if not c]
    body = "\n".join(f"{'PASS' if c else 'FAIL'}  {n}" for n, c in checks)
    return agent_log.finish("tunable-selftest", root, body, "FAIL" if bad else "PASS", echo=body, cases=len(checks), failed=len(bad))
