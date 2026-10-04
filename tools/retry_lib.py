"""Red-prove retry prompt: what a Build prove tool prints when its check fails.

The gather session is the point a retry returns to. `start_build_slice.py` saves its id (`save_gather`) in the git
common dir, shared by the checkout and every linked worktree; nothing is added to the tree. A red prove prints a
fork of that session into the SAME worktree (`grok --cwd PATH -r ID --fork-session`; not `--worktree`, which with -r
resumes into a NEW worktree and cannot be combined with --fork-session), so Build keeps its gather context. The block points at the diff already in the worktree (`git diff BASE...HEAD`, BASE =
the saved --ref, else the week branch grok-build-w{N}) and asks for one diagnosis and one fix (`design/tools.md`
rule 10). No gather session saved, or no base: the block says so loudly and starts nothing (no fresh session, no
main). Lookup: the saved worktree path (set by `start_build_slice.py --launch`) or the folder name. grok names the folder itself
(`~/.grok/worktrees/<repo>/<dir>`; NAME is only its label), so without a match the block lists the saved sessions to
pick from, never a guess. `--selftest` runs the save/lookup/block cases.
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

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


def save_gather(root: Path, wt: str, session: str, ref: str, where: str = "") -> str:
    """Remember the gather session for worktree `wt` (+ its folder `where` when known). Returns the file written, '' when there is no session or no git."""
    path = state_path(root)
    if not session or path is None:
        return ""
    data = _load(path)
    data[wt] = {"session": session, "ref": ref, "path": where, "saved": int(time.time())}
    for old in sorted(data, key=lambda k: data[k].get("saved", 0))[:-KEEP]:
        del data[old]
    path.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return str(path)


def _same(a: str, b: Path) -> bool:
    try:
        return bool(a) and Path(a).resolve() == b.resolve()
    except OSError:
        return False


def gather_for(root: Path) -> dict:
    """The saved entry for this worktree (its saved path, else its folder name), or {}."""
    data = _load(state_path(root))
    for name, e in data.items():
        if isinstance(e, dict) and _same(str(e.get("path", "")), root):
            return e
    e = data.get(root.name)
    return e if isinstance(e, dict) else {}


def _q(p: Path) -> str:
    return f'"{p}"' if " " in str(p) else str(p)


def block(root: Path, what: str, red: list[str]) -> str:
    """The RETRY text for a red prove `what` (a command or check name); `red` = its red output lines."""
    entry = gather_for(root)
    session = str(entry.get("session", ""))
    base = str(entry.get("ref", "")) or repo_lib.week_branch(root)
    cands = sorted(((k, v) for k, v in _load(state_path(root)).items() if isinstance(v, dict) and v.get("session")), key=lambda kv: -int(kv[1].get("saved", 0)))
    seen = pick_red(red) or ["(no red line captured: open the summary named on the RESULT line)"]
    head = f"RETRY: red prove ({what})."
    if not base:
        return "\n".join([head, "NO BASE: no grok-build-w* week branch and no saved --ref, so there is no diff to point a retry at. "
                           "Ask Vira in a question prompt (she runs `python tools/week_start.py` to start a week). Nothing is started for you."])
    if not session:
        pick = "".join(f"\n  START {k} ({v.get('ref') or 'week branch'}): grok --cwd {_q(root)} -r {v['session']} --fork-session" for k, v in cands[:3])
        head += (f" NO MATCHING GATHER SESSION for this worktree ({root.name}). "
                 + ("grok names the folder itself, so START's name does not match it. Saved gather sessions, newest first; use the one from YOUR START:" + pick + "\nNone is yours? "
                    if cands else "start_build_slice.py had no --session / $GROK_SESSION_ID, so there is nothing to fork from. ")
                 + "No fresh session is started for you. Ask Vira in a question prompt for the gather session id "
                 "or her OK to retry in a fresh session. Paste only after that:")
    else:
        head += (f" Fork the gather session into this worktree (keeps your gather context; no re-gather, no new worktree): "
                 f"`grok --cwd {_q(root)} -r {session} --fork-session`. (Docs do not say if -r finds a session saved under another directory; if grok says it is missing, tell Vira.) Paste:")
    files = changed_files(root, base)
    ask = (f'The prove "{what}" is red: {" | ".join(seen)}. The work so far is already in this worktree: `git diff {base}...HEAD`. '
           f"Read only the changed files (start with {', '.join(files) or 'the files in that diff'}), "
           "then give one diagnosis and make one fix. Rerun that prove once and report.")
    return "\n".join([head, "--- paste ---", ask, "--- end ---"])


if __name__ == "__main__":
    sys.exit(__import__("slice_lib").retry_selftest() if "--selftest" in sys.argv[1:] else print(__doc__) or 0)
