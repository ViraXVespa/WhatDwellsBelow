#!/usr/bin/env python3
"""Script name check: FAIL (exit 1) when two live scripts/**/*.gd share a basename (dupes=).

    check_script_cap.py [--git-changed | --path P]    basenames must stay unique repo-wide
    check_script_cap.py --selftest                    the checks below in a throwaway repo
A `--path` that is not on disk (a script the change deleted: CI passes every changed path) is skipped with a note,
never an error. A `--path` that exists but is not a file still exits 2.
The Bot and CI run more checks (BOT.md); outside them only the name check runs.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import sys
import tempfile
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import bot_gate_lib
import gd_lib
import repo_lib

DEFAULT_OVER_KB = bot_gate_lib.SHIP_BYTES // 1000
SWEEP_OVER_KB = bot_gate_lib.SWEEP_BYTES / 1000


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = agent_log.std_parser("Check live scripts/**/*.gd: basenames unique repo-wide.", json_out=True)
    bot_gate_lib.add_flag(parser)
    sup = argparse.SUPPRESS  # Bot-only size options: BOT.md
    parser.add_argument("--over-kb", dest="over_kb", type=float, default=None, help=sup)
    parser.add_argument("--list", action="store_true", help=sup)
    parser.add_argument("--under-kb", type=float, default=0, help=sup)
    parser.add_argument("--sweep", action="store_true", help=sup)
    parser.add_argument(
        "--git-changed",
        dest="git_changed",
        action="store_true",
        help="Only files listed by git status --porcelain -- scripts.",
    )
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        help="Explicit script path (repeatable). Relative to --root unless absolute.",
    )
    parser.add_argument("--selftest", action="store_true", help="Check the deleted-path skip, dupes and the Bot checks in a throwaway repo.")
    return parser.parse_args(argv)


def selftest() -> list[str]:
    """Run main() in a temp repo: deleted --path skipped, dupes still fail, a directory --path exits 2, Bot cap still bites."""
    bad: list[str] = []
    with tempfile.TemporaryDirectory(prefix="wdb-cap-") as tmp:
        root = Path(tmp)
        (root / "project.godot").write_text("", encoding="utf-8")
        for rel_path, size in (("scripts/a/one.gd", 20), ("scripts/b/two.gd", 20), ("scripts/c/big.gd", 10000)):
            (root / rel_path).parent.mkdir(parents=True, exist_ok=True)
            (root / rel_path).write_bytes(b"#" * size)

        def run(*argv: str) -> tuple[int, str]:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
                try:
                    code = main(["--root", str(root), *argv])
                except SystemExit as exc:
                    code = int(exc.code or 0)
            return code, buf.getvalue()

        cases = [
            ("deleted + live path passes", ["--path", "scripts/gone.gd", "--path", "scripts/a/one.gd"], 0, "skipped=1"),
            ("only deleted paths pass", ["--path", "scripts/gone.gd"], 0, "checked=0"),
            ("directory path exits 2", ["--path", "scripts/a"], 2, "not a file"),
            ("Bot cap still fails next to a deleted path", ["--bot", "--path", "scripts/gone.gd", "--path", "scripts/c/big.gd"], 1, "over=1"),
        ]
        for name, argv, want, text in cases:
            code, out = run(*argv)
            if code != want or text not in out:
                bad.append(f"{name}: exit={code} (want {want}), missing {text!r}")
        (root / "scripts/b/one.gd").write_bytes(b"#")
        code, out = run("--path", "scripts/gone.gd", "--path", "scripts/a/one.gd")
        if code != 1 or "DUPE" not in out:
            bad.append(f"dupe next to a deleted path: exit={code}, want 1 with DUPE")
    return bad


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.selftest:
        bad = selftest()
        for b in bad:
            print(f"selftest: {b}")
        return agent_log.emit_result("FAIL" if bad else "PASS", None, checks=5, problems=len(bad))
    root = agent_log.resolve_root(args)
    bot = bot_gate_lib.enabled(args)
    if (args.sweep or args.list or args.over_kb is not None) and not bot:
        return bot_gate_lib.not_run("script size listing")
    if args.sweep:
        args.list, args.under_kb = True, 10.0
        args.over_kb = SWEEP_OVER_KB if args.over_kb is None else args.over_kb
    if args.over_kb is None:
        args.over_kb = SWEEP_OVER_KB if args.list else DEFAULT_OVER_KB
    limit = int(round(args.over_kb * 1000))
    if args.list:
        hi = int(round(args.under_kb * 1000)) if args.under_kb > 0 else None
        rows = gd_lib.sizes(root, limit, hi)
        under = f"{args.under_kb:g}" if hi else "none"
        body = ["root=.", f"overKb={args.over_kb:g} underKb={under} count={len(rows)}", "measure=on-disk bytes", "", "bytes\tpath"] + [f"{n}\t{r}" for n, r in rows]
        echo = [f"{len(rows)} scripts >= {args.over_kb:g}KB" + (f" and < {args.under_kb:g}KB" if hi else "")] + [f"{n:6d}  {r}" for n, r in rows[:30]]
        if len(rows) > 30:
            echo.append(f"... +{len(rows) - 30} more (summary file)")
        return agent_log.finish("script-cap", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), count=len(rows))

    args.path = agent_log.split_list(args.path)
    skipped: list[str] = []
    if args.path:
        files: list[Path] = []
        for raw in args.path:
            path = Path(raw)
            if not path.is_absolute():
                path = root / path
            if not path.exists():
                skipped.append(raw.replace("\\", "/"))  # deleted by the change: nothing left to measure
                continue
            if not path.is_file():
                agent_log.fail(f"--path {raw}: not a file (give repo-relative .gd paths, or omit for all scripts)")
            files.append(path)
    elif args.git_changed:
        found = repo_lib.git_changed(root, "scripts")
        if found is None:
            agent_log.fail("git status failed")
        files = [root / r for r in found if r.endswith(".gd") and (root / r).is_file()]
    else:
        files = gd_lib.iter_gd(root)

    over: list[tuple[int, str]] = []
    for path in files if bot else []:
        size = path.stat().st_size
        if size >= limit:
            over.append((size, agent_log.rel(root, path)))
    over.sort(key=lambda row: (-row[0], row[1]))
    # basenames must stay unique repo-wide (editor tabs, quick-open, grep, bare code-map names): design/refactor.md Cluster folders
    by_name: dict[str, list[str]] = {}
    for gp in gd_lib.iter_gd(root):
        by_name.setdefault(gp.name, []).append(agent_log.rel(root, gp))
    mine = {agent_log.rel(root, f) for f in files}
    dupes = sorted((n, ps) for n, ps in by_name.items() if len(ps) > 1 and mine & set(ps))

    lines = ["script cap" if bot else "script names", "root=."]
    if bot:
        lines += [f"overKb={args.over_kb} limit={limit}", "measure=os.path.getsize (== Get-Item Length)",
                  f"checked={len(files)} over={len(over)} dupes={len(dupes)}", "", "bytes\tpath"]
        lines += [f"{size}\t{rel}" for size, rel in over]
    else:
        lines += [f"checked={len(files)} dupes={len(dupes)}", ""]
    if skipped:
        lines.append(f"skipped={len(skipped)} (not on disk, deleted by the change): " + ", ".join(skipped))
    for name, paths in dupes:
        lines.append(f"DUPE\t{name}\t" + " | ".join(paths))
    if over:
        lines.append("next: split the file (BOT.md size flow, design/refactor.md); do not raise --over-kb")
    if dupes:
        lines.append("next: DUPE = rename one file; basenames are unique repo-wide")
    kv = dict(checked=len(files), dupes=len(dupes))
    if skipped:
        kv["skipped"] = len(skipped)
    if bot:
        kv.update(over=len(over), limit=limit)
    return agent_log.finish("script-cap", root, "\n".join(lines), "FAIL" if over or dupes else "PASS", args=args, **kv)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
