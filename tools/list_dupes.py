#!/usr/bin/env python3
"""Find reused/duplicated code: whole functions (exact, or same shape with renamed params/locals) and line-block clones.

    python tools/list_dupes.py [--lang gd|py|all] [--min-lines 4] [--min-block 8] [--top 40] [--md PATH] [--json]

gd = scripts/**/*.gd, py = tools/*.py (archives, .archive_worktrees, _logs skipped). Kinds, ranked by score
(copies-1)*lines:
  exact   function bodies identical after comments/blank lines are dropped (name ignored)
  shape   same control flow once params and locals are renamed (the shared-extract candidates in design/refactor.md)
  near    same shape once string and number literals are masked too (a shared helper takes the literals as args)
  block   >= --min-block consecutive code lines repeated verbatim in 2+ places (not inside an already reported function)
  nblock  the same, with string/number literals masked (copies differ only in constants)
Read-only. Summary: _logs/dupes/<stamp>-dupes.txt; --md writes the ranked list (location, lines, copies) for design/reuse-map.md.
Result: RESULT INFO exact= shape= near= block= nblock= (always INFO; this is a finder, not a gate).
"""
from __future__ import annotations

import ast
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import gd_lib

KINDS = ("exact", "shape", "near", "block", "nblock")
SKIP = {*gd_lib.SKIP_PARTS, "_logs", "docs", ".git", "assets", "__pycache__"}
IDENT = re.compile(r"\b[A-Za-z_]\w*\b")
LOCAL = re.compile(r"^\s*(?:var|for)\s+(\w+)")
TRIVIAL = re.compile(r"^(pass|return|return null|return false|return true|else:|\)|\]|\})$")
HEADER = re.compile(r"^(const |@|extends |class_name |import |from |static var |var \w+(:\s*\w+)?\s*(:=|=)\s*preload)")


def strip_comment(line: str) -> str:
    q = ""
    for i, ch in enumerate(line):
        if q:
            if ch == q and line[i - 1] != "\\":
                q = ""
        elif ch in "\"'":
            q = ch
        elif ch == "#":
            return line[:i].rstrip()
    return line.rstrip()


STR = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?\b")


def mask(s: str) -> str:
    return NUM.sub("N", STR.sub('"S"', s))


def code_lines(text: str) -> list[tuple[int, str]]:
    """[(1-based line, line with trailing comment/space removed)] for non-blank, non-comment lines."""
    out = []
    for n, raw in enumerate(text.splitlines(), 1):
        s = strip_comment(raw.replace("\r", ""))
        if s.strip():
            out.append((n, s))
    return out


def gd_funcs(text: str) -> list[dict]:
    lines = text.splitlines()
    res = []
    for name, start in gd_lib.func_starts(text):
        end = start
        for j in range(start, len(lines)):
            raw = lines[j]
            if raw.strip() and not raw.startswith(("\t", " ", "#", ")")):
                break
            if raw.strip():
                end = j + 1
        body = [(start + n - 1, s) for n, s in code_lines("\n".join(lines[start - 1:end]))]
        res.append({"name": name, "start": start, "end": end, "lines": body})
    return res


def gd_shape(fn: dict) -> str:
    sig = fn["lines"][0][1]
    params = re.findall(r"\b(\w+)\s*(?::[^,)=]*)?(?:=[^,)]*)?[,)]", sig[sig.index("(") + 1:]) if "(" in sig else []
    names = {p: "p%d" % i for i, p in enumerate(dict.fromkeys(params))}
    for _, s in fn["lines"][1:]:
        m = LOCAL.match(s)
        if m and m.group(1) not in names:
            names[m.group(1)] = "l%d" % len(names)
    out = []
    for i, (_, s) in enumerate(fn["lines"]):
        if i == 0:
            s = re.sub(r"func\s+\w+", "func F", s)
        out.append(IDENT.sub(lambda m: names.get(m.group(0), m.group(0)), s))
    return "\n".join(out)


def gd_exact(fn: dict) -> str:
    return "\n".join(s for _, s in fn["lines"][1:])


