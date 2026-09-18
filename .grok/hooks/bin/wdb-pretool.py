#!/usr/bin/env python3
from __future__ import annotations

import json
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
GREP_TOOLS = {"grep", "Grep", "list_dir", "ListDir", "glob", "Glob"}
READ_TOOLS = {"read_file", "Read", "ReadFile"}
TREE_ROOTS = ("scripts", "design", "tools", "scenes")


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
    for key in ("path", "file_path", "filePath", "target_directory", "targetDirectory", "directory", "glob", "pattern", "command"):
        val = inp.get(key)
        if val:
            found.append(str(val))
    return found


def hits_tree(text: str, repo: Path | None) -> bool:
    low = text.replace("\\", "/").lower()
    for root in TREE_ROOTS:
        if f"/{root}/" in f"/{low}/" or low.startswith(f"{root}/") or low == root:
            return True
        if repo is not None:
            marker = str(repo).replace("\\", "/").lower() + f"/{root}"
            if marker in low:
                return True
    return False


def is_fat_log(text: str) -> bool:
    low = text.replace("\\", "/").lower()
    if "summary.txt" in low:
        return False
    if "/_logs/" not in low and not low.startswith("_logs/"):
        return False
    return low.endswith(".log") or low.endswith(".err") or "-out.log" in low or "-err.log" in low


def main() -> int:
    event = load_event()
    cwd = as_path(event.get("cwd") or event.get("workspaceRoot"))
    workspace = as_path(event.get("workspaceRoot") or event.get("cwd"))
    repo = find_repo(cwd) or find_repo(workspace)
    name, inp = tool_blob(event)
    isolated = is_isolated(cwd, repo)

    if name in IMAGINE_TOOLS:
        if isolated:
            return out("allow")
        if repo is not None:
            return out(
                "deny",
                "Imagine/I2V in the game-repo cwd is denied. Use tools/run_isolated_grok.py.",
            )
        return out("allow")

    blob = " ".join([name, *input_paths(inp)])
    if name in GREP_TOOLS or name.lower() in {"grep", "listdir", "glob"}:
        if repo is not None and not isolated and hits_tree(blob, repo):
            return out(
                "deny",
                "Tree grep/list_dir over scripts|design|tools|scenes is denied. Use list_xref.ps1.",
            )

    if name in READ_TOOLS or "read" in name.lower():
        for item in input_paths(inp):
            if is_fat_log(item):
                return out(
                    "deny",
                    "Raw Godot logs under _logs/ are denied. Read summary.txt via read_summary.ps1.",
                )

    return out("allow")


if __name__ == "__main__":
    raise SystemExit(main())