#!/usr/bin/env python3
"""Exploratory prove: start from what changed, find what refers to it, run the checks those areas need, flag drift.

    python tools/check.py prove [--plan] [--all] [--base REV] [--head REV] [--verbose]

Changed set: `git diff` from merge-base(origin/main, HEAD) to the working tree (commits plus uncommitted and untracked).
Graph (prove_graph.py): every file that names a changed file (path, res:// path, `entry.py sub`, module import,
class_name, json file name): doc links and routes.yaml, BOT.md / tools*.md job tables, task resume/first lines,
workflow skills, CI workflows and hooks, tools importing a changed lib, scripts and scenes preloading a changed
script, data consumers, shot flows. Checks: tools/data/prove_rules.json maps touched paths to commands; built in:
@selftests (changed tools, importers of changed libs, readers of changed data) and @smokes (gate.py bot-smokes
--for the changed scripts). A .gd change that is comment-only (same code with comments stripped) skips the Godot
checks. Each chosen check prints with why. Fails: DRIFT (a path, subcommand, flag, function, node, group or data key
the diff removed that a file still names), CLAIM (a new comment naming a tool module this diff did not touch),
STALE (an untouched dependent's line, in a paragraph naming a tool whose docstring changed, repeating a token of the
new docstring). REVIEW (advisory): a changed signature with callers outside the diff, a tool whose docstring changed
while a dependent that describes it did not.
Per-cluster quick check: --base @{u} (only what this cluster adds over the pushed branch); the pre-push full prove
keeps the merge-base with origin/main.
--plan prints the plan and drift and runs nothing (a --head replay is always --plan). --all runs every rule.
RESULT PASS = every chosen check exit 0 and no DRIFT. Summary: _logs/prove/.
"""
from __future__ import annotations

import fnmatch
import json
import re
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402

import agent_log
import prove_graph as pg

RULES = boot.DATA / "prove_rules.json"
DOC_KINDS = ("doc", "job-table", "task", "skill", "routes", "tool", "ci", "hook")

def analyse(root: Path, base: str, head: str | None) -> dict:
    """Changed set, dependents, drift and review for base..head (head None: working tree)."""
    changes = pg.changes(root, base, head)
    old, new = pg.Tree(root, base), pg.Tree(root, head)
    new.preload()
    ents_new, ents_old = pg.entries(new), pg.entries(old)
    bn_new = Counter(p.rsplit("/", 1)[-1] for p in new.files)
    bn_old = Counter(p.rsplit("/", 1)[-1] for p in old.files)
    changed = {c.path for c in changes} | {c.old for c in changes}
    owner_names: dict[str, str] = {}
    for c in changes:
        tree, ents, bn = (old, ents_old, bn_old) if c.status == "D" else (new, ents_new, bn_new)
        for n in pg.names_of(c.old if c.status == "D" else c.path, tree, ents, bn):
            owner_names.setdefault(n, c.path)
    hits = pg.scan(new, owner_names)
    deps: dict[str, set[str]] = {}  # changed file -> files that name it
    edges = []
    for name, rows in hits.items():
        own = owner_names[name]
        for f, kind, no, line in rows:
            if f != own:
                deps.setdefault(own, set()).add(f)
                tag = " (resume/first line)" if kind == "task" and re.match(r"(resume|first):", line) else ""
                edges.append((own, f, kind, name, no, tag))
    gones = [g for c in changes for g in pg.gone(c, old, new, ents_new, bn_new)]
    names_by: dict[str, list[str]] = {}
    for n, own in owner_names.items():
        names_by.setdefault(own, []).append(n)
    drift, review = _drift(gones, changes, old, new, deps, changed, names_by)
    drift += _claims(changes, new, changed)
    cosmetic = {c.path for c in changes if c.status == "M" and c.path.endswith(".gd")
                and pg.gd_code(old.text(c.old) or "") == pg.gd_code(new.text(c.path) or "")}
    return {"changes": changes, "deps": deps, "edges": edges, "drift": drift, "review": review, "new": new, "ents": ents_new,
            "cosmetic": cosmetic}

