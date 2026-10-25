#!/usr/bin/env python3
"""Tool-command references across the repo, for `check.py tool-docs --stale-refs` (the doc scan there sees backticked
paths in design/*.md only).

Scans tracked design/, root, .grok/, .github/, tools/ and scripts/ text (md, py, gd, json, yml, txt, cfg; not changelogs,
tools/retired or prove_rules.json, not selftest functions or *selftest*.py fixtures) for:
- FLAG: `ENTRY.py [SUB] --flag` where the subcommand's module (and the tools/lib modules it imports) defines no "--flag";
- SUB: `python tools/ENTRY.py WORD` (or a backticked `ENTRY.py WORD`) naming a subcommand ENTRY does not have, or
  `ENTRY.py SUB WORD` where SUB's module has its own subparsers (`docs.py tunable WORD`) and none is WORD;
- TOOL: a `tools/...py` path that does not exist (one-letter or upper-case stems like X, ENTRY are placeholders; tools/_scratch.py is the untracked web scratch).
- BRANCH (branch_scan): a hand-rolled branch test (`startswith("bot/")`, `startswith("grok-build-w")`, `github.head_ref, 'bot/'`)
  outside repo_lib.branch_kind; or Build-only retry text (`grok -r ID --fork-session`, `git diff grok-build`...) in a module a shared,
  any-branch tool can reach (outside tools/lib/slice|release, or imported from outside them) with no repo_lib.head_kind gate.
- SCOPE (branch_scan): a tools .py walking only scripts/ for .gd (`(root / "scripts").rglob("*.gd")`, `sub="scripts"`):
  live .gd is gd_lib.live_gd / LIVE_GD_DIRS (scripts/ and tools/data/), no folder exempt.
Flags are read from string literals, so argparse.SUPPRESS flags (`--bot`) count.
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
        ent = "|".join(sorted(self.table, key=len, reverse=True))
        self.ent_re = re.compile(r"(?<![\w/.-])(python3? +)?(tools/)?(" + ent + r")\.py\b([^`\n\"')|;]*)")
        self.cut = re.compile(r"(?<![\w/.-])(?:tools/)?(?:" + ent + r")\.py\b")

    def _mod_flags(self, stem: str, seen: set, depth: int = 0) -> set:
        if stem in seen or stem not in self.mods:
            return set()
        seen.add(stem)
        src = self.mods[stem].read_text(encoding="utf-8", errors="replace")
        out = set(FLAG_LIT.findall(src))
        if depth < 3:
            for a, b in IMPORT.findall(src):
                for n in [a] if a else [x.strip().split(" ")[0] for x in b.split(",")]:
                    out |= self._mod_flags(n.split(".")[-1], seen, depth + 1)
        return out

    def flags(self, entry: str, sub: str | None) -> set:
        if (entry, sub) not in self.cache:
            out = set(FLAG_LIT.findall((self.root / "tools" / f"{entry}.py").read_text(encoding="utf-8"))) | {"--help"}
            for s, m, _ in self.table[entry]:
                if s == sub:
                    out |= self._mod_flags(m.rsplit("/", 1)[-1], set())
            self.cache[(entry, sub)] = out
        return self.cache[(entry, sub)]

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
            sub = None
            if subs:
                word = toks[0] if toks and re.fullmatch(r"[a-z][\w-]*", toks[0]) else ""
                if word in subs:
                    sub = word
                elif word and word not in WORDS and (m.group(1) or m.group(2) or line[max(0, m.start() - 1):m.start()] == "`"):
                    bad.append(f"SUB     {rel}:{no}: {entry}.py {word}")
                if sub is None:
                    continue
                inner, word2 = self.nested(entry, sub), toks[1] if len(toks) > 1 else ""
                if inner and re.fullmatch(r"[a-z][\w-]*", word2) and word2 not in inner | WORDS \
                        and (m.group(1) or m.group(2) or line[max(0, m.start() - 1):m.start()] == "`"):
                    bad.append(f"SUB     {rel}:{no}: {entry}.py {sub} {word2}")
            have = self.flags(entry, sub)
            bad += [f"FLAG    {rel}:{no}: {entry}.py {sub or ''} {f}".replace("  ", " ") for t in toks
                    for f in re.findall(r"(?<![\w-])(--[a-z][\w-]*)", t) if f not in have]
        for m in re.finditer(r"(?<![\w/.-])(tools/[\w/]*?(\w+)\.py)\b", line):
            if len(m.group(2)) > 1 and not m.group(2).isupper() and m.group(2) != "_scratch" and not (self.root / m.group(1)).exists():
                bad.append(f"TOOL    {rel}:{no}: {m.group(1)}")
        return bad

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
SCOPE = re.compile(r"""\(\s*root\s*/\s*["']scripts["']\s*\)\.rglob\(\s*["']\*\.gd["']|iter_gd\([^)]*sub=["']scripts["']""")
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
             ({"tools/lib/lint/u.py": "found = gd_lib.live_gd(root)\n"}, 0))
    for texts, want in cases:
        got = branch_scan(root, set(), texts)
        if len(got) != want:
            bad.append(f"branch_scan {sorted(texts)}: got {got}, want {want} row(s)")
    if not _fixture_lines("t.py", "def selftest():\n    x = 1\n") == {1, 2}:
        bad.append("stale_cmds: selftest bodies must be skipped")
    return bad
