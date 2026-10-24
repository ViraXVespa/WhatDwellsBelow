"""Red-prove retry prompt: what a Build prove tool prints when its check fails (prove is final verification, `design/tools.md` rule 10).

The reset point is the original session: the one that ran `start_build_slice.py` first in this worktree and did its Gather (id in
`_logs/slice-state.json`; later runs, the forked peer included, never overwrite it). Gather ends with the User running `/fork`; work goes on
in the peer session. A handoff opens a new worktree whose first session runs its own Gather, so it is the original for that unit. A red prove prints `grok -r <original-session-id> --fork-session`
for the USER to run from the worktree directory (no --cwd): a fork keeps the directory of the session it forks. Build never starts grok. The block
points at the work in the worktree (`git diff BASE` against the working tree plus the untracked files; BASE = the first run's --ref, else the
week branch grok-build-w{N}) and asks for one small corrective edit and one rerun. No recorded id: the block names the placeholder and where to
find the id. No base: it says so and starts nothing. `--selftest` runs the block cases.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import repo_lib

STRONG = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|ERROR:|TIMEOUT|clean=false|DUPE|assert|mismatch|fps_pct=|no bench row|hitch sink not listening", re.I)
WEAK = re.compile(r"\bFAIL\b|exit=[1-9]|missing|busy", re.I)
END = "--- end ---"

_GLES_LEAK = ("N5GLES34MeshE", "N5GLES37TextureE")

def _drop_known_leaks(lines: list[str]) -> list[str]:
    out = []
    for ln in lines:
        if "leaked at exit" in ln and any(t in ln for t in _GLES_LEAK):
            continue
        if "leaked" in ln and ("Texture with GL ID" in ln or "Buffer with GL ID" in ln):
            continue
        out.append(ln)
    return out

def pick_red(lines: list[str], n: int = 2) -> list[str]:
    lines = _drop_known_leaks(lines)
    """The n most telling red lines (errors first, then failed exits), each trimmed to one short line."""
    rows = [" ".join(ln.split()) for ln in lines]
    rows = [s for i, s in enumerate(rows) if s and not s.startswith("RESULT") and s not in rows[:i]]
    out = [s[:160] for s in rows if STRONG.search(s)] + [s[:160] for s in rows if WEAK.search(s) and not STRONG.search(s)]
    return out[:n]

def strip(lines: "list[str] | str") -> list[str]:
    """Drop RETRY blocks (head line through `--- end ---`) from a child summary embedded in a parent's body."""
    out, skip = [], False
    for ln in lines.splitlines() if isinstance(lines, str) else lines:
        skip = skip or ln.startswith("RETRY: red prove")
        if not skip:
            out.append(ln)
        elif ln.strip() == END:
            skip = False
    return out

def changed_files(root: Path, base: str, limit: int = 8) -> list[str]:
    """Files that differ from BASE in the working tree (committed or not) plus untracked ones."""
    code, out = repo_lib.run_git(root, "diff", "--name-only", base)
    files = out.splitlines() if code == 0 else []
    code, out = repo_lib.run_git(root, "ls-files", "--others", "--exclude-standard")
    files += [f for f in (out.splitlines() if code == 0 else []) if f not in files]
    return files[:limit]

def original(root: Path) -> dict:
    """{'session', 'ref'} the first start_build_slice.py run recorded in this worktree (`_logs/slice-state.json`), or {}."""
    try:
        d = json.loads((root / "_logs" / "slice-state.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return d if isinstance(d, dict) else {}

def _q(p: Path) -> str:
    return f'"{p}"' if " " in str(p) else str(p)

def block(root: Path, what: str, red: list[str]) -> str:
    """The RETRY text for a red prove `what` (a command or check name); `red` = its red output lines."""
    entry = original(root)
    session = str(entry.get("session", ""))
    base = str(entry.get("ref", "")) or repo_lib.week_branch(root)
    seen = pick_red(strip(red)) or ["(no red line captured: open the summary named on the RESULT line)"]
    head = f"RETRY: red prove ({what}). Prove is final verification: at most one small corrective edit and one rerun; still red: stop and report the log path."
    if not base:
        return "\n".join([head, "NO BASE: no grok-build-w* week branch and no saved --ref, so there is no diff to point a retry at. "
                           "Ask Vira in a question prompt (she runs `python tools/week_start.py` to start a week). Nothing is started for you.", END])
    if session:
        head += f" Retry: the User runs, from the worktree directory (`cd {_q(root)}`): `grok -r {session} --fork-session`: a fork of the original session, from the end of its Gather."
    else:
        head += (f" NO SESSION ID recorded for this worktree ({root.name}). Retry: the User runs, from the worktree directory (`cd {_q(root)}`): "
                 "`grok -r <original-session-id> --fork-session`; the original session is the one she ran `/fork` from at the end of Gather "
                 "(`/session-info` there, or `grok sessions list` in this directory). Nothing is forked or started for you.")
    head += " The fork keeps the worktree and that Gather's context; no re-gather. Paste:"
    files = changed_files(root, base)
    ask = (f'The prove "{what}" is red: {" | ".join(seen)}. The work so far, committed or not, is in this worktree: `git diff {base}` (working tree) and the untracked files. '
           f"Read only the changed files (start with {', '.join(files) or 'the files in that diff'}), "
           "then make one small corrective edit. Rerun that prove once and report; still red: stop and report the log path.")
    return "\n".join([head, "--- paste ---", ask, END])

if __name__ == "__main__":
    sys.exit(__import__("slice_lib").retry_selftest() if "--selftest" in sys.argv[1:] else print(__doc__) or 0)
