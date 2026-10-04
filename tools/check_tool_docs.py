#!/usr/bin/env python3
"""Check the tools catalog (design/tools*.md) against tools/ and tools/bot_allow.txt.

--stale-refs scans the docs (design/*.md without changelog/, root *.md, skills) for dead references:
PATH (backticked path or file name that is not in the tree), IDENT (`Class.member` whose class_name
script has no such member) and, with --narration, NARR lines (will be added, TODO, legacy, formerly,
previously, no longer, old flat paths). PATH/IDENT fail the run; NARR is advisory (RESULT INFO).
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib
from bot_smokes import VERSION as ENGINE_PIN

CATALOGS = ("tools.md", "tools-lint.md", "tools-build.md", "tools-media.md")
ROW = re.compile(r"^\|\s*`([^`|]+)`\s*\|.*\|\s*([BWD]+)\s*\|[^|]*\|\s*([YN])\s*\|\s*$")


SKILL_DIR = Path("/home/box/agent-data/workflows")
SUFFIX = (".gd", ".py", ".md", ".tscn", ".json", ".yaml", ".yml", ".cfg", ".html", ".txt", ".shader", ".tres", ".uid")
TICK = re.compile(r"`([^`\n]+)`")
PATH_SKIP = ("_logs/", "_out/", "user://", "http", ".godot/", "docs/", "design/changelog/")
NARR = re.compile(r"\b(will be added|to be added|TODO|TBD|legacy|formerly|previously|no longer|used to|not yet|for now|old flat|temporary|deprecated|obsolete|superseded)\b", re.I)
ENGINE_VER = re.compile(r"\b4\.\d+\.\d+\b")  # Godot 4.x.y mentions in docs / CI must equal bot_smokes.VERSION
MEMBER = re.compile(r"^\s*(?:static\s+)?(?:func|var|const|signal|enum|class)\s+(\w+)", re.M)


def _doc_files(root: Path, tracked: set[str]) -> list[Path]:
    out = [root / n for n in sorted(tracked) if n.endswith(".md") and (n.startswith("design/") or "/" not in n)
           and not n.startswith("design/changelog/")]
    if SKILL_DIR.is_dir():
        out += sorted(SKILL_DIR.glob("*/SKILL.md"))
    return out


def stale_refs(root: Path, narration: bool) -> tuple[list[str], list[str]]:
    git = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True).stdout.split("\n")
    tracked = {g for g in git if g}
    names = {g.rsplit("/", 1)[-1] for g in tracked}
    gone = subprocess.run(["git", "log", "--diff-filter=D", "--name-only", "--pretty=format:"], cwd=root, capture_output=True, text=True).stdout.split("\n")
    gone_names = {g.rsplit("/", 1)[-1] for g in gone if g} - names
    def ignored(tok: str) -> bool:
        """Gitignored runtime paths (tools/anim_review/...) are not dead refs even when the dir is absent."""
        return subprocess.run(["git", "check-ignore", "-q", "--", tok], cwd=root, capture_output=True).returncode == 0
    classes: dict[str, set[str]] = {}
    for g in tracked:
        if g.endswith(".gd"):
            src = (root / g).read_text(encoding="utf-8-sig", errors="replace")
            m = re.search(r"^class_name\s+(\w+)", src, re.M)
            if m:
                classes[m.group(1)] = set(MEMBER.findall(src))
    bad: list[str] = []
    narr: list[str] = []
    for f in _doc_files(root, tracked):
        name = f.relative_to(root).as_posix() if f.is_relative_to(root) else f.parent.name + "/SKILL.md"
        in_fence = False
        for no, line in enumerate(f.read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if narration and not in_fence and NARR.search(line):
                narr.append(f"NARR    {name}:{no}: {line.strip()[:110]}")
            for tok in TICK.findall(line):
                tok = tok.strip()
                if tok.startswith("res://"):
                    tok = tok[6:]
                if " " in tok or any(c in tok for c in "*<>{}$%|=()[]\\:,;~") or tok.startswith(("-", ".", "/")) or any(tok.startswith(s) for s in PATH_SKIP):
                    pass
                elif tok.endswith(SUFFIX) and "." in tok.rsplit("/", 1)[-1]:
                    if tok.endswith("_scratch.py") or ignored(tok) or (not f.is_relative_to(root) and (f.parent / tok).exists()):
                        continue
                    if tok.rstrip("/") not in tracked and not (root / tok).exists() and not any(g.endswith("/" + tok) for g in tracked) and (("/" in tok) or tok in gone_names):
                        bad.append(f"PATH    {name}:{no}: {tok}")
                    continue
                m = re.match(r"^([A-Z]\w+)\.(\w+)(?:\(.*)?$", tok)
                if m and m.group(1) in classes and m.group(2) not in classes[m.group(1)]:
                    bad.append(f"IDENT   {name}:{no}: {m.group(1)}.{m.group(2)}")
    for f in [*_doc_files(root, tracked), root / ".github/workflows/pages.yml"]:
        if f.is_file() and f.is_relative_to(root):
            for no, line in enumerate(f.read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
                bad += [f"ENGINE  {f.relative_to(root).as_posix()}:{no}: {v} != pinned {ENGINE_PIN}" for v in ENGINE_VER.findall(line) if v != ENGINE_PIN]
    return bad, narr


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check the tools catalog (design/tools*.md) against tools/ and tools/bot_allow.txt (A=Y needs the path allowed; globs and ! denies count).", json_out=True)
    ap.add_argument("--stale-refs", action="store_true", help="Scan docs for dead paths and Class.member identifiers instead of checking the catalog.")
    ap.add_argument("--narration", action="store_true", help="With --stale-refs: also list will-be-added / legacy / formerly / no-longer lines (advisory).")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    if args.stale_refs:
        bad, narr = stale_refs(root, args.narration)
        head = f"stale-refs: dead={len(bad)} narration={len(narr)}"
        return agent_log.finish("stale-refs", root, "\n".join(bad + narr + [head]), "FAIL" if bad else ("INFO" if narr else "PASS"),
                                args=args, legacy=False, dead=len(bad), narration=len(narr))
    tools = root / "tools"
    files = {f.name for f in tools.iterdir() if f.is_file() and f.name != "_scratch.py"}
    globs = repo_lib.load_allowlist(root)
    allow = {n for n in files if repo_lib.allowed(f"tools/{n}", globs)}  # honours globs (`tools/*`), `!` denies and exact lines
    exact = {g[len("tools/"):] for g in globs if g.startswith("tools/") and not any(c in g for c in "*?[!")}
    rows: dict[str, tuple[str, str]] = {}
    bad: list[str] = []
    for cat in CATALOGS:
        for ln in (root / "design" / cat).read_text(encoding="utf-8").splitlines():
            m = ROW.match(ln)
            if not m:
                continue
            name, surf, a = m.groups()
            if name in rows:
                bad.append(f"DUP     {name} (also in another row)")
            rows[name] = (surf, a)
    for n in sorted(files - rows.keys()):
        bad.append(f"MISSING {n}: no catalog row")
    for n in sorted(rows.keys() - files):
        bad.append(f"STALE   {n}: catalog row but no such file")
    for n in sorted(exact - files):
        bad.append(f"ALLOW   {n}: on bot_allow.txt but no such file")
    for n, (surf, a) in sorted(rows.items()):
        if n in files and a == "Y" and n not in allow:
            bad.append(f"ALLOWED {n}: catalog A=Y but tools/{n} is not allowed by bot_allow.txt (add a line or mark A=N)")
        if a == "Y" and "B" not in surf and "D" not in surf:
            bad.append(f"SURF    {n}: allowlisted but no B/D surface")
        if a == "Y" and n.endswith(".py") and n in files:
            t = (tools / n).read_text(encoding="utf-8-sig", errors="replace")
            if '"""' not in t[:600] and "argparse" not in t:
                bad.append(f"HELP    {n}: allowlisted .py without docstring or argparse")
    head = f"tool-docs: tools={len(files)} rows={len(rows)} allowlisted={len(allow)} problems={len(bad)}"
    if bad:
        bad.append("next: MISSING = add a row to the design/tools*.md catalog (new tool: tools.md rule 5); ALLOWED/ALLOW = fix tools/bot_allow.txt or the A column; then rerun")
    return agent_log.finish("tool-docs", root, "\n".join(bad + [head]), "FAIL" if bad else "PASS", args=args,
                            legacy=False, tools=len(files), rows=len(rows), problems=len(bad))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
