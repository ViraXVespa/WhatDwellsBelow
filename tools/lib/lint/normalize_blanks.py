#!/usr/bin/env python3
"""Collapse consecutive blank lines to one across text files. Keeps each file's BOM and line endings.

    python tools/lint.py blanks [PATH ...] [--ext md,py,gd] [--dry-run]

PATH is a file or directory (repeatable). A directory walks files whose suffix is in --ext
(default md,py,gd). Skips _logs, .git, archives and changelogs (history). Blank runs inside a py/gd triple-quoted
string or a markdown ``` fence are content and kept. Writes through md_format_lib so BOM and EOL are kept.
"""
from __future__ import annotations

import re

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import md_format_lib

SKIP = {".git", "_logs", "archives", ".archive_worktrees", "__pycache__"}
SKIP_REL = ("design/changelog/", "scripts/data/changelog.json")
TRIPLE = re.compile(r'"""|\'\'\'')

def collapse(text: str, suffix: str) -> str:
    """md_format_lib.collapse_blanks outside protected regions: py/gd triple-quoted strings, md ``` fences."""
    lines = md_format_lib.force_lf(text).split("\n")
    out: list[str] = []
    blank, inside = 0, ""
    for line in lines:
        if inside:
            out.append(line)
            if (inside == "```" and line.lstrip().startswith("```")) or (inside != "```" and line.count(inside) % 2 == 1):
                inside = ""
            continue
        if line.strip() == "":
            blank += 1
            if blank == 1 and out:
                out.append("")
            continue
        blank = 0
        out.append(line)
        if suffix == ".md" and line.lstrip().startswith("```"):
            inside = "```"
        elif suffix in (".py", ".gd"):
            q = TRIPLE.findall(line)
            if len(q) % 2 == 1:
                inside = q[-1]
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + ("\n" if out else "")

def _selftest() -> int:
    cases = ((".py", 'X = """a\n\n\nb"""\n\n\n\ny = 1\n', 'X = """a\n\n\nb"""\n\ny = 1\n'),
             (".gd", 'const S := """\nx\n\n\ny\n"""\n\n\nvar z := 1\n', 'const S := """\nx\n\n\ny\n"""\n\nvar z := 1\n'),
             (".md", "# T\n\n\n```\na\n\n\nb\n```\n", "# T\n\n```\na\n\n\nb\n```\n"),
             (".md", "a\n\n\n\nb\n", "a\n\nb\n"))
    bad = [f"{suf} {src!r}: got {collapse(src, suf)!r}" for suf, src, want in cases if collapse(src, suf) != want]
    if not any(r.startswith("design/changelog/") for r in SKIP_REL):
        bad.append("changelogs are not skipped")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))

def iter_files(root: Path, paths: list[str], exts: set[str]) -> list[Path]:
    hits: list[Path] = []
    raw = paths or ["."]
    for item in raw:
        target = Path(item)
        if not target.is_absolute():
            target = (root / target).resolve()
        if target.is_file():
            if target.suffix.lstrip(".").lower() in exts:
                hits.append(target)
            continue
        if target.is_dir():
            for p in sorted(target.rglob("*")):
                if not p.is_file():
                    continue
                if any(part in SKIP for part in p.parts) or p.relative_to(root).as_posix().startswith(SKIP_REL):
                    continue
                if p.suffix.lstrip(".").lower() in exts:
                    hits.append(p)
    return hits

def main(argv: list[str] | None = None) -> int:
    parser = agent_log.std_parser(
        "Collapse consecutive blank lines to one. Keeps BOM and line endings.",
        writes=True,
    )
    parser.add_argument("paths", nargs="*", help="File or directory (default: current repo)")
    parser.add_argument("--ext", default="md,py,gd", help="Comma-separated suffixes to include (default md,py,gd)")
    parser.add_argument("--selftest", action="store_true", help="Blank runs inside strings / fences are kept; changelogs skipped.")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    if args.selftest:
        return _selftest()
    root = agent_log.resolve_root(args)
    exts = {e.strip().lstrip(".").lower() for e in args.ext.split(",") if e.strip()}
    files = iter_files(root, args.paths, exts)
    changed = 0
    lines = ["normalize-blanks", f"scanned={len(files)}"]
    for path in files:
        try:
            text, eol, bom = md_format_lib.read_text(path, with_meta=True)
        except OSError:
            continue
        cleaned = collapse(text, path.suffix.lower())
        if cleaned == text:
            continue
        changed += 1
        lines.append(path.relative_to(root).as_posix())
        if not args.dry_run:
            md_format_lib.write_text(path, cleaned, eol=eol, bom=bom)
    lines.append(f"changed={changed}")
    return agent_log.finish(
        "normalize-blanks",
        root,
        "\n".join(lines),
        "PASS",
        args=args,
        changed=changed,
        scanned=len(files),
    )

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
