#!/usr/bin/env python3
"""Check tools/*.py against the CLI contract in design/tools.md.

Per tool: python3 shebang, argparse, main guard, `--help` exits 0 and writes
nothing, ASCII print strings, --root on ops tools, --dry-run on writers, RESULT
via agent_log. Libs (`*_lib.py`, agent_log's siblings without a main guard) are skipped.
Also checks each tools/*.ps1 is a thin shim that calls python.
"""
from __future__ import annotations

import ast
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib

MEDIA_IMPORTS = ("PIL", "numpy", "cv2", "wave", "scipy")
# printers: stdout is the payload (prompt text to copy), so no RESULT line, no --root
PRINTERS = {"bible_prompt", "attack_keyframes", "i2v_seeds", "anim_review_tree"}
# art workflow tools that resolve paths through their own lib (anim_review_lib.ROOT)
NO_ROOT = {"anim_review_pack", "anim_review_regen"}
EXEMPT_RESULT = {"agent_log", "wdb_scratch_server"}  # run helper itself; long-running HTTP server
WRITERS = {
    "doc_patch", "patch_code_map", "code_map", "patch_tunables", "tunables", "build_changelog",
    "week_pin", "write_utf8_file", "list_unused_funcs", "bot_opt", "split_funcs", "facade_requal",
    "move_script_cluster", "archive_prior_changelogs", "enable_texture_mips",
}
ADVISORY_PS1_OK = ("python",)
PRINT_STR = re.compile(r"print\(\s*f?[\"']([^\"']*)[\"']")


def snapshot(root: Path) -> tuple:
    logs = root / "_logs"
    files = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in logs.rglob("*") if p.is_file()) if logs.is_dir() else []
    return (tuple(repo_lib.git_changed(root) or ()), tuple(files))


def classify(src: str) -> str:
    mods = set(re.findall(r"^\s*(?:import|from)\s+(\w+)", src, re.M))
    return "media" if mods & set(MEDIA_IMPORTS) else "ops"


def check_py(root: Path, path: Path, bad: list[str], tally: dict[str, int]) -> None:
    name = path.stem
    src = path.read_text(encoding="utf-8-sig")
    if name.endswith("_lib") or name.startswith("_") or "__main__" not in src:
        tally["libs"] += 1
        return
    tally["checked"] += 1
    if src[:400].lstrip("#!/usr/bin/env python3\n ").startswith('"""Shim'):
        first = src.splitlines()[0]
        if first.strip() != "#!/usr/bin/env python3":
            bad.append(f"SHEBANG {path.name}: first line must be #!/usr/bin/env python3")
        return
    kind = classify(src)
    first = src.splitlines()[0] if src else ""
    if first.strip() != "#!/usr/bin/env python3":
        bad.append(f"SHEBANG {path.name}: first line must be #!/usr/bin/env python3")
    try:
        tree = ast.parse(src)
    except SyntaxError as exc:
        bad.append(f"SYNTAX  {path.name}: {exc.msg} line {exc.lineno}")
        return
    if not re.search(r"ArgumentParser\(|std_parser\(", src):
        bad.append(f"ARGS    {path.name}: no argparse (use agent_log.std_parser)")
    if kind == "ops" and name not in PRINTERS:
        if name not in NO_ROOT and "--root" not in src and "std_parser" not in src:
            bad.append(f"ROOT    {path.name}: ops tool without --root")
        if name not in EXEMPT_RESULT and not re.search(r"agent_log\.(finish|emit_result|result_line)\(", src):
            bad.append(f"RESULT  {path.name}: ops tool must end with agent_log.finish/emit_result (final RESULT line)")
    if name in WRITERS and "--dry-run" not in src and "std_parser" not in src:
        bad.append(f"DRYRUN  {path.name}: writer without --dry-run")
    if "writes=True" not in src and name in WRITERS and "--dry-run" not in src:
        pass
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "print":
            for arg in ast.walk(node):
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str) and not arg.value.isascii():
                    bad.append(f"ASCII   {path.name}: non-ASCII in print() line {node.lineno}")
                    break
    if not re.search(r"ArgumentParser\(|std_parser\(", src):
        return  # never execute a tool that cannot parse --help
    before = snapshot(root)
    try:
        proc = subprocess.run(
            [sys.executable, str(path), "--help"], cwd=root, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL
        )
    except subprocess.TimeoutExpired:
        bad.append(f"HELP    {path.name}: --help timed out")
        return
    if proc.returncode != 0:
        bad.append(f"HELP    {path.name}: --help exit {proc.returncode}")
    elif "usage" not in proc.stdout.lower():
        bad.append(f"HELP    {path.name}: --help printed no usage")
    if snapshot(root) != before:
        bad.append(f"MUTATE  {path.name}: --help changed files")


def check_ps1(path: Path, bad: list[str]) -> None:
    src = path.read_text(encoding="utf-8-sig").lower()
    if "python" not in src or len(src) > 3000:
        bad.append(f"SHIM    {path.name}: .ps1 must be a thin shim calling the python twin")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check tools/*.py against the CLI contract.", json_out=True)
    ap.add_argument("--only", action="append", default=[], help="Only these tool stems (repeatable).")
    ap.add_argument("--no-ps1", action="store_true", help="Skip the .ps1 shim check.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    tools = root / "tools"
    bad: list[str] = []
    tally = {"checked": 0, "libs": 0}
    for path in sorted(tools.glob("*.py")):
        if args.only and path.stem not in args.only:
            continue
        check_py(root, path, bad, tally)
    ps1 = 0
    if not args.no_ps1 and not args.only:
        for path in sorted(tools.glob("*.ps1")):
            ps1 += 1
            check_ps1(path, bad)
    lines = [f"tool-cli: checked={tally['checked']} libs={tally['libs']} ps1={ps1} problems={len(bad)}"] + bad
    status = "FAIL" if bad else "PASS"
    return agent_log.finish("tool-cli", root, "\n".join(lines), status, args=args, checked=tally["checked"], ps1=ps1, problems=len(bad))


if __name__ == "__main__":
    raise SystemExit(main())
