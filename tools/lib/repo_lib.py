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

def git_changed(root: Path, *pathspec: str, untracked: bool = True, renames: bool = True) -> list[str] | None:
    """Repo-relative POSIX paths from `git status --porcelain`. None if git fails. renames=False: both sides of a move."""
    cmd = ["status", "--porcelain"] + (["-u"] if untracked else []) + ([] if renames else ["--no-renames"])
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

def unpushed(root: Path) -> list[str]:
    """Paths the commits not yet on @{u} touch (both sides of a move); [] with no upstream."""
    code, out = run_git(root, "diff", "--name-only", "--no-renames", "@{u}...HEAD")
    return out.splitlines() if code == 0 else []

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

BUILD_BRANCH = re.compile(r"grok-build-w\d+")
WEB_BRANCH = re.compile(r"grok-web-w\d+")

def branch_kind(name: str) -> str:
    """Who works on branch `name`: build (grok-build-wN), web (grok-web-wN), main, or bot (bot/* and every other named
    branch, e.g. vendor-fixes). '' or HEAD (detached) is "detached"; head_kind() resolves that for a worktree."""
    name = name.removeprefix("refs/heads/").removeprefix("origin/")
    if BUILD_BRANCH.fullmatch(name):
        return "build"
    if WEB_BRANCH.fullmatch(name):
        return "web"
    if name in ("main", "master"):
        return "main"
    return "detached" if name in ("", "HEAD") else "bot"

def head_kind(root: Path) -> str:
    """branch_kind of the checked-out branch. Detached: build in a Build slice worktree (open_slice.py detaches
    wdb-<area>-<stamp> at the week branch; slice.py start writes _logs/slice-state.json), else bot."""
    code, out = run_git(root, "rev-parse", "--abbrev-ref", "HEAD")
    kind = branch_kind(out.strip() if code == 0 else "")
    if kind != "detached":
        return kind
    return "build" if root.name.startswith("wdb-") or (root / "_logs" / "slice-state.json").is_file() else "bot"

def diff_base(root: Path) -> str:
    """Default diff base for "what this work changed": the week branch on Build, else the merge-base with origin/main
    (what prove uses), else HEAD."""
    if head_kind(root) == "build" and week_branch(root):
        return week_branch(root)
    code, out = run_git(root, "merge-base", "origin/main", "HEAD")
    return out.strip() if code == 0 and out.strip() else "HEAD"

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

def git_test(cwd: Path, *args: str) -> None:
    """git with a throwaway identity, for selftests in temp repos (raises on failure)."""
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=cwd, check=True, capture_output=True)

def selftest_repo(parent: Path | str, *, empty_commit: bool = False, version: str = '{"epoch": 0, "series": 9, "patch": 0}') -> Path:
    """parent/main: a git repo with project.godot and scripts/data/version.json (uncommitted), for tool selftests."""
    main = Path(parent) / "main"
    main.mkdir()
    git_test(main, "init", "-q")
    if empty_commit:
        git_test(main, "commit", "-q", "--allow-empty", "-m", "a")
    (main / "project.godot").write_text("")
    (main / "scripts" / "data").mkdir(parents=True)
    (main / VERSION_FILE).write_text(version + "\n")
    return main
