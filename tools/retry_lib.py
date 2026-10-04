"""Red-prove retry prompt: what a Build prove tool prints when its check fails.

The gather session is the point a retry returns to. `start_build_slice.py` saves its id (`save_gather`) in the git
common dir, shared by the checkout and every linked worktree; nothing is added to the tree. A red prove prints a
fork of that session into the SAME worktree (`grok --cwd PATH -r ID --fork-session`), so Build keeps its gather
context and does not re-gather. The block points at the diff already in the worktree (`git diff BASE...HEAD`, BASE =
the saved --ref, else the week branch grok-build-w{N}) and asks for one diagnosis and one fix (`design/tools.md`
rule 10). No gather session saved, or no base: the block says so loudly and starts nothing (no fresh session, no
main). Lookup key = the worktree folder name (`--worktree=NAME`). `--selftest` runs the save/lookup/block cases.
"""
from __future__ import annotations

import json
import re
import sys
import tempfile
import time
from pathlib import Path

import agent_log
import repo_lib

STRONG = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|ERROR:|TIMEOUT|clean=false|DUPE|assert|mismatch", re.I)
WEAK = re.compile(r"\bFAIL\b|exit=[1-9]|missing|busy", re.I)
KEEP = 20


def pick_red(lines: list[str], n: int = 2) -> list[str]:
    """The n most telling red lines (errors first, then failed exits), each trimmed to one short line."""
    rows = [" ".join(ln.split()) for ln in lines]
    rows = [s for i, s in enumerate(rows) if s and not s.startswith("RESULT") and s not in rows[:i]]
    out = [s[:160] for s in rows if STRONG.search(s)] + [s[:160] for s in rows if WEAK.search(s) and not STRONG.search(s)]
    return out[:n]


def changed_files(root: Path, base: str, limit: int = 8) -> list[str]:
    code, out = repo_lib.run_git(root, "diff", "--name-only", f"{base}...HEAD")
    files = out.splitlines() if code == 0 else []
    if not files:
        files = repo_lib.git_changed(root) or []
    return files[:limit]


def state_path(root: Path) -> Path | None:
    """Gather-session file in the git common dir (outside the tree, shared by all worktrees); None without git."""
    code, out = repo_lib.run_git(root, "rev-parse", "--git-common-dir")
    if code != 0 or not out:
        return None
    d = Path(out)
    return (d if d.is_absolute() else root / d).resolve() / "wdb-gather-sessions.json"


def _load(path: Path | None) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8")) if path and path.is_file() else {}
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_gather(root: Path, wt: str, session: str, ref: str) -> str:
    """Remember the gather session for worktree `wt`. Returns the file written, '' when there is no session or no git."""
    path = state_path(root)
    if not session or path is None:
        return ""
    data = _load(path)
    data[wt] = {"session": session, "ref": ref, "saved": int(time.time())}
    for old in sorted(data, key=lambda k: data[k].get("saved", 0))[:-KEEP]:
        del data[old]
    path.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return str(path)


def gather_for(root: Path) -> dict:
    """The saved entry for this worktree (key = its folder name), or {}."""
    return _load(state_path(root)).get(root.name) or {}


def _q(p: Path) -> str:
    return f'"{p}"' if " " in str(p) else str(p)


def block(root: Path, what: str, red: list[str]) -> str:
    """The RETRY text for a red prove `what` (a command or check name); `red` = its red output lines."""
    entry = gather_for(root)
    session = str(entry.get("session", ""))
    base = str(entry.get("ref", "")) or repo_lib.week_branch(root)
    seen = pick_red(red) or ["(no red line captured: open the summary named on the RESULT line)"]
    head = f"RETRY: red prove ({what})."
    if not base:
        return "\n".join([head, "NO BASE: no grok-build-w* week branch and no saved --ref, so there is no diff to point a retry at. "
                           "Ask Vira in a question prompt (she runs `python tools/week_start.py` to start a week). Nothing is started for you."])
    if not session:
        others = ", ".join(f"{k}={v.get('session')}" for k, v in _load(state_path(root)).items() if isinstance(v, dict))
        head += (f" NO GATHER SESSION is saved for this worktree ({root.name}): start_build_slice.py had no --session / $GROK_SESSION_ID, "
                 + (f"or its worktree name differs from this folder (saved: {others}); " if others else "")
                 + "so there is nothing to fork from. No fresh session is started for you. Ask Vira in a question prompt for the gather session id "
                 "(then `grok --cwd PATH -r ID --fork-session`) or her OK to retry in a fresh session. Paste only after that:")
    else:
        head += (f" Fork the gather session into this worktree (keeps your gather context; no re-gather, no new worktree): "
                 f"`grok --cwd {_q(root)} -r {session} --fork-session`. Paste:")
    files = changed_files(root, base)
    ask = (f'The prove "{what}" is red: {" | ".join(seen)}. The work so far is already in this worktree: `git diff {base}...HEAD`. '
           f"Read only the changed files (start with {', '.join(files) or 'the files in that diff'}), "
           "then give one diagnosis and make one fix. Rerun that prove once and report.")
    return "\n".join([head, "--- paste ---", ask, "--- end ---"])


def selftest() -> int:
    """Save/lookup/block in a throwaway git repo: with session, without session, without base."""
    import subprocess

    def git(cwd: Path, *a: str) -> None:
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *a], cwd=cwd, check=True, capture_output=True)

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        main = Path(td) / "main"
        main.mkdir()
        git(main, "init", "-q")
        (main / "a.txt").write_text("a\n")
        git(main, "add", "-A")
        git(main, "commit", "-qm", "a")
        git(main, "branch", "grok-build-w9")
        wt = Path(td) / "wdb-x-1"
        git(main, "worktree", "add", "-q", "--detach", str(wt), "grok-build-w9")
        (wt / "b.txt").write_text("b\n")
        git(wt, "add", "-A")
        git(wt, "commit", "-qm", "b")
        red = ["SCRIPT ERROR: Parse Error: x"]
        no_ses = block(wt, "gate", red)
        for need in ("NO GATHER SESSION", "git diff grok-build-w9...HEAD", "No fresh session"):
            if need not in no_ses:
                bad.append(f"no-session block lacks {need!r}")
        if "abc-123" in no_ses:
            bad.append("no-session block names a session")
        if not save_gather(main, "wdb-x-1", "abc-123", ""):
            bad.append("save_gather wrote nothing")
        other = Path(td) / "wdb-other"
        git(main, "worktree", "add", "-q", "--detach", str(other), "grok-build-w9")
        if "saved: wdb-x-1=abc-123" not in block(other, "gate", red):
            bad.append("a worktree with no entry must list the saved ones")
        with_ses = block(wt, "gate", red)
        for need in (f"grok --cwd {wt} -r abc-123 --fork-session", "git diff grok-build-w9...HEAD", "b.txt", "one diagnosis"):
            if need not in with_ses:
                bad.append(f"session block lacks {need!r}")
        if save_gather(main, "wdb-x-2", "", "r"):
            bad.append("empty session was saved")
        git(main, "branch", "-D", "grok-build-w9")
        gone = block(wt, "gate", red)
        if "NO BASE" not in gone or "git diff" in gone:
            bad.append("no-base block wrong")
        save_gather(main, "wdb-x-1", "abc-123", "my-ref")
        if "git diff my-ref...HEAD" not in block(wt, "gate", red):
            bad.append("saved ref not used as base")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv[1:] else print(__doc__) or 0)
