#!/usr/bin/env python3
"""Check tools/*.py against the CLI contract in design/tools.md.

Per tool: python3 shebang, argparse, main guard, `--help` exits 0 and writes
nothing, ASCII print strings, --root on ops tools, --dry-run on writers, RESULT
via agent_log. Libs (`*_lib.py`, agent_log's siblings without a main guard) are skipped.
Also checks each tools/*.ps1 is a thin shim that calls python.

`--smoke-run` also executes every tool in a throwaway copy of the repo (never the live tree): bad flag and bad
`--root` must exit 2 with an `error:` line, and each SMOKE case (read-only or `--dry-run` args) must not crash,
must end in a RESULT line, stay under the line budget, print ASCII and repo-relative paths, and (dry runs) leave
the copy unchanged. The per-run table (rc, lines, seconds) goes to the summary file.
"""
from __future__ import annotations

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib

MEDIA_IMPORTS = ("PIL", "numpy", "cv2", "wave", "scipy")
# printers: stdout is the payload (prompt text to copy), so no RESULT line, no --root
PRINTERS = {"bible_prompt", "attack_keyframes", "i2v_seeds", "read_summary"}
NO_ROOT: set[str] = set()
EXEMPT_RESULT = {"agent_log", "wdb_scratch_server"}  # run helper itself; long-running HTTP server
WRITERS = {
    "doc_patch", "patch_code_map", "code_map", "tunables", "build_changelog",
    "week_pin", "write_utf8_file", "list_unused_funcs", "bot_opt", "split_funcs", "facade_requal",
    "move_script_cluster", "archive_prior_changelogs", "enable_texture_mips",
}
ADVISORY_PS1_OK = ("python",)
# --smoke-run: tool stem -> arg lists run in the sandbox copy. A tool not listed gets only the bad-flag and bad-root probes.
# Keep every case read-only or --dry-run. No Godot, network or long-running tools here.
# A case is an arg list, or (arg list, allowed exit codes) when a clean `error:` exit 2 is the right answer in the sandbox.
_ERR = (0, 1, 2)
SMOKE: dict[str, list] = {
    "agent_log": [["smoke-job"]],
    "anim_review_pack": [["--dry-run"]], "anim_review_regen": [["--dry-run"]], "anim_review_tree": [["--dry-run"]],
    "archive_prior_changelogs": [["--dry-run"]],
    "attack_keyframes": [["--beats"]],
    "bible_prompt": [["--gender", "female"]],
    "bot_opt": [["--list"]],
    "bot_smokes": [["--doctor"], ["--for", "scripts/app.gd"]],
    "bot_status": [[], ["--sweep"]],
    "bot_warnscan": [["--list"]],
    "build_changelog": [["--dry-run"]],
    "check_code_map": [[]],
    "check_load_graph": [[]],
    "check_script_cap": [[], ["--git-changed"]],
    "check_shot_gaps": [[]],
    "check_tool_docs": [[]],
    "clean_agent_logs": [["--dry-run"]],
    "code_map": [["check"], ["row", "scripts/app.gd"]],
    "doc_patch": [["next-label"], ["--dry-run", "replace-file", "design/tools.md", "--from-file", "design/tools.md"]],
    "enable_texture_mips": [["--dry-run"]],
    "facade_requal": [["scripts/graphics/mesh_commit.gd", "--check"]],
    "file_stat": [["--path", "tools"], ["tools/agent_log.py"]],
    "gen_prompt_glyphs": [["--dry-run"]],
    "godot_lib": [["--display"]],
    "lint_hostify": [[]],
    "list_changed": [[]],
    "list_dupes": [["--lang", "py"]],
    "list_facade_cluster": [["scripts/graphics/mesh_commit.gd"]],
    "list_oversize_docs": [[]],
    "list_oversize_scripts": [[]],
    "list_route": [[], ["debug.smokes"]],
    "list_scenes": [[]],
    "list_unused_funcs": [["--dry-run"]],
    "list_xref": [["bot_status"]],
    "make_p2_sfx": [["--dry-run"]], "make_p9_sfx": [["--dry-run"]], "make_placeholder_audio": [["--dry-run"]],
    "pack_facing_fix": [(["--dry-run"], _ERR)], "pack_locomotion": [["--dry-run"]], "pack_oneshot": [["--dry-run"]],
    "pack_p2_art": [(["--dry-run"], _ERR)], "pack_turntable": [(["--dry-run"], _ERR)], "pack_walk": [(["--dry-run"], _ERR)],
    "pages_game_hash": [[]],
    "process_enemies": [(["--dry-run"], _ERR)], "process_gear_icons": [(["--dry-run"], _ERR)], "process_gloam": [(["--dry-run"], _ERR)],
    "process_session_sprites": [(["--dry-run"], _ERR)], "process_sprites": [(["--dry-run"], _ERR)],
    "process_world": [(["--dry-run"], _ERR)], "process_world_pass": [(["--dry-run"], _ERR)],
    "read_summary": [["bot-status"]],
    "rekey_stills": [(["--dry-run"], _ERR)],
    "report_grok_sessions": [[]], "report_grok_week": [["--dry-run"]],
    "run_shot_flow": [["--list"]],
    "show_func": [(["--path", "scripts/graphics/mesh_commit.gd", "--name", "no_such_func"], _ERR)],
    "split_funcs": [["scripts/graphics/mesh_commit.gd", "--list"]],
    "summarize_scripts": [[]],
    "start_build_slice": [["--door", "debug", "--job", "debug.smokes", "--dry-run"]],
    "tunables": [["get", "--key", "x"], ["get", "x"]],
    "week_pin": [["--dry-run", "--id", "smoke", "--label", "l", "--desc", "d", "--commit", "abc"]],
    "week_start": [["--dry-run"]],
}
SMOKE_MAX_LINES = 40  # stdout line budget per smoke run
SMOKE_LINES = {"list_dupes": 70, "bot_status": 60, "list_oversize_docs": 120}  # per-tool override for reports that are the payload
SMOKE_NO_RESULT = PRINTERS | {"agent_log", "wdb_scratch_server"}
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
    if not re.search(r"ArgumentParser\(|std_parser\(|timing_parser\(|run_writer\(", src):
        bad.append(f"ARGS    {path.name}: no argparse (use agent_log.std_parser)")
    if kind == "ops" and name not in PRINTERS:
        if name not in NO_ROOT and "--root" not in src and "std_parser" not in src and "timing_parser" not in src and "run_writer" not in src:
            bad.append(f"ROOT    {path.name}: ops tool without --root")
        if name not in EXEMPT_RESULT and not re.search(r"(agent_log\.(finish|emit_result|result_line|run_writer|guarded)|godot_lib\.timing_job)\(", src):
            bad.append(f"RESULT  {path.name}: ops tool must end with agent_log.finish/emit_result (final RESULT line)")
    if name in WRITERS and "--dry-run" not in src and "std_parser" not in src and "run_writer" not in src:
        bad.append(f"DRYRUN  {path.name}: writer without --dry-run")
    if "writes=True" not in src and name in WRITERS and "--dry-run" not in src:
        pass
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "print":
            for arg in ast.walk(node):
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str) and not arg.value.isascii():
                    bad.append(f"ASCII   {path.name}: non-ASCII in print() line {node.lineno}")
                    break
    if not re.search(r"ArgumentParser\(|std_parser\(|timing_parser\(|run_writer\(", src):
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