def _drift(gones, changes, old, new, deps, changed, names_by) -> tuple[list[str], list[str]]:
    allow = set(json.loads(RULES.read_text(encoding="utf-8")).get("drift_allow", []))
    want: dict[str, list] = {}
    for g in gones:
        if g.what in ("path", "command", "flag", "node", "member"):
            want.setdefault(g.symbol, []).append(g)
        elif g.what == "key":
            want.setdefault(f'"{g.symbol}"', []).append(g)
    hits = pg.scan(new, {k: "" for k in want})
    for g in gones:  # functions: look for calls in the files that already name the owner
        if g.what in ("def", "sig"):
            call = re.compile(rf"(?<![\w])(?:[\w]+\.)?{re.escape(g.symbol)}\s*\(|`[\w.]*\b{re.escape(g.symbol)}\b")
            rows = [(f, pg.kind_of(f), no, line.strip()) for f in sorted(deps.get(g.owner, set()))
                    for no, line in enumerate((new.text(f) or "").splitlines(), 1) if g.symbol in line and call.search(line)]
            want.setdefault(f"{g.what}:{g.symbol}", []).append(g)
            hits[f"{g.what}:{g.symbol}"] = rows
    drift, review = [], []
    for sym, gs in want.items():
        for g in gs:
            if g.what == "path" and g.symbol in new.set:
                continue
            users = deps.get(g.owner, set())
            for f, kind, no, line in hits.get(sym, []):
                if f == g.owner or f"{f}|{g.symbol}" in allow:
                    continue
                where = f"{f}:{no} [{kind}]{' (resume/first line)' if kind == 'task' and re.match(r'(resume|first):', line) else ''}{' (untouched)' if f not in changed else ''}"
                if g.what == "flag" and not any(t in line for t in g.ctx):
                    continue
                if g.what == "node" and (kind not in ("shot-flow", "data", "script", "scene") or not pg.node_ref(g.symbol, line)):
                    continue
                if g.what == "key" and f not in users:
                    continue
                if g.what == "member" and kind not in DOC_KINDS and f not in users:
                    continue
                if g.what in ("def", "sig"):
                    if g.what == "sig":
                        if f not in changed:
                            review.append(f"REVIEW  signature of {g.symbol}() changed in {g.owner}; caller {where}")
                        continue
                label = {"path": "removed path", "command": "removed subcommand", "flag": "removed flag",
                         "def": "removed function", "node": "removed node/group", "key": "removed data key",
                         "member": "removed const/var"}[g.what]
                drift.append(f"DRIFT   {label} {g.symbol} ({g.owner}) still named at {where}: {line[:90]}")
    # a tool whose docstring or help text changed: dependents that describe it but were not touched
    stems = {Path(f).stem for f in new.files if f.endswith((".py", ".gd"))}
    for c in changes:
        if not c.path.startswith("tools/"):
            continue
        at = pg.doc_changed(c, old.text(c.old) or "", new.text(c.path) or "")
        src = new.text(c.path) or ""
        prose = [ln for i, ln in enumerate(c.added) if pg.is_prose(c, i, src) or "help=" in ln] if at else []
        for f in sorted(deps.get(c.path, set()) - changed) if at else []:
            stale = pg.stale_lines(c.path, names_by.get(c.path, []), prose, f, new.text(f) or "", stems)
            for no, line in stale:
                drift.append(f"STALE   {c.path} docstring/help changed (line {at}); {f}:{no} [{pg.kind_of(f)}] (untouched) repeats it: {line[:90]}")
            if not stale and pg.kind_of(f) in DOC_KINDS:
                review.append(f"REVIEW  {c.path} docstring/help changed (line {at}); {f} names it and is untouched")
    return drift, review

