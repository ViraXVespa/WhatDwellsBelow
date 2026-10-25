#!/usr/bin/env python3
"""Tool-command references across the repo, for `check.py tool-docs --stale-refs` (the doc scan there sees backticked
paths in design/*.md only).

Scans tracked design/, root, .grok/, .github/, tools/ and scripts/ text (md, py, gd, json, yml, txt, cfg; not changelogs,
tools/retired or prove_rules.json, not selftest functions or *selftest*.py fixtures) for:
- FLAG: `ENTRY.py [SUB] --flag` where the subcommand's module (and the tools/lib modules it imports) defines no "--flag";
- SUB: `python tools/ENTRY.py WORD` (or a backticked `ENTRY.py WORD`) naming a subcommand ENTRY does not have, or
  `ENTRY.py SUB WORD` where SUB's module has its own subparsers (`docs.py tunable WORD`) and none is WORD;
- TOOL: a `tools/...py` path that does not exist (one-letter or upper-case stems like X, ENTRY are placeholders; tools/_scratch.py is the untracked web scratch).
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

def selftest(root: Path) -> list[str]:
    s, bad = Scan(root), []
    for line, want in (("`python tools/media.py clip crop IN --box R`", []), ("`media.py clip crop --region R`", ["FLAG"]),
                       ("python tools/shots.py capturez", ["SUB"]),
                       ("`docs.py tunable frobnicate`", ["SUB"]), ("`docs.py tunable range KEY 0 1`", []), ("`media.py sprites key IN OUT`", []), ("`shots.py` and the rest", []), ("`check.py script-cap --bot`", []),
                       ("see tools/no_such_tool.py", ["TOOL"]), ("tools/lib/shots/run_movie.py --refs A", []), ("python tools/X.py", [])):
        got = [b.split()[0] for b in s.line("t.md", 1, line)]
        if got != want:
            bad.append(f"stale_cmds {line!r}: got {got}, want {want}")
    if not _fixture_lines("t.py", "def selftest():\n    x = 1\n") == {1, 2}:
        bad.append("stale_cmds: selftest bodies must be skipped")
    return bad