def make_sandbox(root: Path) -> Path:
    """Copy tracked + untracked-not-ignored files into a temp dir with its own git history."""
    sb = Path(tempfile.mkdtemp(prefix="wdb-smoke-"))
    raw = subprocess.run(["git", "ls-files", "-z", "-co", "--exclude-standard"], cwd=root, capture_output=True).stdout
    for rel in filter(None, raw.decode("utf-8", "replace").split("\0")):
        src = root / rel
        if src.is_file():
            (sb / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, sb / rel)
    git = ["git", "-c", "user.name=smoke", "-c", "user.email=smoke@local"]
    for cmd in (["init", "-q"], ["add", "-A"], ["commit", "-qm", "base"]):
        subprocess.run(git + cmd, cwd=sb, capture_output=True)
    return sb


def smoke_one(sb: Path, stem: str, case: "list[str] | tuple", bad: list[str], table: list[str]) -> None:
    args, ok_codes = (case[0], case[1]) if isinstance(case, tuple) else (case, (0, 1))
    label = f"{stem} {' '.join(args)}".strip()
    t0 = time.time()
    try:
        proc = subprocess.run([sys.executable, str(sb / "tools" / f"{stem}.py"), *args], cwd=sb, capture_output=True, text=True,
                              timeout=120, stdin=subprocess.DEVNULL, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "GODOT_BIN": str(sb / "no-godot")})
    except subprocess.TimeoutExpired:
        bad.append(f"TIMEOUT {label}")
        return
    out, err = proc.stdout, proc.stderr
    lines = len(out.splitlines())
    table.append(f"{stem:28} rc={proc.returncode} lines={lines:<4} {time.time() - t0:5.1f}s  {' '.join(args)}")
    probe = args[:1] in (["--nope"],) or args[:1] == ["--root"]
    if "Traceback" in err or "Traceback" in out:
        bad.append(f"CRASH   {label}: {err.strip().splitlines()[-1][:100] if err.strip() else 'traceback'}")
        return
    if probe:
        if proc.returncode != 2 or "error" not in err.lower():
            bad.append(f"USAGE   {label}: want exit 2 + an error: line on stderr, got exit {proc.returncode}")
        return
    if args[:1] != ["--json"] and proc.returncode not in ok_codes:
        bad.append(f"EXIT    {label}: exit {proc.returncode} ({err.strip().splitlines()[-1][:90] if err.strip() else 'no message'})")
    last = out.strip().splitlines()[-1] if out.strip() else ""
    if args[:1] == ["--json"]:
        try:
            ok = isinstance(json.loads(out), dict)
        except ValueError:
            ok = False
        if not ok:
            bad.append(f"JSON    {label}: stdout is not exactly one JSON object ({lines} lines)")
        return
    if proc.returncode == 2 and "error:" in err:
        pass  # clean failure with a message
    elif stem not in SMOKE_NO_RESULT and not last.startswith("RESULT ") and not last.startswith("{"):
        bad.append(f"RESULT  {label}: last line is not RESULT")
    if lines > SMOKE_LINES.get(stem, SMOKE_MAX_LINES) and "--json" not in args:
        bad.append(f"NOISE   {label}: {lines} lines (budget {SMOKE_LINES.get(stem, SMOKE_MAX_LINES)})")
    if not out.isascii() and stem not in PRINTERS:
        bad.append(f"ASCII   {label}: non-ASCII output")
    if sb.as_posix() in out and "--doctor" not in args:  # --doctor echoes the GODOT_BIN pin (a machine path)
        bad.append(f"ABSPATH {label}: prints absolute paths (use repo-relative)")
    if "--dry-run" in args and "--help" not in args:
        rc, status = repo_lib.run_git(sb, "status", "--porcelain")
        if status.strip():
            bad.append(f"DRYRUN  {label}: changed files: {status.strip().splitlines()[0][:80]}")
            subprocess.run(["git", "checkout", "-q", "--", "."], cwd=sb)
            subprocess.run(["git", "clean", "-qfd"], cwd=sb)


