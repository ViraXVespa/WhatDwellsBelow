"""Red-prove retry prompt: what a Build prove tool prints when its check fails.

A retry runs in the SAME worktree as a fresh-eyes session (no fork, no new worktree). The worktree's git
history is the revert point. The printed block carries a ready-to-paste prompt: which prove failed, the red
output, the changed files to read first, and the ask (one diagnosis, one fix; `design/tools.md` rule 10).
"""
from __future__ import annotations

import re
from pathlib import Path

import repo_lib

STRONG = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|ERROR:|TIMEOUT|clean=false|DUPE|assert|mismatch", re.I)
WEAK = re.compile(r"\bFAIL\b|exit=[1-9]|missing|busy", re.I)


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


def block(root: Path, what: str, red: list[str]) -> str:
    """The RETRY text for a red prove `what` (a command or check name); `red` = its red output lines."""
    base = repo_lib.week_branch(root) or "main"
    files = changed_files(root, base)
    seen = pick_red(red) or ["(no red line captured: open the summary named on the RESULT line)"]
    ask = (f'The prove "{what}" is red: {" | ".join(seen)}. Run `git diff {base}...HEAD` to see what is done, '
           f"read only the changed files (start with {', '.join(files) or 'the files in that diff'}), "
           "then give one diagnosis and make one fix. Rerun that prove once and report.")
    return "\n".join([f"RETRY: red prove ({what}). Start a fresh session in this worktree ({root.name}); no fork, no new worktree. Paste:",
                      "--- paste ---", ask, "--- end ---"])
