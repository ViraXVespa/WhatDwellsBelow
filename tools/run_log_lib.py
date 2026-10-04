"""Run-log layout for _logs/<job>/: every run writes its own timestamped files, nothing is overwritten.

    _logs/<job>/index.txt                  newest run first: stamp, status, summary file, RESULT notes (last 20 kept)
    _logs/<job>/<stamp>-<job>.txt          one run's summary (its last line is the RESULT line)
    _logs/<job>/<stamp>-<name>.log         a run's raw logs and artifacts, same stamp

<stamp> is local time YYYYMMDD-HHMMSS (+NN when two runs of one job start in the same second). Keep-count pruning
runs on every write: the 20 newest stamps stay per folder, older stamped files go. The weekly clear is
`clean_agent_logs.py --new-week`. Read a job with `read_summary.py --job NAME` (index first, then the newest summary).
`python tools/agent_log.py --selftest` checks this layout in a throwaway folder.
"""
from __future__ import annotations

import re
import time
from pathlib import Path

KEEP = 20
INDEX = "index.txt"
LEGACY = "summary.txt"
STAMP_RE = re.compile(r"^(\d{8}-\d{6}(?:\+\d+)?)-(.+)$")
_STAMPS: dict[tuple[str, str], str] = {}


def stamp_of(name: str) -> str:
    m = STAMP_RE.match(name)
    return m.group(1) if m else ""


def stamp_for(d: Path, job: str) -> str:
    """The stamp of this process's run of `job` in folder `d`; the first call reserves <stamp>-<job>.txt."""
    key = (str(d.resolve()), job)
    if key in _STAMPS:
        return _STAMPS[key]
    d.mkdir(parents=True, exist_ok=True)
    while True:
        base = time.strftime("%Y%m%d-%H%M%S")
        newest = max((stamp_of(f.name) for f in d.iterdir() if stamp_of(f.name)), default="")
        stamp = base
        if newest >= base:  # same second (or a clock step back): sort after every existing run
            head, _, n = newest.partition("+")
            stamp = f"{head}+{int(n or 1) + 1:02d}"
        try:
            with (d / f"{stamp}-{job}.txt").open("x", encoding="utf-8"):
                pass
            break
        except FileExistsError:
            continue
    _STAMPS[key] = stamp
    return stamp


def run_path(d: Path, job: str, name: str) -> Path:
    """Path for a raw log or artifact of this run: <stamp>-<name> (never reused by a later run)."""
    return d / f"{stamp_for(d, job)}-{name}"


def summary_path(d: Path, job: str) -> Path:
    return run_path(d, job, f"{job}.txt")


def entries(d: Path) -> list[tuple[str, str, str, str]]:
    """Index rows (stamp, status, file, note) newest first; rows whose file is gone are dropped."""
    p = d / INDEX
    rows: list[tuple[str, str, str, str]] = []
    if p.is_file():
        for ln in p.read_text(encoding="utf-8", errors="replace").splitlines():
            if ln.startswith("#") or not ln.strip():
                continue
            c = (ln.split("\t") + ["", "", "", ""])[:4]
            if (d / c[2]).is_file():
                rows.append((c[0], c[1], c[2], c[3]))
    return rows


def latest(d: Path) -> Path | None:
    """Newest run's summary file, else a legacy summary.txt, else None."""
    rows = entries(d)
    if rows:
        return d / rows[0][2]
    old = d / LEGACY
    return old if old.is_file() else None


def prune(d: Path, keep: int = KEEP) -> int:
    """Delete stamped files of all but the `keep` newest stamps in `d`. Returns the number of files removed."""
    files = [f for f in d.iterdir() if f.is_file() and stamp_of(f.name)] if d.is_dir() else []
    stamps = sorted({stamp_of(f.name) for f in files}, reverse=True)
    drop = set(stamps[keep:])
    n = 0
    for f in files:
        if stamp_of(f.name) in drop:
            f.unlink(missing_ok=True)
            n += 1
    return n


def record(d: Path, summary: Path, status: str, note: str = "", keep: int = KEEP) -> None:
    """Put a finished run at the top of index.txt, then prune to the newest `keep` runs."""
    _STAMPS.pop((str(d.resolve()), summary.name[len(stamp_of(summary.name)) + 1:-4]), None)  # next run gets a new stamp
    old = [r for r in entries(d) if r[2] != summary.name]
    new = (stamp_of(summary.name), status, summary.name, " ".join(note.split()))
    prune(d, keep)
    rows = [new] + [r for r in old if (d / r[2]).is_file()]
    body = [f"# {d.name} runs, newest first (last {keep} kept; one summary per run, never overwritten)"]
    body += ["\t".join(r) for r in rows[:keep]]
    (d / INDEX).write_text("\n".join(body) + "\n", encoding="utf-8")


def write_summary(d: Path, job: str, text: str, status: str = "INFO", note: str = "") -> Path:
    """Write this run's summary file (never an existing one), index it, prune. Returns its path."""
    p = summary_path(d, job)
    p.write_text(text.rstrip("\n") + "\n", encoding="utf-8")
    record(d, p, status, note)
    return p


def clear(d: Path) -> int:
    """Weekly clear of one folder: stamped files, index.txt and a legacy summary.txt. Returns files removed."""
    n = 0
    for f in d.iterdir() if d.is_dir() else []:
        if f.is_file() and (stamp_of(f.name) or f.name in (INDEX, LEGACY)):
            f.unlink(missing_ok=True)
            n += 1
    return n


def selftest(tmp: Path) -> list[str]:
    """Problems found (empty = ok). Writes 25 runs of a fake job into `tmp`."""
    bad: list[str] = []
    d = tmp / "demo"
    seen: set[str] = set()
    for i in range(25):
        raw = run_path(d, "demo", "err.log")
        raw.write_text(f"raw {i}\n", encoding="utf-8")
        p = write_summary(d, "demo", f"run {i}", "PASS" if i % 2 == 0 else "FAIL", f"i={i}")
        if p.name in seen:
            bad.append(f"summary name reused: {p.name}")
        seen.add(p.name)
        if latest(d) != p:
            bad.append(f"latest() is not run {i}")
    rows = entries(d)
    if len(rows) != KEEP:
        bad.append(f"index has {len(rows)} rows, want {KEEP}")
    if rows and rows[0][3] != "i=24":
        bad.append(f"index not newest first: top note {rows[0][3] if rows else ''}")
    if rows and rows[-1][3] != "i=5":
        bad.append("index does not end at the 20th newest run")
    runs = {stamp_of(f.name) for f in d.iterdir() if stamp_of(f.name)}
    if len(runs) != KEEP:
        bad.append(f"{len(runs)} stamps kept on disk, want {KEEP}")
    if len(list(d.glob("*-err.log"))) != KEEP:
        bad.append("raw logs were not kept per run")
    if clear(d) < KEEP or any(d.iterdir()):
        bad.append("clear() left files behind")
    _STAMPS.clear()
    return bad
