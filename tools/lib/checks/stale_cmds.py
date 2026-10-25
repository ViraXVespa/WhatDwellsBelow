#!/usr/bin/env python3
"""Tool-command references across the repo, for `check.py tool-docs --stale-refs` (the doc scan there sees backticked
paths in design/*.md only).

Scans tracked design/, root, .grok/, .github/, tools/ and scripts/ text (md, py, gd, json, yml, txt, cfg; not changelogs,
tools/retired or prove_rules.json, not selftest functions or *selftest*.py fixtures) for:
- FLAG: `ENTRY.py [SUB [SUB2]] --flag` with no add_argument("--flag") in SUB's module (only SUB2's parser and the shared
  ones when SUB has subparsers: tunable's add parser has --after, its diff parser does not) or in the helper
  modules it imports (not modules another subcommand owns: bot_smokes running `bot_warnscan --areas` lends no --areas);
- SUB: `python tools/ENTRY.py WORD` (or a backticked `ENTRY.py WORD`) naming a subcommand ENTRY does not have, or
  `ENTRY.py SUB WORD` where SUB's module has its own subparsers (`docs.py tunable WORD`) and none is WORD;
- TOOL: a `tools/...py` path that does not exist (one-letter or upper-case stems like X, ENTRY are placeholders; tools/_scratch.py is the untracked web scratch).
- BRANCH (branch_scan): a hand-rolled branch test (`startswith("bot/")`, `startswith("grok-build-w")`, `github.head_ref, 'bot/'`)
  outside repo_lib.branch_kind; or Build-only retry text (`grok -r ID --fork-session`, `git diff grok-build`...) in a module a shared,
  any-branch tool can reach (outside tools/lib/slice|release, or imported from outside them) with no repo_lib.head_kind gate.
- SCOPE (branch_scan): a tools .py walking only scripts/ for .gd (`(root / "scripts").rglob("*.gd")`, `sub="scripts"`, or
  `iter_gd(root)` with its scripts/ default):
  live .gd is gd_lib.live_gd / LIVE_GD_DIRS (scripts/ and tools/data/), no folder exempt.
Flags are read from add_argument calls (arg_flags), so argparse.SUPPRESS flags (`--bot`) count; a parser built in a loop or
from non-literal flags falls back to every "--x" literal in that module.
"""
from __future__ import annotations

import ast
import re
from pathlib import Path

import boot

SCAN_DIRS = ("design/", "tools/", "scripts/", ".grok/", ".github/")
SUFFIX = (".md", ".py", ".gd", ".json", ".yml", ".yaml", ".txt", ".cfg")
SKIP = ("design/changelog/", "tools/retired/", "scripts/data/changelog.json", "design/refs/",
        "tools/data/prove_rules.json")  # drift_allow names removed paths on purpose
FLAG_LIT = re.compile(r"""["'](--[a-z][\w-]*)["']""")
IMPORT = re.compile(r"^\s*(?:from\s+([\w.]+)\s+import|import\s+([\w., ]+))", re.M)
WORDS = {"and", "or", "to", "is", "the", "with", "as", "for", "in", "then", "runs", "also", "itself", "prints", "lists", "from",
         "on", "at", "by", "call", "calls", "when", "has", "does", "it", "its", "run", "lines", "help"}

