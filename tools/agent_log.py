#!/usr/bin/env python3
"""Run helpers for every tools/*.py: repo root, std CLI, RESULT line, summary files.

Contract (see design/tools.md): argparse, --root, --dry-run on writers, --json on
reports, ASCII output, repo-relative POSIX paths, one final line
`RESULT <PASS|FAIL|INFO> k=v ... summary=<rel>`, exit 0 ok / 1 findings / 2 usage.
Each run writes its own `_logs/<job>/<stamp>-<job>.txt` (gitignored, never overwritten) and `index.txt` lists
the newest runs first (`run_log_lib.py`). No session keys.

    python tools/agent_log.py <job>     # prints dir/index for a job, makes the dir
    python tools/agent_log.py --selftest   # run-log layout check in a throwaway folder
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

import run_log_lib

_JOB_KEY = re.compile(r"^[A-Za-z0-9._-]+$")
STATUSES = ("PASS", "FAIL", "INFO")
DRY_RUN = False  # set by run_writer --dry-run; tools that fan out to worker processes run serially when true


GROK_SESSIONS_DEFAULT = r"C:\Users\Vira\.grok\sessions"


def grok_sessions(*rest: str) -> Path:
    """Grok session store: $WDB_GROK_SESSIONS or the default above; `rest` parts may use backslashes."""
    base = Path(os.environ.get("WDB_GROK_SESSIONS") or GROK_SESSIONS_DEFAULT)
    return base.joinpath(*[p for r in rest for p in r.split("\\") if p])


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


_REAL_STDOUT = None  # set while --json diverts text output; the final JSON object goes to the real stdout


def _json_on(ns: argparse.Namespace) -> None:
    global _REAL_STDOUT
    if getattr(ns, "json", False) is True and _REAL_STDOUT is None:
        _REAL_STDOUT = sys.stdout
        sys.stdout = io.StringIO()  # progress text is dropped; stdout carries exactly one JSON object


def _json_print(obj: dict) -> bool:
    """Print obj as the one JSON object (restoring stdout if --json diverted it). False when not in JSON mode."""
    global _REAL_STDOUT
    if _REAL_STDOUT is None:
        return False
    sys.stdout, _REAL_STDOUT = _REAL_STDOUT, None
    print(json.dumps(obj, sort_keys=False))
    return True


class _Parser(argparse.ArgumentParser):
    def parse_args(self, args=None, namespace=None):
        ns = super().parse_args(args, namespace)
        _json_on(ns)
        return ns


def std_parser(description: str, *, writes: bool = False, json_out: bool = True) -> argparse.ArgumentParser:
    """Parser with --root, --json and (writes=True) --dry-run. json_out stays for old callers; every tool gets --json."""
    ap = _Parser(description=description)
    ap.add_argument("--root", default=None, help="Repo root (default: auto-discovered).")
    if writes:
        ap.add_argument("--dry-run", dest="dry_run", action="store_true", help="Print what would change; write nothing.")
    if json_out:
        ap.add_argument("--json", dest="json", action="store_true", help="Print one JSON object (status, summary, counts) instead of text.")
    return ap


def split_list(values: object, cast: type = str) -> list:
    """Flatten ['a,b', 'c'] (comma or space separated) into [a, b, c]."""
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


def cwd_scan_root(args: object) -> tuple[Path, str]:
    """(root, `root=<absolute>` line) for a tool that scans a project: --root, else the current directory's project (else the tool's own).
    The line carries a WARN when the scanned root is not the current directory's project."""
    hint = getattr(args, "root", None)
    cwd_root = None
    if not hint:
        try:
            cwd_root = repo_root(Path.cwd())
        except FileNotFoundError:
            pass
    root = resolve_root(hint or cwd_root)
    return root, f"root={root}" + (f" WARN: the current directory's project is {cwd_root}, not this root; pass --root {cwd_root}" if cwd_root and cwd_root != root else "")