def _claims(changes, new, changed) -> list[str]:
    """New comment/docstring lines that name another tool module this diff did not touch."""
    stems: dict[str, str] = {}
    for p in new.files:
        if p.startswith("tools/") and p.endswith(".py") and "_" in Path(p).stem:
            stems.setdefault(Path(p).stem, p)
    out = []
    for c in changes:
        if not c.path.endswith((".py", ".gd")) or c.status == "D":
            continue
        src = new.text(c.path) or ""
        for i, line in enumerate(c.added):
            if not pg.is_prose(c, i, src):
                continue
            for w in sorted(set(re.findall(r"\b([a-z][a-z0-9]*_[a-z0-9_]+)\b(?!\.(?!py\b)\w)", line))):
                p = stems.get(w)
                if p and p != c.path and p not in changed:
                    out.append(f"CLAIM   {c.path}:{c.added_at[i]} new comment names {w} ({p}), untouched here: check the claim: {line.strip()[:80]}")
    return out

def plan(root: Path, a: dict, run_all: bool) -> list[tuple[str, str, list[str]]]:
    """[(id, command, why lines)] in rule order."""
    rules = json.loads(RULES.read_text(encoding="utf-8"))["checks"]
    paths = [c.path for c in a["changes"]]
    stats = {c.status for c in a["changes"]}
    out = []
    for r in rules:
        hit = [p for p in paths if any(fnmatch.fnmatch(p, g) for g in r["when"]) and not (r.get("godot") and p in a["cosmetic"])]
        st = sorted(stats & set(r.get("when_status", [])))
        if not (hit or st or run_all):
            continue
        why = r["why"] + (f" <- {', '.join(hit[:2])}{f' +{len(hit) - 2}' if len(hit) > 2 else ''}" if hit and r["when"] != ["*"] else "")
        why += f" <- status {''.join(st)}" if st and not hit else ""
        if r["cmd"] == "@selftests":
            for cmd, w in _selftests(a):
                out.append(("selftest", cmd, w))
        elif r["cmd"] == "@smokes":
            gd = [p for p in hit if p.endswith((".gd", ".tscn")) and (root / p).is_file()]
            phases = _phases(root, gd) if gd else ""
            if phases:
                out.append(("smokes", f"python3 tools/gate.py bot-smokes --phases {phases} --no-gaps", r["why"] + f" <- {len(gd)} file(s)"))
        else:
            out.append((r["id"], r["cmd"], why))
    return out

SELFTEST_FLAG = re.compile(r"""^\s*(?:\w+\.add_argument\(\s*['"]--selftest|.*['"]--selftest['"]\s+in\s+sys\.argv)""", re.M)

def _selftests(a: dict) -> list[tuple[str, str]]:
    new, ents = a["new"], a["ents"]
    pick: dict[str, str] = {}
    for c in a["changes"]:
        if c.path.startswith("tools/") and c.path.endswith(".py") and c.status != "D":
            pick.setdefault(c.path, "changed")
    for own, f, kind, name, no, tag in a["edges"]:
        if kind == "tool" and f.endswith(".py") and (name.startswith(("import ", "from ")) or own.startswith("tools/data/")):
            pick.setdefault(f, f"reads {own.rsplit('/', 1)[-1]}")
    out = []
    for p, why in sorted(pick.items()):
        src = new.text(p) or ""
        e = ents.get(p)
        # Its own flag (argparse or argv test, not a mention); a lib run by path also needs a __main__ block.
        if not SELFTEST_FLAG.search(src) or re.search(r"^(COMMANDS|MODULE)\s*=", src, re.M) or (not e and "__main__" not in src):
            continue
        cmd = f"python3 tools/{e[0]}.py {e[1] or ''} --selftest".replace("  ", " ") if e else f"python3 {p} --selftest"
        out.append((cmd, f"selftest: {p} ({why})"))
    return out