class Norm(ast.NodeTransformer):
    def __init__(self) -> None:
        self.m: dict[str, str] = {}

    def _n(self, name: str) -> str:
        return self.m.setdefault(name, "v%d" % len(self.m))

    def visit_arg(self, node):
        node.arg = self._n(node.arg)
        node.annotation = None
        return node

    def visit_Name(self, node):
        if isinstance(node.ctx, ast.Store) or node.id in self.m:
            node.id = self._n(node.id)
        return node


def py_funcs(text: str) -> list[dict]:
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return []
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        seg = ast.get_source_segment(text, node) or ""
        lines = [(node.lineno + n - 1, s) for n, s in code_lines(seg)]
        n2 = Norm()
        body = ast.parse(ast.unparse(node)).body[0]
        body.name = "F"
        dump = ast.dump(n2.visit(body))
        out.append({"name": node.name, "start": node.lineno, "end": node.end_lineno, "lines": lines,
                    "exact": "\n".join(s for _, s in lines[1:]), "shape": dump})
    return out


def collect(root: Path, lang: str) -> dict[str, list[Path]]:
    files: dict[str, list[Path]] = {"gd": [], "py": []}
    for kind, sub, pat in (("gd", "scripts", "*.gd"), ("py", "tools", "*.py")):
        if lang in (kind, "all"):
            files[kind] = sorted(p for p in (root / sub).rglob(pat) if not SKIP & set(p.relative_to(root).parts))
    return files


def build(root: Path, lang: str, min_lines: int, min_block: int):
    funcs: list[dict] = []
    wins: dict[str, list[tuple[str, int]]] = defaultdict(list)
    seqs: dict[str, list[tuple[int, str]]] = {}
    for kind, paths in collect(root, lang).items():
        for p in paths:
            text = p.read_text(encoding="utf-8-sig", errors="replace")
            rel = agent_log.rel(root, p)
            for fn in (gd_funcs(text) if kind == "gd" else py_funcs(text)):
                fn["file"] = rel
                if kind == "gd":
                    fn["exact"], fn["shape"] = gd_exact(fn), gd_shape(fn)
                fn["near"] = mask(fn["shape"]) if kind == "gd" else re.sub(r"Constant\(value=[^)]*\)", "C", fn["shape"])
                if len(fn["lines"]) - 1 >= min_lines:
                    funcs.append(fn)
            seq = [(n, s.strip()) for n, s in code_lines(text)]
            seqs[rel] = seq
            for i in range(len(seq) - min_block + 1):
                w = [mask(s) for _, s in seq[i:i + min_block]]
                if len(set(w)) < 4 or all(HEADER.match(s) or TRIVIAL.match(s) for s in w):
                    continue
                wins[hashlib.md5("\n".join(w).encode()).hexdigest()].append((rel, i))
    return funcs, wins, seqs


def func_groups(funcs: list[dict]) -> list[dict]:
    out, seen = [], set()
    for kind in ("exact", "shape", "near"):
        g: dict[str, list[dict]] = defaultdict(list)
        for f in funcs:
            g[f[kind]].append(f)
        for fs in g.values():
            keys = frozenset((f["file"], f["start"]) for f in fs)
            if len(fs) < 2 or keys in seen:
                continue
            seen.add(keys)
            n = len(fs[0]["lines"])
            out.append({"kind": kind, "lines": n, "copies": len(fs), "score": (len(fs) - 1) * n,
                        "where": ["%s:%d-%d %s" % (f["file"], f["start"], f["end"], f["name"]) for f in fs]})
    return out


def _hash(seq, i, k):
    return hashlib.md5("\n".join(mask(s) for _, s in seq[i:i + k]).encode()).hexdigest()