class Scan:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.table = boot.entries(root / "tools")
        self.mods = {p.stem: p for p in (root / "tools/lib").rglob("*.py") if "__pycache__" not in p.parts}
        self.cache: dict = {}
        self.cli = {m.rsplit("/", 1)[-1] for rows in self.table.values() for _, m, _ in rows}
        ent = "|".join(sorted(self.table, key=len, reverse=True))
        self.ent_re = re.compile(r"(?<![\w/.-])(python3? +)?(tools/)?(" + ent + r")\.py\b([^`\n\"')|;]*)")
        self.cut = re.compile(r"(?<![\w/.-])(?:tools/)?(?:" + ent + r")\.py\b")

    def _mod_flags(self, stem: str, seen: set, sub2: str | None = None, depth: int = 0) -> set:
        """add_argument flags of STEM (only SUB2's parser plus the shared ones when STEM has subparsers) and of the
        helper modules it imports; a module another subcommand owns (bot_smokes importing bot_warnscan) lends none."""
        if stem in seen or stem not in self.mods or (depth and stem in self.cli):
            return set()
        seen.add(stem)
        src = self.mods[stem].read_text(encoding="utf-8", errors="replace")
        got = arg_flags(src)
        out = set(FLAG_LIT.findall(src)) if got is None else got[0] | set().union(*(
            [got[1].get(sub2, set())] if sub2 and sub2 in got[1] else got[1].values()))
        if depth < 3:
            for a, b in IMPORT.findall(src):
                for n in [a] if a else [x.strip().split(" ")[0] for x in b.split(",")]:
                    out |= self._mod_flags(n.split(".")[-1], seen, None, depth + 1)
        return out

    def flags(self, entry: str, sub: str | None, sub2: str | None = None) -> set:
        if (entry, sub, sub2) not in self.cache:
            src = (self.root / "tools" / f"{entry}.py").read_text(encoding="utf-8")
            got = arg_flags(src)
            out = (set(FLAG_LIT.findall(src)) if got is None else got[0].union(*got[1].values())) | {"--help", "-h"}
            for s, m, _ in self.table[entry]:
                if s == sub:
                    out |= self._mod_flags(m.rsplit("/", 1)[-1], set(), sub2)
            self.cache[(entry, sub, sub2)] = out
        return self.cache[(entry, sub, sub2)]

    def nested(self, entry: str, sub: str) -> set:
        """add_parser names in SUB's own module (empty: SUB takes no second word)."""
        key = ("nested", entry, sub)
        if key not in self.cache:
            mods = [m.rsplit("/", 1)[-1] for s, m, _ in self.table[entry] if s == sub]
            src = "".join(self.mods[m].read_text(encoding="utf-8", errors="replace") for m in mods if m in self.mods)
            names = set(re.findall(r"""add_parser\(\s*["']([a-z][\w-]*)["']""", src))
            self.cache[key] = set() if re.search(r"""add_parser\(\s*[^"'\s]""", src) else names  # names built in a loop: unknown
        return self.cache[key]

    def line(self, rel: str, no: int, line: str) -> list[str]:
        bad: list[str] = []
        for m in self.ent_re.finditer(line):
            entry, rest = m.group(3), self.cut.split(m.group(4))[0]
            toks, subs = rest.split(), {s for s, _, _ in self.table[entry] if s}
            sub = sub2 = None
            if subs:
                word = toks[0] if toks and re.fullmatch(r"[a-z][\w-]*", toks[0]) else ""
                if word in subs:
                    sub = word
                elif word and word not in WORDS and (m.group(1) or m.group(2) or line[max(0, m.start() - 1):m.start()] == "`"):
                    bad.append(f"SUB     {rel}:{no}: {entry}.py {word}")
                if sub is None:
                    continue
                inner, word2 = self.nested(entry, sub), toks[1] if len(toks) > 1 else ""
                sub2 = word2 if word2 in inner else None
                if inner and re.fullmatch(r"[a-z][\w-]*", word2) and word2 not in inner | WORDS \
                        and (m.group(1) or m.group(2) or line[max(0, m.start() - 1):m.start()] == "`"):
                    bad.append(f"SUB     {rel}:{no}: {entry}.py {sub} {word2}")
            inner = self.nested(entry, sub) if sub else set()
            for i, t in enumerate(toks):  # each flag goes with the last SUB2 before it (`code-map check or patch --add`)
                if t in inner and i:
                    sub2 = t
                for f in re.findall(r"(?<![\w-])(--[a-z][\w-]*)", t):
                    if f not in self.flags(entry, sub, sub2 if sub else None):
                        bad.append(f"FLAG    {rel}:{no}: " + " ".join(x for x in (f"{entry}.py", sub, sub2 if sub else None, f) if x))
        for m in re.finditer(r"(?<![\w/.-])(tools/[\w/]*?(\w+)\.py)\b", line):
            if len(m.group(2)) > 1 and not m.group(2).isupper() and m.group(2) != "_scratch" and not (self.root / m.group(1)).exists():
                bad.append(f"TOOL    {rel}:{no}: {m.group(1)}")
        return bad

def _recv(node) -> tuple[str | None, str | None]:
    """(base variable, add_parser("NAME") seen on the way) for the receiver of an .add_argument call."""
    name = None
    while isinstance(node, (ast.Attribute, ast.Call, ast.Subscript)):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "add_parser" \
                and node.args and isinstance(node.args[0], ast.Constant) and name is None:
            name = node.args[0].value
        if isinstance(node, ast.Subscript) and isinstance(node.value, ast.Attribute) and node.value.attr == "choices" \
                and isinstance(node.slice, ast.Constant) and name is None:
            name = node.slice.value  # sub.choices["patch"].add_argument
        node = node.func if isinstance(node, ast.Call) else node.value
    return (node.id if isinstance(node, ast.Name) else None), name

