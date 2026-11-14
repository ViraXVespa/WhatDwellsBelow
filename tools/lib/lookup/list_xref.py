#!/usr/bin/env python3
"""Text search; writes a short hit list instead of dumping ripgrep into chat.

    python tools/find.py xref --pattern pc-offload [--path design --path tools | --path design tools] [--include "*.gd"] [--regex]
--path accumulates: repeat it, list several after one flag, or comma-separate; a path that does not exist is named in a WARN.
Scans the project that holds the current directory (so a worktree is scanned from inside it), else this tool's own checkout;
--root overrides. The first output line prints the absolute scanned root, with a WARN when it is not the current directory's project.
Case-insensitive. Skips top-level archives/, .archive_worktrees/, _logs/, docs/ and the Bot's own docs (BOT.md, design/grok-bot-*.md). Summary: _logs/xref/<stamp>-xref.txt. --selftest runs the cases in a temp repo.
Default output is an INDEX when a search hits many places: per-file hit counts with each file's first matching line, most hits first. Then
`--expand FILE` (repeatable) lists every hit in that file. A search with only a few hits prints them directly.
--texts searches the visible text of the last shot-flow runs instead (_logs/shot-flow/**/*.texts.json): the way to find which words a screen shows.

"""
from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import gd_lib

SKIP = {*gd_lib.SKIP_PARTS, "_logs", "docs", ".git"}
DEFAULT_PATHS = ["scripts", "scenes", "tools", "design", "project.godot", "export_presets.cfg"]  # settings hold platform causes

def BOT_DOCS(rel: str) -> bool:
    """The Bot's own docs are not Build's search scope."""
    return rel == "BOT.md" or (rel.startswith("design/grok-bot-") and rel.endswith(".md"))

