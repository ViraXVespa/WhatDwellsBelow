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
import json
import re
import sys
from pathlib import Path

_JOB_KEY = re.compile(r"^[A-Za-z0-9._-]+$")
STATUSES = ("PASS", "FAIL", "INFO")


def repo_root(hint: str | Path | None = None) -> Path:
    """Walk up from hint, this file, then cwd to the dir holding project.godot."""
    starts: list[Path] = []
    if hint:
        starts.append(Path(hint).expanduser().resolve())
    starts += [Path(__file__).resolve().parent, Path.cwd().resolve()]
    for start in starts:
        here = start if start.is_dir() else start.parent
        for cand in (here, *here.parents):
            if (cand / "project.godot").is_file():
                return cand
    raise FileNotFoundError("agent_log: repo root not found (no project.godot)")


def rel(root: Path | str, path: Path | str) -> str:
    try:
        return Path(path).resolve().relative_to(Path(root).resolve()).as_posix()
    except ValueError:
        return Path(path).as_posix()


def std_parser(description: str, *, writes: bool = False, json_out: bool = False) -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=description)
    ap.add_argument("--root", default=None, help="Repo root (default: auto-discovered).")
    if writes:
        ap.add_argument("--dry-run", dest="dry_run", action="store_true", help="Print what would change; write nothing.")
    if json_out:
        ap.add_argument("--json", dest="json", action="store_true", help="Print one JSON object instead of text.")
    return ap


def resolve_root(args_or_hint: object = None) -> Path:
    hint = args_or_hint if isinstance(args_or_hint, (str, Path)) else getattr(args_or_hint, "root", None)
    return repo_root(hint)


def fail(msg: str, code: int = 2) -> "None":
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def result_line(status: str, summary: str | None = None, **kv: object) -> str:
    if status not in STATUSES:
        raise ValueError(f"agent_log: status must be one of {STATUSES}")
    parts = ["RESULT", status] + [f"{k}={v}" for k, v in kv.items() if v is not None]
    if summary:
        parts.append(f"summary={summary}")
    return " ".join(parts)


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
    **kv: object,
) -> int:
    """Write the summary, print body + legacy line + final RESULT, return the exit code.

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
        if body:
            print(body.rstrip("\n"))
        if legacy and path is not None:
            print(f"Summary -> {path}")
        print(res)
    return exit_code(status)


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