def smoke_run(root: Path, only: list[str], bad: list[str]) -> tuple[int, int, list[str]]:
    sb = make_sandbox(root)
    for path in (root / "tools").glob("*.py"):  # the live tools, not the committed ones
        shutil.copy2(path, sb / "tools" / path.name)
    table: list[str] = []
    stems = [p.stem for p in sorted((root / "tools").glob("*.py"))]
    runs = tools = 0
    try:
        for stem in stems:
            src = (sb / "tools" / f"{stem}.py").read_text(encoding="utf-8-sig")
            if (only and stem not in only) or stem.endswith("_lib") or "__main__" not in src or src.lstrip("#!/usr/bin/env python3\n ").startswith('"""Shim'):
                continue
            tools += 1
            cases = [["--nope"]]
            helptext = subprocess.run([sys.executable, str(sb / "tools" / f"{stem}.py"), "--help"], cwd=sb, capture_output=True, text=True,
                                      stdin=subprocess.DEVNULL, timeout=60).stdout
            has_json = "--json" in helptext
            if "--root" in helptext:
                cases.append(["--root", "/nonexistent/wdb-smoke-root"])
            mine = SMOKE.get(stem, [])
            if mine and has_json and stem not in SMOKE_NO_RESULT:
                first = mine[0][0] if isinstance(mine[0], tuple) else mine[0]
                mine = mine + [(["--json"] + first, (0, 1, 2))]
            for args in cases + mine:
                runs += 1
                smoke_one(sb, stem, args, bad, table)
    finally:
        if os.environ.get("WDB_KEEP_SANDBOX"):
            table.append(f"sandbox kept: {sb}")
        else:
            shutil.rmtree(sb, ignore_errors=True)
    return tools, runs, table


def check_ps1(path: Path, bad: list[str]) -> None:
    src = path.read_text(encoding="utf-8-sig").lower()
    if "python" not in src or len(src) > 3000:
        bad.append(f"SHIM    {path.name}: .ps1 must be a thin shim calling the python twin")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check tools/*.py against the CLI contract.", json_out=True)
    ap.add_argument("--only", action="append", default=[], help="Only these tool stems (repeatable).")
    ap.add_argument("--no-ps1", action="store_true", help="Skip the .ps1 shim check.")
    ap.add_argument("--smoke-run", action="store_true", help="Also run every tool's probes and SMOKE cases in a throwaway repo copy (about a minute).")
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
    smoke: dict = {}
    table: list[str] = []
    if args.smoke_run:
        n_tools, n_runs, table = smoke_run(root, args.only, bad)
        smoke = {"smoke_tools": n_tools, "smoke_runs": n_runs}
    lines = [f"tool-cli: checked={tally['checked']} libs={tally['libs']} ps1={ps1} problems={len(bad)}"] + bad
    status = "FAIL" if bad else "PASS"
    return agent_log.finish("tool-cli", root, "\n".join(lines + table), status, args=args, echo="\n".join(lines),
                            checked=tally["checked"], ps1=ps1, problems=len(bad), **smoke)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
