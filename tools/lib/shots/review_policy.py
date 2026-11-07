#!/usr/bin/env python3
"""Project PreToolUse policy for staged review jobs, NOT a host sandbox.

Only explicit text-review jobs gate image reads. Ordinary visual read_file stays
available. Shell use is limited to the bundled helper, never arbitrary Python.
Tool spellings come from the existing WDB hook and review runner, not guessed OCR APIs.
"""
from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

from ocr_evidence import tried
from review_local import MANIFEST, inside, parser, source

SHELL_TOOLS = {"run_terminal_command", "bash", "shell", "Shell", "Bash", "powershell", "PowerShell"}
READ_TOOLS = {"read_file", "Read", "ReadFile"}
PATH_KEYS = ("path", "file_path", "filePath", "target_file", "targetFile")


def decide(event: dict, root: Path) -> tuple[str, str]:
    data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    name = str(event.get("toolName") or event.get("tool_name") or event.get("tool") or "")
    inp = event.get("toolInput") or event.get("tool_input") or event.get("input") or {}
    if not isinstance(inp, dict):
        return "deny", "Malformed staged review tool input"
    if name in SHELL_TOOLS:
        try:
            tokens = shlex.split(str(inp.get("command") or inp.get("cmd") or ""))
            # No flags to the interpreter, pipelines, chained commands or inline Python.
            if len(tokens) < 4 or tokens[0] != data["python"] or tokens[1] != "local/review_local.py":
                raise ValueError("use the staged helper command exactly as shown in job.md")
            args = parser().parse_args(tokens[2:])
            names = args.images if args.op == "ocr" else [args.image] if args.op in ("crop", "zoom") else [args.before, args.after]
            for path in names:
                source(root, path)
            if args.op != "ocr":
                p = inside(root, args.out)
                if not p.is_relative_to(root / "out") or p.suffix.lower() != ".png":
                    raise ValueError("write helper images only to out/*.png")
            return "allow", ""
        except (ValueError, SystemExit, OSError, KeyError) as exc:
            return "deny", "Only local OCR/crop/zoom/diff helper execution is allowed: " + str(exc)
    # A media generation job keeps its existing non-review workflow; this policy
    # is installed only by the screenshot reviewer, not the media generator.
    for key in PATH_KEYS:
        if not inp.get(key):
            continue
        try:
            path = inside(root, str(inp[key]))
        except ValueError as exc:
            return "deny", str(exc)
        if name in READ_TOOLS:
            if path.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                try:
                    source(root, str(path.relative_to(root)))
                except (ValueError, OSError) as exc:
                    return "deny", str(exc)
                if data["text_review"] and not data.get("why") and not tried(root, [path]):
                    return "deny", "Text review: run the local helper ocr on this image first (weak/fail/SKIP may use vision)."
        elif path.name != "report.md" or path.parent != root:
            return "deny", "Review tools write only report.md; use the helper for out/*.png"
    return "allow", ""


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        decision, reason = decide(json.load(sys.stdin), root)
    except (OSError, ValueError, TypeError, KeyError) as exc:
        decision, reason = "deny", "Invalid staged review configuration: " + str(exc)
    print(json.dumps({"decision": decision, "reason": reason}))
    return 0 if decision == "allow" else 2


if __name__ == "__main__":
    raise SystemExit(main())
