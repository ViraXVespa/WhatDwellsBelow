#!/usr/bin/env python3
"""Repo helpers shared by tools: git, changed files, allowlist, version label.

Import-only. Root discovery and RESULT/summary live in agent_log.
"""
from __future__ import annotations

import json
import re
import subprocess
from fnmatch import fnmatch
from pathlib import Path

ALLOW_FILE = "tools/bot_allow.txt"
VERSION_FILE = "scripts/data/version.json"


def run_git(root: Path, *args: str) -> tuple[int, str]:
    """(returncode, stdout or stderr). 127 when git is missing."""
    try:
        proc = subprocess.run(["git", *args], cwd=root, check=False, capture_output=True, text=True)
    except FileNotFoundError:
        return 127, "git-not-found"
    out = (proc.stdout or "").rstrip()
    return proc.returncode, out if out else (proc.stderr or "").rstrip()


def git_changed(root: Path, *pathspec: str, untracked: bool = True) -> list[str] | None:
    """Repo-relative POSIX paths from `git status --porcelain`. None if git fails."""
    cmd = ["status", "--porcelain"] + (["-u"] if untracked else [])
    if pathspec:
        cmd += ["--", *pathspec]
    code, out = run_git(root, *cmd)
    if code != 0:
        return None
    paths: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        rel = line[3:].strip()
        if " -> " in rel:
            rel = rel.split(" -> ", 1)[1]
        if rel:
            paths.append(rel.strip('"').replace("\\", "/"))
    return paths


def load_allowlist(root: Path) -> list[str]:
    """Globs from tools/bot_allow.txt (comments stripped, `!` negations kept)."""
    path = root / ALLOW_FILE
    if not path.is_file():
        return []
    out: list[str] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        raw = line.split("#", 1)[0].strip()
        if raw:
            out.append(raw)
    return out


def allowed(rel: str, globs: list[str]) -> bool:
    posix = rel.replace("\\", "/")
    for pattern in globs:
        if pattern.startswith("!"):
            if fnmatch(posix, pattern[1:]):
                return False
            continue
        if fnmatch(posix, pattern):
            return True
    return False


def read_version(root: Path) -> dict:
    return json.loads((root / VERSION_FILE).read_text(encoding="utf-8-sig"))


def week_branch(root: Path) -> str:
    """Current week branch grok-build-w{N}: the highest N among local grok-build-w* branches that match the
    version.json series or are an ancestor of HEAD (a worktree cut before the seed still sees its week). '' if none."""
    code, out = run_git(root, "for-each-ref", "--format=%(refname:short)", "refs/heads/grok-build-w*")
    names = [n for n in out.splitlines() if code == 0 and re.fullmatch(r"grok-build-w\d+", n)]
    try:
        series = int(read_version(root)["series"])
    except (OSError, KeyError, ValueError):
        series = -1
    keep = [n for n in names if int(n.rsplit("w", 1)[1]) == series or run_git(root, "merge-base", "--is-ancestor", n, "HEAD")[0] == 0]
    return max(keep, key=lambda n: int(n.rsplit("w", 1)[1]), default="")


def next_label(root: Path) -> str:
    """Baked version.json epoch.series.(patch+1). Stamp commits are ignored."""
    v = read_version(root)
    return f"{int(v['epoch'])}.{int(v['series'])}.{int(v['patch']) + 1}"


def changelog_dir(root: Path) -> Path:
    return root / "design" / "changelog"


def under(path: Path, root: Path) -> bool:
    """True when `path` resolves inside `root`."""
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def write_text_nl(path: Path, text: str) -> None:
    """Write UTF-8 text with a trailing newline, creating parent folders."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")
