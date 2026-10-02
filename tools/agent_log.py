#!/usr/bin/env python3
"""Run helpers for every tools/*.py: repo root, std CLI, RESULT line, summary files.

Contract (see design/tools.md): argparse, --root, --dry-run on writers, --json on
reports, ASCII output, repo-relative POSIX paths, one final line
`RESULT <PASS|FAIL|INFO> k=v ... summary=<rel>`, exit 0 ok / 1 findings / 2 usage.
Summaries go to `_logs/<job>/summary.txt` (gitignored). No session keys.

    python3 tools/agent_log.py <job>     # prints dir/summary for a job, makes the dir
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import re
import sys
from pathlib import Path

_JOB_KEY = re.compile(r"^[A-Za-z0-9._-]+$")
STATUSES = ("PASS", "FAIL", "INFO")
DRY_RUN = False  # set by run_legacy --dry-run; tools that fan out to worker processes run serially when true


def repo_root(hint: str | Path | None = None) -> Path:
    """Walk up from hint, else from this file, then cwd, to the dir holding project.godot.

    An explicit hint (--root) that is not inside a repo is an error, never a silent fallback.
    """
    starts: list[Path] = []
    if hint:
        starts.append(Path(hint).expanduser().resolve())
    else:
        starts += [Path(__file__).resolve().parent, Path.cwd().resolve()]
    for start in starts:
        here = start if start.is_dir() else start.parent
        for cand in (here, *here.parents):
            if (cand / "project.godot").is_file():
                return cand
    where = f" at or above {starts[0]}" if hint else ""
    raise FileNotFoundError(f"repo root not found (no project.godot{where}); pass --root <repo dir>" if hint else "repo root not found (no project.godot); run from the repo or pass --root <repo dir>")


def rel(root: Path | str, path: Path | str) -> str:
    try:
        return Path(path).resolve().relative_to(Path(root).resolve()).as_posix()
    except ValueError:
        return Path(path).as_posix()


def std_parser(description: str, *, writes: bool = False, json_out: bool = False) -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=description)
    ap.add_argument("--root", "-Root", default=None, help="Repo root (default: auto-discovered).")
    if writes:
        ap.add_argument("--dry-run", "-DryRun", "-WhatIf", dest="dry_run", action="store_true", help="Print what would change; write nothing.")
    if json_out:
        ap.add_argument("--json", dest="json", action="store_true", help="Print one JSON object instead of text.")
    return ap


def split_list(values: object, cast: type = str) -> list:
    """Flatten ['a,b', 'c'] (comma/space separated, PowerShell style) into [a, b, c]."""
    out: list = []
    for v in values or []:
        out += [cast(p) for p in re.split(r"[,\s]+", str(v)) if p]
    return out


def resolve_root(args_or_hint: object = None) -> Path:
    hint = args_or_hint if isinstance(args_or_hint, (str, Path)) else getattr(args_or_hint, "root", None)
    try:
        return repo_root(hint)
    except FileNotFoundError as exc:
        fail(str(exc))


def fail(msg: str, code: int = 2) -> "None":
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def guarded(main, *args: object) -> int:
    """Run main(*args); a missing/unreadable path or a bare SystemExit("msg") becomes `error: ...` + exit 2, not a traceback."""
    try:
        return main(*args)
    except (FileNotFoundError, NotADirectoryError, PermissionError) as exc:
        name = getattr(exc, "filename", None)
        why = "missing path" if isinstance(exc, (FileNotFoundError, NotADirectoryError)) else "no permission"
        print(f"error: {why}: {name}" if name else f"error: {exc}", file=sys.stderr)
        return 2
    except SystemExit as exc:
        if isinstance(exc.code, str):
            print("error: " + re.sub(r"^(FAIL|error:)\s+", "", exc.code), file=sys.stderr)
            return 2
        raise
    except KeyboardInterrupt:
        print("error: interrupted", file=sys.stderr)
        return 130


def result_line(status: str, summary: str | None = None, **kv: object) -> str:
    if status not in STATUSES:
        raise ValueError(f"agent_log: status must be one of {STATUSES}")
    parts = ["RESULT", status] + [f"{k}={v}" for k, v in kv.items() if v is not None]
    if summary:
        parts.append(f"summary={summary}")
    return " ".join(parts)


def emit_result(status: str, summary: str | None = None, **kv: object) -> int:
    """Print the final RESULT line (no summary file) and return the exit code."""
    print(result_line(status, summary, **kv))
    return exit_code(status)


def exit_code(status: str) -> int:
    return 1 if status == "FAIL" else 0


def agent_log_dir(job: str, root: Path | None = None) -> Path:
    if not _JOB_KEY.fullmatch(job):
        raise ValueError("agent_log: bad job name")
    return (repo_root(root) / "_logs" / job).resolve()


def agent_summary_path(job: str, root: Path | None = None) -> Path:
    return agent_log_dir(job, root) / "summary.txt"


def ensure_agent_log_dir(job: str, root: Path | None = None) -> Path:
    path = agent_log_dir(job, root)
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_summary(job: str, root: Path, body: str) -> Path:
    path = agent_summary_path(job, root)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body.rstrip("\n") + "\n", encoding="utf-8")
    return path


def finish(
    job: str,
    root: Path,
    body: str,
    status: str,
    *,
    args: object = None,
    legacy: bool = True,
    write: bool = True,
    echo: str | None = None,
    **kv: object,
) -> int:
    """Write the summary, print body + legacy line + final RESULT, return the exit code.

    echo: print this instead of body on stdout (body still goes to the summary file).
    With --json (args.json) prints one JSON object and nothing else.
    """
    summary_rel = None
    path = None
    if write:
        summary_rel = f"_logs/{job}/summary.txt"
        res = result_line(status, summary_rel, **kv)
        path = write_summary(job, root, body.rstrip("\n") + "\n" + res if body else res)
    else:
        res = result_line(status, None, **kv)
    if getattr(args, "json", False):
        obj = {"status": status, "summary": summary_rel, **{k: v for k, v in kv.items()}}
        print(json.dumps(obj, sort_keys=False))
    else:
        shown = body if echo is None else echo
        if shown:
            print(shown.rstrip("\n"))
        if legacy and path is not None:
            print(f"Summary -> {path}")
        print(res)
    return exit_code(status)


def _call(fn, args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        res = fn(*args)
    return res, buf.getvalue()


def run_jobs(jobs: list) -> list:
    """Run [(fn, args), ...] in a process pool (serial when one job or under --dry-run). Worker prints and string
    results are echoed in finish order, so output is the same on fork and spawn platforms."""
    out: list = []
    if not jobs:
        return out
    if DRY_RUN or len(jobs) == 1:
        results = [_call(fn, args) for fn, args in jobs]
    else:
        from concurrent.futures import ProcessPoolExecutor, as_completed

        with ProcessPoolExecutor() as pool:
            results = [f.result() for f in as_completed([pool.submit(_call, fn, args) for fn, args in jobs])]
    for res, text in results:
        if text:
            print(text, end="")
        if isinstance(res, str):
            print(res)
        out.append(res)
    return out


def _dry_writes() -> "contextlib.ExitStack":
    """Patch the common write paths (PIL save, mkdir, Path writes, shutil copies, wave, subprocess) to print `would write X`."""
    import shutil
    import subprocess
    import unittest.mock as mock
    from pathlib import Path as P

    def say(kind):
        def fake(*a, **k):
            print(f"would {kind} {a[1] if kind == 'write' and len(a) > 1 else a[0] if a else ''}")
            return subprocess.CompletedProcess(a, 0, "", "") if kind == "run" else None
        return fake

    st = contextlib.ExitStack()
    targets = [(P, "mkdir", lambda *a, **k: None), (P, "write_bytes", lambda s, *a, **k: print(f"would write {s}")),
               (P, "write_text", lambda s, *a, **k: print(f"would write {s}")),
               (shutil, "copy", lambda s, d, *a, **k: print(f"would write {d}")), (shutil, "copy2", lambda s, d, *a, **k: print(f"would write {d}")),
               (shutil, "copyfile", lambda s, d, *a, **k: print(f"would write {d}")), (shutil, "move", lambda s, d, *a, **k: print(f"would write {d}")),
               (subprocess, "run", lambda c, *a, **k: print(f"would run {(c[0] if isinstance(c, (list, tuple)) else c)}") or subprocess.CompletedProcess(c, 0, "", ""))]
    try:
        from PIL import Image
        targets.append((Image.Image, "save", lambda s, fp, *a, **k: print(f"would write {fp}")))
    except ImportError:
        pass
    for obj, name, fake in targets:
        st.enter_context(mock.patch.object(obj, name, fake))
    return st


def run_legacy(tool: str, desc: str, run, argv: list[str] | None = None, g: "dict | list | None" = None, job: str | None = None, add_args=None) -> int:
    """Shared main for the one-shot art generators: --root, --dry-run, --verbose, folded output, summary + RESULT.

    run() does the work and prints one line per file; g=globals() lets --root re-point the module's Path constants
    (the ones under its ROOT; a list of dicts rebases several modules). add_args(parser) adds tool flags and then
    run(args) gets the namespace. Default stdout is the first 8 lines + a count; the full text is in the summary file.
    """
    ap = std_parser(desc, writes=True)
    ap.add_argument("--verbose", "-v", action="store_true", help="Print every line (default: first 8 and a count).")
    if add_args:
        add_args(ap)
    args = ap.parse_args(argv)
    root = resolve_root(args)
    for mod in (g if isinstance(g, list) else [g] if g is not None else []):
        old = mod.get("REPO") or mod.get("ROOT")
        if isinstance(old, Path) and old.resolve() != root:
            for k, v in list(mod.items()):
                if isinstance(v, Path):
                    try:
                        mod[k] = root / v.resolve().relative_to(old.resolve())
                    except ValueError:
                        pass
    global DRY_RUN
    DRY_RUN = bool(args.dry_run)
    buf = io.StringIO()
    err = None
    here = Path.cwd()
    os.chdir(root)  # some tools use repo-relative paths
    try:
        with contextlib.ExitStack() as st:
            if args.dry_run:
                st.enter_context(_dry_writes())
            st.enter_context(contextlib.redirect_stdout(buf))
            try:
                run(args) if add_args else run()
            except (FileNotFoundError, NotADirectoryError) as exc:
                err = f"missing path: {getattr(exc, 'filename', None) or exc}"
            except SystemExit as exc:
                if not isinstance(exc.code, str):
                    raise
                err = exc.code
    finally:
        os.chdir(here)
    lines = [ln.replace(root.as_posix() + "/", "") for ln in buf.getvalue().splitlines()]
    wrote = sum(1 for ln in lines if ln.startswith(("wrote", "would write")))
    missing = sum(1 for ln in lines if ln.startswith("missing"))
    shown = lines if args.verbose or len(lines) <= 8 else lines[:8] + [f"... {len(lines) - 8} more lines (summary file has all)"]
    body = "\n".join(lines)
    if err:
        print("\n".join(shown), file=sys.stderr) if shown else None
        print(f"error: {err}", file=sys.stderr)
        return 2
    status = "FAIL" if missing and not wrote else "PASS"  # every source missing = nothing happened
    return finish(job or tool, root, body, status, args=args, legacy=False, echo="\n".join(shown), tool=tool, wrote=wrote, missing=missing, dry_run=bool(args.dry_run))


def main(argv: list[str] | None = None) -> int:
    ap = std_parser("Print (and create) the _logs/<job> directory for a job.")
    ap.add_argument("job", nargs="?", default="", help="Job name, e.g. build-gate.")
    ap.add_argument("--job", dest="job_opt", default="", help="Same as the positional job.")
    args = ap.parse_args(argv)
    job = args.job_opt or args.job
    try:
        root = resolve_root(args)
        if not job:
            print(result_line("INFO", root=".", logs="_logs"))
            return 0
        ensure_agent_log_dir(job, root)
    except (OSError, ValueError) as exc:
        fail(str(exc))
    print(f"job={job}")
    print(f"dir=_logs/{job}")
    print(f"summary=_logs/{job}/summary.txt")
    print(result_line("INFO", f"_logs/{job}/summary.txt", job=job))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
