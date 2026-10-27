#!/usr/bin/env python3
"""PreToolUse hook. Deny default tools the pc-offload skill replaces.

Grep of one file stays allowed. gate.py build and reading a file under edit stay allowed.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

IMAGINE_TOOLS = {
    "image_gen",
    "image_edit",
    "image_to_video",
    "ImageGen",
    "ImageEdit",
    "ImageToVideo",
}
GREP_TOOLS = {"grep", "Grep"}
LIST_TOOLS = {"list_dir", "ListDir", "glob", "Glob"}
READ_TOOLS = {"read_file", "Read", "ReadFile"}
SHELL_TOOLS = {
    "run_terminal_command",
    "bash",
    "shell",
    "Shell",
    "Bash",
    "powershell",
    "PowerShell",
}
TREE_ROOTS = ("scripts", "design", "tools", "scenes")
_SEP = r"(?:^|&&|\|\||;|\|)"
_GIT = _SEP + r"\s*git(?:\.exe)?(?:\s+-C\s+\S+)?(?:\s+--[\w.-]+)*\s+"
GIT_INVENTORY = re.compile(_GIT + r"(?:status|log|diff|show)\b", re.I | re.M)
GIT_GREP = re.compile(_GIT + r"grep\b", re.I | re.M)
SEARCH_CMD = re.compile(
    _SEP + r"\s*(?:rg|grep|findstr|find|Select-String)(?:\.exe)?\b(?!\.py)",
    re.I | re.M,
)
PY_C = re.compile(_SEP + r"\s*(?:python|python3|py)(?:\.exe)?(?:\s+-\d)?\s+-c\b", re.I | re.M)
LOG_READ = re.compile(
    r"(?:^|&&|\|\||;|\|)\s*(?:Get-Content|gc|type|cat|more)\b",
    re.I | re.M,
)
LIST_CMD = re.compile(
    r"(?:^|&&|\|\||;|\|)\s*(?:Get-ChildItem|gci|ls|dir)(?:\.exe)?\b",
    re.I | re.M,
)
BARE_LIST = re.compile(
    r"(?:^|&&|\|\||;|\|)\s*(?:Get-ChildItem|gci|ls|dir)(?:\.exe)?(?:\s+-\w+)*\s*$",
    re.I | re.M,
)
LENGTH = re.compile(r"\bLength\b")

def out(decision: str, reason: str = "") -> int:
    payload = {"decision": decision}
    if reason:
        payload["reason"] = reason
    sys.stdout.write(json.dumps(payload) + "\n")
    return 0 if decision == "allow" else 2

def load_event() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}

def as_path(value: object) -> Path | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return Path(text).expanduser()
    except OSError:
        return None

def find_repo(start: Path | None) -> Path | None:
    if start is None:
        return None
    try:
        cur = start.resolve()
    except OSError:
        return None
    for parent in (cur, *cur.parents):
        if (parent / "project.godot").is_file():
            return parent
    return None

def is_isolated(cwd: Path | None, repo: Path | None) -> bool:
    if cwd is None:
        return False
    try:
        resolved = cwd.resolve()
    except OSError:
        return False
    parts = {p.lower() for p in resolved.parts}
    if "wdb-iso" in parts:
        return True
    if repo is None:
        return True
    try:
        resolved.relative_to(repo.resolve())
        return False
    except ValueError:
        return True

def tool_blob(event: dict) -> tuple[str, dict]:
    name = str(event.get("toolName") or event.get("tool_name") or event.get("tool") or "")
    inp = event.get("toolInput") or event.get("tool_input") or event.get("input") or {}
    if not isinstance(inp, dict):
        inp = {}
    return name, inp

def input_paths(inp: dict) -> list[str]:
    found = []
    for key in ("path", "file_path", "filePath", "target_file", "targetFile", "target_directory", "targetDirectory", "directory", "glob", "pattern", "command", "cmd"):
        val = inp.get(key)
        if val:
            found.append(str(val))
    return found

def norm(text: str) -> str:
    return text.replace("\\", "/").lower()

def path_tokens(text: str) -> list[str]:
    return [tok.rstrip("/") for tok in re.split(r"[\s\"']+", norm(text)) if tok]

def mentions_root(text: str, root: str, repo: Path | None) -> bool:
    low = norm(text)
    if f"/{root}/" in f"/{low}/":
        return True
    for token in path_tokens(text):
        if token == root or token.startswith(root + "/") or token.endswith("/" + root):
            return True
    if repo is not None and norm(str(repo)) + "/" + root in low:
        return True
    return False

def hits_tree(text: str, repo: Path | None) -> bool:
    return any(mentions_root(text, root, repo) for root in TREE_ROOTS)

def hits_scenes(text: str, repo: Path | None) -> bool:
    return mentions_root(text, "scenes", repo)

def is_logs_path(text: str) -> bool:
    low = norm(text)
    if "/_logs/" in f"/{low}/" or low.startswith("_logs/"):
        return True
    for token in path_tokens(text):
        if token == "_logs" or token.startswith("_logs/") or token.endswith("/_logs"):
            return True
    return False

def is_one_file(path: str) -> bool:
    low = norm(path).rstrip("/")
    if not low or low.endswith("/"):
        return False
    base = low.split("/")[-1]
    return "." in base

def shell_command(name: str, inp: dict) -> str:
    if name not in SHELL_TOOLS and name.lower() not in {n.lower() for n in SHELL_TOOLS}:
        return ""
    return str(inp.get("command") or inp.get("cmd") or "")

def target_text(inp: dict) -> str:
    for key in ("target_directory", "targetDirectory", "directory", "path", "glob", "pattern"):
        val = inp.get(key)
        if val:
            return str(val)
    return ""

def is_repo_root(text: str, repo: Path | None, cwd: Path | None) -> bool:
    raw = text.strip().strip('"')
    if raw in ("", ".", "./"):
        return cwd is not None and repo is not None and not is_isolated(cwd, repo)
    if repo is None:
        return False
    p = as_path(raw)
    if p is None:
        return False
    try:
        return p.resolve() == repo.resolve()
    except OSError:
        return False

def list_reason(text: str, repo: Path | None, cwd: Path | None) -> str:
    if hits_scenes(text, repo):
        return "Listing scenes/ is denied. Use tools/find.py scenes."
    if is_repo_root(text, repo, cwd):
        return "Listing the repo root is denied. Use tools/find.py route."
    return "Tree list/grep over scripts|design|tools|scenes is denied. Use tools/find.py xref."

def shell_reason(cmd: str, repo: Path | None, cwd: Path | None) -> str:
    if GIT_INVENTORY.search(cmd):
        return "Git status/log/diff/show is denied. Use tools/find.py changed."
    if GIT_GREP.search(cmd) or SEARCH_CMD.search(cmd):
        return "Shell search is denied. Use tools/find.py xref. Add --path site for site/."
    if PY_C.search(cmd):
        return "python -c is denied. Use tools/find.py stat, or tools/docs.py patch write for a script body."
    if is_logs_path(cmd) and (LOG_READ.search(cmd) or LIST_CMD.search(cmd)):
        return "Reading _logs/ is denied. Use tools/session.py summary --job <name>."
    if LIST_CMD.search(cmd) and not LENGTH.search(cmd):
        if BARE_LIST.search(cmd.strip()):
            return "Listing the repo root is denied. Use tools/find.py route."
        if hits_tree(cmd, repo):
            return list_reason(cmd, repo, cwd)
    return ""

def decide(event: dict) -> tuple[str, str]:
    cwd = as_path(event.get("cwd") or event.get("workspaceRoot"))
    workspace = as_path(event.get("workspaceRoot") or event.get("cwd"))
    repo = find_repo(cwd) or find_repo(workspace)
    name, inp = tool_blob(event)
    isolated = is_isolated(cwd, repo)

    if name in IMAGINE_TOOLS:
        if isolated:
            return "allow", ""
        if repo is not None:
            return "deny", "Imagine/I2V in the game-repo cwd is denied. Use tools/media.py grok."
        return "allow", ""

    if repo is None or isolated:
        return "allow", ""

    blob = " ".join([name, *input_paths(inp)])
    low_name = name.lower()

    if low_name in {"grep"} or name in GREP_TOOLS:
        path = str(inp.get("path") or inp.get("file_path") or inp.get("filePath") or "")
        if not is_one_file(path):
            return "deny", "Repo grep of a directory is denied. Use tools/find.py xref. Add --path site for site/. Grep of one file stays allowed."

    if low_name in {"listdir", "glob"} or name in LIST_TOOLS:
        text = target_text(inp) or blob
        if hits_tree(text, repo) or is_repo_root(text, repo, cwd):
            return "deny", list_reason(text, repo, cwd)

    if name in READ_TOOLS or low_name in {"read", "read_file", "readfile"}:
        for item in input_paths(inp):
            if is_logs_path(item):
                return "deny", "Reading _logs/ is denied. Use tools/session.py summary --job <name>."

    cmd = shell_command(name, inp)
    if cmd:
        reason = shell_reason(cmd, repo, cwd)
        if reason:
            return "deny", reason

    return "allow", ""

def main() -> int:
    if "--selftest" in sys.argv[1:]:
        return selftest()
    decision, reason = decide(load_event())
    return out(decision, reason)

def selftest() -> int:
    repo = Path(__file__).resolve().parents[3]
    if not (repo / "project.godot").is_file():
        print("selftest: repo root not found", file=sys.stderr)
        return 1
    root = str(repo)
    outside = str(repo.parent / "wdb-iso" / "job")

    def ev(tool: str, inp: dict | None = None, cwd: str = root) -> dict:
        return {"toolName": tool, "toolInput": inp or {}, "cwd": cwd, "workspaceRoot": cwd}

    cases = [
        (ev("grep", {"path": "design/pc-offload.md", "pattern": "x"}), "allow"),
        (ev("grep", {"path": "scripts", "pattern": "x"}), "deny"),
        (ev("grep", {"pattern": "x"}), "deny"),
        (ev("list_dir", {"target_directory": "scenes"}), "deny"),
        (ev("list_dir", {"target_directory": root}), "deny"),
        (ev("list_dir", {"target_directory": "site/data"}), "allow"),
        (ev("read_file", {"target_file": "_logs/week-start/x.txt"}), "deny"),
        (ev("read_file", {"target_file": root + "/_logs/godot.log"}), "deny"),
        (ev("read_file", {"target_file": "design/build-week-start.md"}), "allow"),
        (ev("read_file", {"target_file": "tools/lib/release/week_start.py"}), "allow"),
        (ev("run_terminal_command", {"command": "git status --porcelain=v1 -b"}), "deny"),
        (ev("run_terminal_command", {"command": "git log -8 --oneline"}), "deny"),
        (ev("run_terminal_command", {"command": "git diff -- design/pc-offload.md"}), "deny"),
        (ev("run_terminal_command", {"command": "git show --stat"}), "deny"),
        (ev("run_terminal_command", {"command": "git add -- design/pc-offload.md; git status"}), "deny"),
        (ev("run_terminal_command", {"command": "git push origin grok-build-w9"}), "allow"),
        (ev("run_terminal_command", {"command": "git commit -m \"fix: a\""}), "allow"),
        (ev("run_terminal_command", {"command": "python tools/find.py xref --pattern foo"}), "allow"),
        (ev("run_terminal_command", {"command": "python tools/find.py changed"}), "allow"),
        (ev("run_terminal_command", {"command": "rg foo scripts"}), "deny"),
        (ev("run_terminal_command", {"command": "Select-String -Path scripts -Pattern foo"}), "deny"),
        (ev("run_terminal_command", {"command": "Get-Content _logs/week-start/x.txt"}), "deny"),
        (ev("run_terminal_command", {"command": "python tools/session.py summary --job week-start"}), "allow"),
        (ev("run_terminal_command", {"command": "python tools/session.py py --script _logs/agent-py/a.py"}), "allow"),
        (ev("run_terminal_command", {"command": "python tools/gate.py build --batch"}), "allow"),
        (ev("run_terminal_command", {"command": "python -c \"print(1)\""}), "deny"),
        (ev("run_terminal_command", {"command": "Get-ChildItem scripts"}), "deny"),
        (ev("run_terminal_command", {"command": "Get-ChildItem scripts | Select-Object Length"}), "allow"),
        (ev("run_terminal_command", {"command": "Get-ChildItem"}), "deny"),
        (ev("run_terminal_command", {"command": "Get-ChildItem site/data"}), "allow"),
        (ev("image_gen", {"prompt": "x"}), "deny"),
        (ev("image_gen", {"prompt": "x"}, cwd=outside), "allow"),
    ]
    failed = 0
    for event, want in cases:
        got, reason = decide(event)
        if got != want:
            failed += 1
            cmd = event["toolInput"].get("command") or event["toolInput"].get("path") or event["toolInput"].get("target_directory") or event["toolInput"].get("target_file") or ""
            print(f"FAIL {event['toolName']} {cmd!r} want={want} got={got} reason={reason}", file=sys.stderr)
    if failed:
        print(f"selftest: {failed} failed", file=sys.stderr)
        return 1
    print(f"selftest: {len(cases)} passed")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