def main(argv: list[str] | None = None) -> int:
    if argv is None and "--selftest" in sys.argv[1:] or argv and "--selftest" in argv:
        return selftest()
    ap = agent_log.std_parser("Text search over scripts/scenes/tools/design.", json_out=True)
    ap.add_argument("pattern_pos", nargs="?", default="", help="Pattern (same as --pattern).")
    ap.add_argument("--pattern", default="", help="Text to find (or pass it as the argument).")
    ap.add_argument("--path", nargs="+", action="extend", default=None, help="Files or dirs to search; repeat the flag or list several (default scripts scenes tools design project.godot export_presets.cfg).")
    ap.add_argument("--include", default="*", help="Filename glob, e.g. *.gd")
    ap.add_argument("--max-hits", type=int, default=30, help=argparse.SUPPRESS)
    ap.add_argument("--max-files", type=int, default=20, help=argparse.SUPPRESS)
    ap.add_argument("--regex", action="store_true", help="Treat the pattern as a regular expression.")
    ap.add_argument("--expand", action="append", default=[], metavar="FILE", help="List every hit in this file (repo-relative path or a unique end of it); repeat for more files.")
    ap.add_argument("--all", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--selftest", action="store_true", help="Run the cases in a temp repo.")
    ap.add_argument("--texts", action="store_true", help="Search the shot-flow text dumps (_logs/shot-flow/**/*.texts.json) instead of the source folders.")
    args = ap.parse_args(argv)
    if args.texts:
        args.path = ["_logs/shot-flow"]
        args.include = "*.texts.json" if args.include == "*" else args.include
    cwd_root = None
    if not args.root:
        try:
            cwd_root = agent_log.repo_root(Path.cwd())
        except FileNotFoundError:
            pass
    root = agent_log.resolve_root(args.root or cwd_root)
    pattern = args.pattern or args.pattern_pos
    if not pattern:
        agent_log.fail("pass --pattern TEXT")
    rx = re.compile(pattern if args.regex else re.escape(pattern), re.IGNORECASE)
    paths = list(dict.fromkeys(agent_log.split_list(args.path or [d for d in DEFAULT_PATHS if (root / d).exists()])))
    missing = [p for p in paths if not (Path(p) if Path(p).is_absolute() else root / p).exists()]
    if not args.all:  # the index and --expand need whole counts; --max-hits / --max-files shape only the flat --all list
        args.max_hits, args.max_files = max(args.max_hits, 3000), max(args.max_files, 600)
    hits: list[str] = []
    files_hit: set[str] = set()
    scanned, trunc = 0, False
    for raw in paths:
        base = Path(raw)
        base = base if base.is_absolute() else root / base
        if not base.exists():
            continue
        cands = [base] if base.is_file() else sorted(base.rglob("*"))
        for f in cands:
            if not f.is_file() or (SKIP & set(f.relative_to(root).parts[:1]) and not args.texts) or not fnmatch.fnmatch(f.name, args.include):
                continue
            if BOT_DOCS(f.relative_to(root).as_posix()):
                continue
            scanned += 1
            if len(files_hit) >= args.max_files or len(hits) >= args.max_hits:
                trunc = True
                break
            try:
                data = f.read_bytes()
            except OSError:
                continue
            if b"\0" in data[:2048]:
                continue
            rel = agent_log.rel(root, f)
            for n, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
                if rx.search(line):
                    files_hit.add(rel)
                    if len(hits) >= args.max_hits:
                        trunc = True
                        break
                    text = line.strip()
                    hits.append(f"{rel}:{n}:{text[:160] + '...' if len(text) > 160 else text}")
        if trunc:
            break
    by_file: dict[str, list[str]] = {}
    for h in hits:
        by_file.setdefault(h.split(":", 1)[0], []).append(h)
    expand = [f for f in args.expand if f]
    index = not args.all and not expand and len(hits) > 6 and len(by_file) > 1
    if expand:
        picked = {rel for rel in by_file if any(rel == e or rel.endswith("/" + e.lstrip("/")) for e in expand)}
        hits = [h for rel in sorted(picked) for h in by_file[rel]]
        if not hits:
            agent_log.fail("no hits in %s for %r; files with hits: %s" % (", ".join(expand), pattern, ", ".join(sorted(by_file)) or "none"))
    mode = "regex" if args.regex else "simple"
    where = f"WARN: no such path: {', '.join(missing)}" if missing else ""
    body = [f"{where} pattern={pattern} mode={mode} include={args.include} path={','.join(paths)}",
            f"scanned={scanned} files={len(files_hit)} hits={len(hits)} truncated={trunc}",
            ""] + hits
    echo = f"{where}\nxref files={len(files_hit)} hits={len(hits)} scanned={scanned}"
    if index:
        ranked = sorted(by_file.items(), key=lambda kv: (-len(kv[1]), kv[0]))
        echo += "".join(f"\n{len(v):>3}  {k}  first: {v[0].split(':', 2)[1]}: {v[0].split(':', 2)[2][:90]}" for k, v in ranked[:14])
        if len(ranked) > 14:
            echo += f"\n... and {len(ranked) - 14} more files: narrow with --path"
        echo += "\nnext: `--expand FILE` lists one file's hits"
    else:
        echo += "".join("\n" + h for h in hits[:args.max_hits])
    if trunc:
        echo += "\nnext: more hits exist; narrow with --path/--include"
    elif not hits and args.texts:
        echo += "\nnext: no match in the shot-flow text dumps" + ("" if (root / "_logs" / "shot-flow").is_dir() else " (none yet: run `python tools/shots.py flow --flow NAME` first)")
    elif not hits:
        echo += "\nnext: no match; try a shorter pattern or --regex (search is case-insensitive over scripts scenes tools design and the project/export settings)"
    return agent_log.finish("xref", root, "\n".join(body), "INFO", args=args, echo=echo, files=len(files_hit),
                            hits=len(hits), scanned=scanned, truncated=trunc)

def selftest() -> int:
    import subprocess
    import tempfile

    import repo_lib

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td)
        for rel in ("scripts/a.gd", "scripts/b.gd", "design/c.md"):
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text("var needle = 1\n", encoding="utf-8")

        def run(*a: str) -> str:
            p = subprocess.run([*boot.cmd("list_xref"), "--root", str(root), "needle", *a], capture_output=True, text=True)
            return p.stdout + p.stderr
        for form in (["--path", "scripts/a.gd", "--path", "scripts/b.gd"], ["--path", "scripts/a.gd", "scripts/b.gd"],
                     ["--path", "scripts/a.gd,scripts/b.gd"]):
            out = run(*form)
            if "scripts/a.gd:1" not in out or "scripts/b.gd:1" not in out or "design/c.md" in out:
                bad.append(f"--path accumulates ({' '.join(form)}): {out[-200:]}")
        (root / "export_presets.cfg").write_text("html/needle=true\n", encoding="utf-8")
        out = run()
        if "design/c.md:1" not in out or "export_presets.cfg:1" not in out or "WARN" in out:
            bad.append("no --path searches the default folders and the export settings, with no WARN for an absent default")
        if "WARN: no such path: nope.gd" not in run("--path", "nope.gd", "--path", "scripts/a.gd"):
            bad.append("a missing --path is named in a WARN")
    return agent_log.selftest_result(bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