def arg_flags(src: str) -> tuple[set, dict[str, set]] | None:
    """(shared flags, {subparser name: its flags}) from the module's add_argument calls, in source order per top-level
    function: `s = sub.add_parser("add")` then `s.add_argument("--after")` puts --after under "add"; a parser built in a
    loop or a non-literal flag (`add_argument(*FLAGS)`) returns None (caller falls back to every "--x" literal)."""
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return None
    shared: set = set()
    named: dict[str, set] = {}
    defs = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
    for scope in [[t for t in tree.body if not isinstance(t, defs)]] + [[t] for t in tree.body if isinstance(t, defs)]:
        owner: dict[str, str | None] = {}
        nodes = sorted((n for top in scope for n in ast.walk(top) if isinstance(n, (ast.Assign, ast.Call))),
                       key=lambda n: (n.lineno, n.col_offset))
        for n in nodes:
            if isinstance(n, ast.Assign) and isinstance(n.value, ast.Call):
                base, name = _recv(n.value)
                f = n.value.func
                if isinstance(f, ast.Attribute) and f.attr == "add_parser" and not name:
                    return None  # add_parser(var): names unknown
                for t in n.targets:
                    if isinstance(t, ast.Name):
                        owner[t.id] = name or (owner.get(base) if base else None)
            elif isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "add_parser":
                if n.args and isinstance(n.args[0], ast.Constant):
                    named.setdefault(n.args[0].value, set())  # a subcommand with no flags of its own still has a set
            elif isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "add_argument":
                if any(not isinstance(a, ast.Constant) for a in n.args):
                    return None
                base, name = _recv(n.func.value)
                name = name or owner.get(base or "")
                fl = {a.value for a in n.args if isinstance(a.value, str) and a.value.startswith("-")}
                (named.setdefault(name, set()) if name else shared).update(fl)
    return shared, named

def _fixture_lines(rel: str, text: str) -> set[int]:
    """Lines inside selftest functions (fixtures name bad commands on purpose)."""
    if not rel.endswith(".py"):
        return set()
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()
    return {n for f in ast.walk(tree) if isinstance(f, (ast.FunctionDef, ast.AsyncFunctionDef)) and "selftest" in f.name
            for n in range(f.lineno, (f.end_lineno or f.lineno) + 1)}

def scan(root: Path, tracked: set[str]) -> list[str]:
    s = Scan(root)
    bad: list[str] = []
    for rel in sorted(tracked):
        if not rel.endswith(SUFFIX) or rel.startswith(SKIP) or "selftest" in rel.rsplit("/", 1)[-1] \
                or not (rel.startswith(SCAN_DIRS) or "/" not in rel):
            continue
        text = (root / rel).read_text(encoding="utf-8-sig", errors="replace")
        skip = _fixture_lines(rel, text)
        for no, line in enumerate(text.splitlines(), 1):
            if no not in skip and ".py" in line:
                bad += s.line(rel, no, line)
    return bad

BUILD_DIRS = ("tools/lib/slice/", "tools/lib/release/")  # Build/week flow modules: their text may assume a Build branch
SCOPE = re.compile(r"""\(\s*root\s*/\s*["']scripts["']\s*\)\.rglob\(\s*["']\*\.gd["']|iter_gd\([^)]*sub=["']scripts["']|iter_gd\(\s*\w+\s*\)""")
BUILD_TEXT = re.compile(r"grok -r \S+ --fork-session|`/fork`|git diff grok-build|RETRY: red prove")
ADHOC = re.compile(r"""startswith\(\s*["'](?:bot/|grok-build|grok-web)|head_ref,\s*'(?:bot/|grok-)""")
GATE = re.compile(r"\b(?:head_kind|branch_kind)\(")

def branch_scan(root: Path, tracked: set[str], texts: dict[str, str] | None = None) -> list[str]:
    """BRANCH rows (see the module doc). texts: rel -> source override (selftest)."""
    src = dict(texts or {})
    for rel in tracked:
        if rel not in src and rel.endswith((".py", ".yml")) and rel.startswith(("tools/", ".github/")) and not rel.startswith(SKIP) \
                and "selftest" not in rel.rsplit("/", 1)[-1]:
            src[rel] = (root / rel).read_text(encoding="utf-8-sig", errors="replace")
    bad: list[str] = []
    importers: dict[str, list[str]] = {}
    for rel, text in src.items():
        for m in IMPORT.finditer(text):
            for name in re.split(r"[,\s]+", (m.group(1) or m.group(2) or "").strip()):
                importers.setdefault(name.split(".")[-1], []).append(rel)
    for rel, text in sorted(src.items()):
        skip = _fixture_lines(rel, text)
        lines = [(n, ln) for n, ln in enumerate(text.splitlines(), 1) if n not in skip]
        if not rel.endswith(("repo_lib.py", "stale_cmds.py")):
            bad += [f"BRANCH  {rel}:{n}: hand-rolled branch test; use repo_lib.branch_kind/head_kind" for n, ln in lines if ADHOC.search(ln)]
        if not rel.endswith(("gd_lib.py", "stale_cmds.py")):
            bad += [f"SCOPE  {rel}:{n}: walks scripts/ only for .gd; use gd_lib.live_gd (scripts/ + tools/data/)" for n, ln in lines if SCOPE.search(ln)]
        hit = next((n for n, ln in lines if BUILD_TEXT.search(ln)), 0)
        if not hit or not rel.endswith(".py") or GATE.search(text):
            continue
        stem = rel.rsplit("/", 1)[-1][:-3]
        shared = [i for i in importers.get(stem, []) if not i.startswith(BUILD_DIRS)]
        if not rel.startswith(BUILD_DIRS) or shared:
            bad.append(f"BRANCH  {rel}:{hit}: Build-only text reachable off Build ({', '.join(sorted(shared)) or 'shared module'}); gate it on repo_lib.head_kind")
    return bad

