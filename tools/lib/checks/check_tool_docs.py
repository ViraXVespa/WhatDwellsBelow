#!/usr/bin/env python3
"""Check the tools catalog (design/tools*.md) against the entry tools and tools/bot_allow.txt.

Catalog rows name commands: one row per entry subcommand (`shots.py capture`), or the entry alone when it has
no subcommands (`bot_status.py`). Every lib module (tools/lib/**/*.py that is not a subcommand, plus
`lib/imglib/`) and every data file (tools/data/*, tools/*.txt) must be named in backticks in some tools*.md.

--stale-refs scans the docs (design/*.md without changelog/, root *.md, repo and box skills) for dead references:
PATH (backticked path or file name that is not in the tree), IDENT (`Class.member` whose class_name
or one-target preload alias script has no such member, inherited ones counted) and, with --narration, NARR lines (will be added, TODO, legacy, formerly,
previously, no longer, old flat paths). It also runs `stale_cmds` over tracked docs, code, data and CI for
FLAG/SUB/TOOL (a tool command naming a flag or subcommand that tool lacks, or a dead tools/*.py path).
PATH/IDENT/FLAG/SUB/TOOL fail the run; NARR is advisory (RESULT INFO). --selftest checks the command scan and the doc set.
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402

import agent_log
import repo_lib
import stale_cmds
from godot_lib import VERSION as ENGINE_PIN

CATALOG_GLOB = "tools*.md"  # the door (tools.md) plus every tools-<area>.md sibling
ROW = re.compile(r"^\|\s*`([^`|]+)`\s*\|.*\|\s*([BWD]+)\s*\|[^|]*\|\s*([YN])\s*\|\s*$")

SKILL_DIR = Path("/home/box/agent-data/workflows")
SUFFIX = (".gd", ".py", ".md", ".tscn", ".json", ".yaml", ".yml", ".cfg", ".html", ".txt", ".shader", ".tres", ".uid")
TICK = re.compile(r"`([^`\n]+)`")
PATH_SKIP = ("_logs/", "_out/", "user://", "http", ".godot/", "docs/", "design/changelog/")
NARR = re.compile(r"\b(will be added|to be added|TODO|TBD|legacy|formerly|previously|no longer|used to|not yet|for now|old flat|temporary|deprecated|obsolete|superseded)\b", re.I)
ENGINE_VER = re.compile(r"\b4\.\d+\.\d+\b")  # Godot 4.x.y mentions in docs / CI must equal godot_lib.VERSION
MEMBER = re.compile(r"^\s*(?:static\s+)?(?:func|var|const|signal|enum|class)\s+(\w+)", re.M)

def _doc_files(root: Path, tracked: set[str]) -> list[Path]:
    out = [root / n for n in sorted(tracked) if n.endswith(".md") and (n.startswith(("design/", ".grok/skills/")) or "/" not in n)
           and not n.startswith("design/changelog/")]
    if SKILL_DIR.is_dir():
        out += sorted(SKILL_DIR.glob("*/SKILL.md"))
    return out

PRELOAD = re.compile(r'^const\s+([A-Z]\w*)\s*(?::\s*\w+)?\s*:?=\s*preload\("res://([^"]+\.gd)"\)', re.M)

def gd_classes(root: Path, tracked: set[str]) -> dict[str, set[str]]:
    """Name -> members (inherited via `extends "res://..."` too) for each class_name and each preload alias
    (`const Stamp := preload("res://...gd")`) that names one script everywhere; a doc's `Stamp.SUB` is checked against it."""
    src = {g: (root / g).read_text(encoding="utf-8-sig", errors="replace") for g in tracked if g.endswith(".gd")}
    def members(g: str, seen: tuple = ()) -> set[str]:
        out = set(MEMBER.findall(src.get(g, "")))
        m = re.search(r'^extends\s+"res://([^"]+\.gd)"', src.get(g, ""), re.M)
        return out | members(m.group(1), seen + (g,)) if m and m.group(1) not in seen else out
    targets: dict[str, set[str]] = {}
    for g, text in src.items():
        for alias, path in PRELOAD.findall(text):
            targets.setdefault(alias, set()).add(path)
    classes = {a: members(next(iter(ps))) for a, ps in targets.items() if len(ps) == 1 and next(iter(ps)) in src}
    for g, text in src.items():
        m = re.search(r"^class_name\s+(\w+)", text, re.M)
        if m:
            classes[m.group(1)] = members(g)
    return classes