def fail(msg: str, code: int = 2) -> "None":
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def print_json(obj: dict) -> None:
    """Print obj as the one JSON object of a --json run (restores stdout when --json diverted it)."""
    if not _json_print(obj):
        print(json.dumps(obj))


def _err(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    _json_print({"status": "FAIL", "error": msg})


def _cwd_rel(name: object) -> object:
    """Path relative to the cwd when under it (errors print repo-relative paths)."""
    try:
        return Path(str(name)).resolve().relative_to(Path.cwd().resolve()).as_posix() if name else name
    except ValueError:
        return name


def guarded(main, *args: object) -> int:
    """Run main(*args); a missing/unreadable path or a bare SystemExit("msg") becomes `error: ...` + exit 2, not a traceback."""
    try:
        return main(*args)
    except (FileNotFoundError, NotADirectoryError, PermissionError) as exc:
        name = _cwd_rel(getattr(exc, "filename", None))
        why = "missing path" if isinstance(exc, (FileNotFoundError, NotADirectoryError)) else "no permission"
        _err(f"{why}: {name}" if name else str(exc))
        return 2
    except SystemExit as exc:
        if isinstance(exc.code, str):
            _err(re.sub(r"^(FAIL|error:)\s+", "", exc.code))
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
    """Print the final RESULT line (no summary file) and return the exit code. Under --json: one JSON object instead."""
    if not _json_print({"status": status, "summary": summary, **kv}):
        print(result_line(status, summary, **kv))
    return exit_code(status)


def exit_code(status: str) -> int:
    return 1 if status == "FAIL" else 0


def agent_log_dir(job: str, root: Path | None = None) -> Path:
    if not _JOB_KEY.fullmatch(job):
        raise ValueError("agent_log: bad job name")
    return (repo_root(root) / "_logs" / job).resolve()


def agent_summary_path(job: str, root: Path | None = None) -> Path:
    """The newest run's summary file of `job` (a missing summary.txt path when the job has not run)."""
    d = agent_log_dir(job, root)
    return run_log_lib.latest(d) or d / run_log_lib.LEGACY


def ensure_agent_log_dir(job: str, root: Path | None = None) -> Path:
    path = agent_log_dir(job, root)
    path.mkdir(parents=True, exist_ok=True)
    return path


def run_path(job: str, root: Path, name: str) -> Path:
    """This run's own raw log or artifact path: _logs/<job>/<stamp>-<name>. Never reused by a later run."""
    return run_log_lib.run_path(ensure_agent_log_dir(job, root), job, name)


def write_summary(job: str, root: Path, body: str, status: str = "INFO", note: str = "") -> Path:
    """Write this run's summary (a new file per run), update index.txt, prune to the newest 20 runs."""
    return run_log_lib.write_summary(ensure_agent_log_dir(job, root), job, body, status, note)


def write_run_file(root: Path, d: Path, job: str, body: str, status: str, write: bool = True, **kv: object) -> str:
    """Run summary for a tool with its own out folder `d`: body + RESULT line (naming the new stamped file),
    indexed and pruned like finish(); write=False (dry run) writes nothing. Returns the RESULT line to print last."""
    if not write:
        return result_line(status, None, **kv)
    p = run_log_lib.summary_path(d, job)
    res = result_line(status, rel(root, p), **kv)
    p.write_text((body.rstrip("\n") + "\n" if body else "") + res + "\n", encoding="utf-8")
    run_log_lib.record(d, p, status, " ".join(f"{k}={v}" for k, v in kv.items() if v is not None))
    return res


def finish(
    job: str,
    root: Path,
    body: str,
    status: str,
    *,
    args: object = None,
    legacy: bool = False,
    write: bool = True,
    echo: str | None = None,
    retry: tuple[str, list[str]] | None = None,
    **kv: object,
) -> int:
    """Write this run's summary file, print body + legacy line + final RESULT, return the exit code.

    echo: print this instead of body on stdout (body still goes to the summary file).
    retry: (prove name, red lines) of a Build prove; on FAIL the paste-ready RETRY block is added (retry_lib.py).
    With --json (args.json) prints one JSON object and nothing else.
    """
    summary_rel = None
    path = None
    if retry and status == "FAIL":
        import retry_lib

        note = retry_lib.block(root, retry[0], retry[1])
        body = "\n".join(retry_lib.strip(body))
        body = (body.rstrip("\n") + "\n\n" if body else "") + note
        echo = None if echo is None else "\n".join(retry_lib.strip(echo)).rstrip("\n") + "\n\n" + note
    if write:
        d = ensure_agent_log_dir(job, root)
        path = run_log_lib.summary_path(d, job)
        summary_rel = rel(root, path)
        res = result_line(status, summary_rel, **kv)
        path.write_text((body.rstrip("\n") + "\n" + res if body else res) + "\n", encoding="utf-8")
        run_log_lib.record(d, path, status, " ".join(f"{k}={v}" for k, v in kv.items() if v is not None))
    else:
        res = result_line(status, None, **kv)
    if getattr(args, "json", False) is True:
        if not _json_print({"status": status, "summary": summary_rel, **kv}):
            print(json.dumps({"status": status, "summary": summary_rel, **kv}, sort_keys=False))
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


def run_writer(tool: str, desc: str, run, argv: list[str] | None = None, g: "dict | list | None" = None, job: str | None = None, add_args=None) -> int:
    """Shared main for the one-shot art generators: --root, --dry-run, --verbose, folded output, summary + RESULT.

    run() does the work and prints one line per file; g=globals() lets --root re-point the module's Path constants
    (the ones under its ROOT; a list of dicts rebases several modules). add_args(parser) adds tool flags and then
    run(args) gets the namespace. Default stdout is the first 8 lines + a count; the full text is in the summary file.
    """
    ap = std_parser(desc, writes=True)
    ap.epilog = f"Env: WDB_GROK_SESSIONS = Grok session store the source images/videos are read from (default {GROK_SESSIONS_DEFAULT})."
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
                err = f"missing path: {_cwd_rel(getattr(exc, 'filename', None)) or exc}"
            except SystemExit as exc:
                if not isinstance(exc.code, str):
                    raise
                err = exc.code
    finally:
        os.chdir(here)
    lines = [ln.replace(root.as_posix() + "/", "") for ln in buf.getvalue().splitlines()]
    wrote = sum(1 for ln in lines if ln.startswith(("wrote", "would write")))
    missing = sum(1 for ln in lines if ln.startswith("missing"))
    shown = lines if args.verbose or len(lines) <= 12 else lines[:8] + [f"... {len(lines) - 8} more lines (summary file has all)"]
    body = "\n".join(lines)
    if err:
        if shown:
            print("\n".join(shown), file=sys.stderr)
        _err(err)
        return 2
    status = "FAIL" if missing and not wrote else "PASS"  # every source missing = nothing happened
    return finish(job or tool, root, body, status, args=args, legacy=False, echo="\n".join(shown), tool=tool, wrote=wrote, missing=missing, dry_run=bool(args.dry_run))


def main(argv: list[str] | None = None) -> int:
    ap = std_parser("Print (and create) the _logs/<job> directory for a job.")
    ap.add_argument("job", nargs="?", default="", help="Job name, e.g. build-gate.")
    ap.add_argument("--job", dest="job_opt", default="", help="Same as the positional job.")
    ap.add_argument("--selftest", action="store_true", help="Check the run-log layout (stamped files, index, prune, clear) in a temp folder.")
    args = ap.parse_args(argv)
    if args.selftest:
        import tempfile

        with tempfile.TemporaryDirectory(prefix="wdb-runlog-") as tmp:
            bad = run_log_lib.selftest(Path(tmp))
        for b in bad:
            print(f"selftest: {b}")
        return emit_result("FAIL" if bad else "PASS", None, checks=8, problems=len(bad))
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
    print(f"index=_logs/{job}/index.txt")
    print(result_line("INFO", f"_logs/{job}/index.txt", job=job))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