def selftest(root: Path) -> list[str]:
    s, bad = Scan(root), []
    for line, want in (("`python tools/media.py clip crop IN --box R`", []), ("`media.py clip crop --region R`", ["FLAG"]),
                       ("python tools/shots.py capturez", ["SUB"]),
                       ("`docs.py tunable frobnicate`", ["SUB"]), ("`docs.py tunable range KEY 0 1`", []), ("`media.py sprites key IN OUT`", []), ("`shots.py` and the rest", []), ("`check.py script-cap --bot`", []),
                       ("`gate.py bot-smokes --areas p1`", ["FLAG"]), ("`gate.py warnscan --areas static`", []),
                       ("`docs.py tunable diff --after X`", ["FLAG"]), ("`docs.py tunable add K --after X`", []),
                       ("`docs.py code-map check` or `docs.py code-map patch --system S --add P`", []),
                       ("docs.py code-map check or patch --system S --add P", []), ("`docs.py code-map sweep --add P`", ["FLAG"]),
                       ("see tools/no_such_tool.py", ["TOOL"]), ("tools/lib/shots/run_movie.py --refs A", []), ("python tools/X.py", [])):
        got = [b.split()[0] for b in s.line("t.md", 1, line)]
        if got != want:
            bad.append(f"stale_cmds {line!r}: got {got}, want {want}")
    retry = 'def block(root):\n    return "RETRY: red prove ... grok -r X --fork-session"\n'
    cases = (({"tools/lib/slice/retry_lib.py": retry, "tools/lib/agent_log.py": "import retry_lib\n"}, 1),
             ({"tools/lib/slice/retry_lib.py": "import repo_lib\n" + retry.replace("    return", "    if repo_lib.head_kind(root) != 'build':\n        return ''\n    return"),
               "tools/lib/agent_log.py": "import retry_lib\n"}, 0),
             ({"tools/lib/slice/retry_lib.py": retry, "tools/lib/slice/slice_lib.py": "import retry_lib\n"}, 0),
             ({"tools/lib/bot_gate_lib.py": 'ok = ref.startswith("bot/")\n'}, 1),
             ({".github/workflows/g.yml": "if: startsWith(github.head_ref, 'bot/')\n"}, 1),
             ({"tools/lib/lint/u.py": 'found = sorted((root / "scripts").rglob("*.gd"))\n'}, 1),
             ({"tools/lib/lint/u.py": "found = gd_lib.iter_gd(root)\n"}, 1),
             ({"tools/lib/lint/u.py": 'found = gd_lib.iter_gd(root, sub="tests")\n'}, 0),
             ({"tools/lib/lint/u.py": "found = gd_lib.live_gd(root)\n"}, 0))
    for texts, want in cases:
        got = branch_scan(root, set(), texts)
        if len(got) != want:
            bad.append(f"branch_scan {sorted(texts)}: got {got}, want {want} row(s)")
    loop = 'for n in ("a", "b"):\n    s = sub.add_parser(n)\n    s.add_argument("--x")\n'
    two = 's = sub.add_parser("a")\ns.add_argument("--x")\ns = sub.add_parser("b")\nap.add_argument("--root")\n'
    if arg_flags(loop) is not None or arg_flags(two) != ({"--root"}, {"a": {"--x"}, "b": set()}):
        bad.append(f"stale_cmds arg_flags: loop {arg_flags(loop)}, two {arg_flags(two)}")
    if not _fixture_lines("t.py", "def selftest():\n    x = 1\n") == {1, 2}:
        bad.append("stale_cmds: selftest bodies must be skipped")
    return bad