def stale_refs(root: Path, narration: bool) -> tuple[list[str], list[str]]:
    git = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True).stdout.split("\n")
    tracked = {g for g in git if g and (root / g).exists()}  # a tracked file deleted in the working tree is gone
    names = {g.rsplit("/", 1)[-1] for g in tracked}
    gone = subprocess.run(["git", "log", "--diff-filter=D", "--name-only", "--pretty=format:"], cwd=root, capture_output=True, text=True).stdout.split("\n")
    gone_names = {g.rsplit("/", 1)[-1] for g in gone if g} - names
    def ignored(tok: str) -> bool:
        """Gitignored runtime paths (tools/anim_review/...) are not dead refs even when the dir is absent."""
        return subprocess.run(["git", "check-ignore", "-q", "--", tok], cwd=root, capture_output=True).returncode == 0
    classes = gd_classes(root, tracked)
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
                    if tok.endswith("_scratch.py") or ignored(tok) or (f.parent / tok).exists():
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
    return bad + stale_cmds.scan(root, tracked) + stale_cmds.branch_scan(root, tracked), narr

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check the tools catalog (design/tools*.md) against the entry tools and tools/bot_allow.txt (A=Y needs the entry allowed; globs and ! denies count).", json_out=True, verbose=True)
    ap.add_argument("--stale-refs", action="store_true", help="Scan docs for dead paths and Class.member identifiers, and the repo for tool commands with unknown flags/subcommands, instead of checking the catalog.")
    ap.add_argument("--selftest", action="store_true", help="Check the stale-refs command scan on fixed lines and the scanned doc set.")
    ap.add_argument("--narration", action="store_true", help="With --stale-refs: also list will-be-added / legacy / formerly / no-longer lines (advisory).")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        bad = stale_cmds.selftest(root)
        docs = {f.relative_to(root).as_posix() for f in _doc_files(root, {".grok/skills/z/SKILL.md", "design/a.md", "design/changelog/x.md", "README.md", "scripts/a.md"}) if f.is_relative_to(root)}
        if docs != {".grok/skills/z/SKILL.md", "design/a.md", "README.md"}:
            bad.append(f"stale-refs doc set {sorted(docs)}: want repo skills, design/ (no changelog) and root *.md")
        with tempfile.TemporaryDirectory() as tmp:  # IDENT: preload aliases and inherited members
            t = Path(tmp)
            for rel, text in (("k.gd", "const SUB := 4\n"), ("s.gd", 'extends "res://k.gd"\nfunc bake():\n\tpass\n'),
                              ("a.gd", 'const Stamp := preload("res://s.gd")\nconst Two := preload("res://k.gd")\n'), ("b.gd", 'const Two := preload("res://s.gd")\n')):
                (t / rel).write_text(text, encoding="utf-8")
            got = gd_classes(t, {"k.gd", "s.gd", "a.gd", "b.gd"})
            if got.get("Stamp") != {"SUB", "bake"} or "Two" in got:
                bad.append(f"stale-refs classes {got}: want Stamp = s.gd + inherited SUB, no two-target alias Two")
        return agent_log.finish("tool-docs-selftest", root, "\n".join(bad + [f"selftest: fail={len(bad)}"]), "FAIL" if bad else "PASS", args=args, legacy=False)
    if args.stale_refs:
        bad, narr = stale_refs(root, args.narration)
        head = f"stale-refs: dead={len(bad)} narration={len(narr)}"
        echo = "\n".join(agent_log.fold(bad + narr, args.verbose, keep=20, limit=28) + [head])
        return agent_log.finish("stale-refs", root, "\n".join(bad + narr + [head]), "FAIL" if bad else ("INFO" if narr else "PASS"),
                                args=args, echo=echo, legacy=False, dead=len(bad), narration=len(narr))
    tools = root / "tools"
    table = boot.entries(tools)
    files = {f"{e}.py" + (f" {sub}" if sub else "") for e, rows_ in table.items() for sub, _, _ in rows_}  # catalog names: commands
    entry_of = {n: n.split(" ", 1)[0] for n in files}
    sub_mods = {f"lib/{m}.py" for rows_ in table.values() for _, m, _ in rows_}
    lib = tools / "lib"
    named = {f"lib/{p.relative_to(lib).as_posix()}" for p in lib.rglob("*.py") if "imglib" not in p.parts and "__pycache__" not in p.parts} - sub_mods
    named |= {"lib/imglib/"} | {f"data/{p.name}" + ("/" if p.is_dir() else "") for p in (tools / "data").iterdir()}
    named |= {p.name for p in tools.iterdir() if p.is_file() and p.suffix != ".py" and not p.name.startswith(".")}
    stray = sorted(p.name for p in tools.glob("*.py") if p.stem not in table and p.name != "_scratch.py")
    globs = repo_lib.load_allowlist(root)
    allow = {n for n in files if repo_lib.allowed(f"tools/{entry_of[n]}", globs)}  # honours globs (`tools/*`), `!` denies and exact lines
    exact = {g[len("tools/"):] for g in globs if g.startswith("tools/") and not any(c in g for c in "*?[!")}
    rows: dict[str, tuple[str, str]] = {}
    bad: list[str] = [f"ENTRY   tools/{n}: top-level tools/*.py must be an entry tool (COMMANDS or MODULE table)" for n in stray]
    text = ""
    for cat in sorted((root / "design").glob(CATALOG_GLOB)):
        text += cat.read_text(encoding="utf-8")
        for ln in cat.read_text(encoding="utf-8").splitlines():
            m = ROW.match(ln)
            if not m:
                continue
            name, surf, a = m.groups()
            if name in rows:
                bad.append(f"DUP     {name} (also in another row)")
            rows[name] = (surf, a)
    for n in sorted(files - rows.keys()):
        bad.append(f"MISSING {n}: no catalog row")  # every subcommand of every entry tool
    for n in sorted(rows.keys() - files):
        bad.append(f"STALE   {n}: catalog row but no such command")
    for n in sorted(exact - {p.relative_to(tools).as_posix() for p in tools.rglob("*") if p.is_file()}):
        bad.append(f"ALLOW   {n}: on bot_allow.txt but no such file")
    for n in sorted(named):
        if f"`{n}" not in text and f"`tools/{n}" not in text:
            bad.append(f"UNNAMED tools/{n}: name it in backticks in the tools*.md that owns its area (libs: tools-libs.md)")
    for n, (surf, a) in sorted(rows.items()):
        if n in files and a == "Y" and n not in allow:
            bad.append(f"ALLOWED {n}: catalog A=Y but tools/{n} is not allowed by bot_allow.txt (add a line or mark A=N)")
        if a == "Y" and "B" not in surf and "D" not in surf:
            bad.append(f"SURF    {n}: allowlisted but no B/D surface")
    n_bad = len(bad)
    head = f"tool-docs: commands={len(files)} rows={len(rows)} libs_data={len(named)} allowlisted={len(allow)} problems={n_bad}"
    if bad:
        bad.append("next: MISSING = add a row to the design/tools*.md catalog (new tool: tools.md rule 5); UNNAMED = name the lib or data file in its area doc; ALLOWED/ALLOW = fix tools/bot_allow.txt or the A column; then rerun")
    echo = "\n".join(agent_log.fold(bad[:-1], args.verbose, keep=20, limit=28) + bad[-1:] + [head]) if bad else None
    return agent_log.finish("tool-docs", root, "\n".join(bad + [head]), "FAIL" if bad else "PASS", args=args, echo=echo,
                            legacy=False, commands=len(files), rows=len(rows), problems=n_bad)  # not the next: hint

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