def _phases(root: Path, files: list[str]) -> str:
    r = subprocess.run([sys.executable, "tools/gate.py", "bot-smokes", "--for", *files], cwd=root, capture_output=True, text=True)
    m = re.search(r"phases=([\d,]+)", r.stdout)
    return m.group(1) if m else ""

def run(root: Path, steps) -> list[tuple[int, str, str, float]]:
    out = []
    for _, cmd, _ in steps:
        t = time.time()
        r = subprocess.run(cmd.split(), cwd=root, capture_output=True, text=True)
        res = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("RESULT")]
        tail = "" if r.returncode == 0 else " | ".join((r.stdout + r.stderr).strip().splitlines()[-4:])[:300]
        out.append((r.returncode, cmd, (res[-1] if res else "(no RESULT)") + (f"\n      {tail}" if tail else ""), time.time() - t))
    return out

def main() -> int:
    ap = agent_log.std_parser(__doc__.split("\n")[0], verbose=True)
    ap.add_argument("--base", default=None, help="Diff base (default: merge-base of origin/main and HEAD; @{u} = the per-cluster quick check).")
    ap.add_argument("--head", default=None, help="Diff head commit (default: the working tree); implies --plan.")
    ap.add_argument("--plan", action="store_true", help="Print the plan, graph and drift; run nothing.")
    ap.add_argument("--all", dest="run_all", action="store_true", help="Run every rule, not only the triggered ones.")
    ap.add_argument("--selftest", action="store_true", help="Replay built-in breakages in a throwaway repo.")
    args = ap.parse_args()
    if args.selftest:
        import prove_selftest
        return prove_selftest.main()
    root = agent_log.resolve_root(args)
    base = pg.git(root, "rev-parse", "--verify", "-q", args.base + "^{commit}").strip() if args.base else pg.git(root, "merge-base", "origin/main", "HEAD").strip()
    if not base:
        agent_log.fail(f"no such base: {args.base or 'merge-base origin/main HEAD'}")
    t0 = time.time()
    a = analyse(root, base, args.head)
    steps = plan(root, a, args.run_all)
    st = Counter(c.status for c in a["changes"])
    kinds = Counter(f[2] for f in {(e[1], e[0], e[2]) for e in a["edges"]})
    lines = [f"changed={len(a['changes'])} ({' '.join(f'{k}{v}' for k, v in sorted(st.items()))}) base={base[:8]} head={(args.head or 'worktree')[:8]}",
             f"graph: {sum(len(v) for v in a['deps'].values())} dependents ({', '.join(f'{k} {v}' for k, v in kinds.most_common())})"]
    body = list(lines)
    body += [f"  {own} <- {f}:{no} [{kind}] {name}{tag}" for own, f, kind, name, no, tag in sorted(set(a["edges"]))]
    chosen = [f"RUN  {cmd}   # {why}" for _, cmd, why in steps]
    lines += chosen
    body += chosen
    ran = []
    if not (args.plan or args.head):
        ran = run(root, steps)
        rows = [f"rc={rc} {s:.0f}s :: {cmd} :: {res}" for rc, cmd, res, s in ran]
        lines += agent_log.fold(rows, args.verbose, keep=14, limit=16)
        body += rows
    for label, rows in (("drift", a["drift"]), ("review", a["review"])):
        rows = sorted(dict.fromkeys(rows))
        lines += agent_log.fold(rows, args.verbose, keep=6, limit=8)
        body += rows
    failed = sum(1 for r in ran if r[0] != 0)
    status = "FAIL" if failed or a["drift"] else "PASS"
    return agent_log.finish("prove", root, "\n".join(body), status, args=args, echo="\n".join(lines),
                            changed=len(a["changes"]), deps=sum(len(v) for v in a["deps"].values()), chose=len(steps),
                            ran=len(ran), failed=failed, drift=len(set(a["drift"])), review=len(set(a["review"])), sec=round(time.time() - t0))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