def block_groups(wins, seqs, min_block: int) -> list[dict]:
    out, done = [], set()
    for occ in wins.values():
        if len(occ) < 2:
            continue
        back = [(r, i - 1) for r, i in occ]
        if all(i > 0 for _, i in occ) and wins.get(_hash(seqs[back[0][0]], back[0][1], min_block)) == back:
            continue
        cur, ext = occ, 0
        while all(i + 1 + min_block <= len(seqs[r]) for r, i in cur):
            nxt = [(r, i + 1) for r, i in cur]
            if wins.get(_hash(seqs[nxt[0][0]], nxt[0][1], min_block)) != nxt:
                break
            cur, ext = nxt, ext + 1
        n = min_block + ext
        spans = [(r, seqs[r][i][0], seqs[r][i + n - 1][0]) for r, i in occ]
        if _overlap(spans) or frozenset(spans) in done:
            continue
        done.add(frozenset(spans))
        raw = {tuple(s for _, s in seqs[r][i:i + n]) for r, i in occ}
        out.append({"kind": "block" if len(raw) == 1 else "nblock", "lines": n, "copies": len(occ),
                    "score": (len(occ) - 1) * n, "where": ["%s:%d-%d" % s for s in spans]})
    return out


def _overlap(spans) -> bool:
    by: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for r, a, b in spans:
        by[r].append((a, b))
    return any(x[1] >= y[0] for v in by.values() for x, y in zip(sorted(v), sorted(v)[1:]))


def drop_inside_funcs(blocks: list[dict], fgroups: list[dict]) -> list[dict]:
    """Drop a block clone whose every copy sits inside a function already reported as an exact/shape/near group."""
    ranges: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for g in fgroups:
        for w in g["where"]:
            f, rest = w.rsplit(":", 1)
            a, b = rest.split(" ")[0].split("-")
            ranges[f].append((int(a), int(b)))
    keep = []
    for b in blocks:
        inside = 0
        for w in b["where"]:
            f, rest = w.rsplit(":", 1)
            a, z = map(int, rest.split("-"))
            inside += any(x <= a and z <= y for x, y in ranges.get(f, []))
        if inside < len(b["where"]):
            keep.append(b)
    return keep


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Find duplicated functions and code blocks (exact, same-shape, block clones).", json_out=True)
    ap.add_argument("--lang", choices=("gd", "py", "all"), default="all", help="Which sources to scan: gd, py or all (default all).")
    ap.add_argument("--min-lines", type=int, default=4, help="min function body lines for exact/shape groups")
    ap.add_argument("--min-block", type=int, default=8, help="min consecutive repeated code lines for block clones")
    ap.add_argument("--top", type=int, default=40, help="rows shown per kind in the console summary")
    ap.add_argument("--md", default="", help="also write the ranked list as markdown to this path")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    funcs, wins, seqs = build(root, args.lang, args.min_lines, args.min_block)
    fg = func_groups(funcs)
    bg = drop_inside_funcs(block_groups(wins, seqs, args.min_block), fg)
    rows = sorted(fg + bg, key=lambda r: -r["score"])
    cnt = {k: sum(1 for r in rows if r["kind"] == k) for k in KINDS}
    lines = ["dupes lang=%s min_lines=%d min_block=%d" % (args.lang, args.min_lines, args.min_block)]
    for k in KINDS:
        for r in [r for r in rows if r["kind"] == k][:args.top]:
            lines.append("%-5s score=%-4d lines=%-3d copies=%d  %s" % (k, r["score"], r["lines"], r["copies"], " | ".join(r["where"])))
    if args.md:
        md = ["| Kind | Score | Lines | Copies | Where |", "|---|---|---|---|---|"]
        md += ["| %s | %d | %d | %d | %s |" % (r["kind"], r["score"], r["lines"], r["copies"], "<br>".join("`%s`" % w for w in r["where"])) for r in rows]
        Path(args.md).write_text("\n".join(md) + "\n", encoding="utf-8")
    d = agent_log.ensure_agent_log_dir("dupes", root)
    agent_log.run_path("dupes", root, "rows.json").write_text(json.dumps(rows, indent=1), encoding="utf-8")
    res = agent_log.write_run_file(root, d, "dupes", "\n".join(lines), "INFO", **cnt)
    if args.json:
        agent_log.print_json({"status": "INFO", "counts": cnt, "rows": rows})
    else:
        print("\n".join(lines + [res]))
    return 0


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
