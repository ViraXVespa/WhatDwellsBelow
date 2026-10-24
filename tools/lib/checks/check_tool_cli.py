#!/usr/bin/env python3
"""Check the tools against the CLI contract in design/tools.md.

A tool is one subcommand of an entry tool (tools/<entry>.py SUB -> tools/lib/<area>/<module>.py; boot.entries),
named here by its module stem (run_shots), or a tools/lib/*.py lib with a main guard (run directly).
Per entry (tools/*.py): shebang, a COMMANDS or MODULE table and no other logic (no def/class), every module it
names exists, bare run and --help list the subcommands, an unknown subcommand exits 2 with `error:`.
Per tool: python3 shebang, argparse, main guard, `--help` exits 0 and writes
nothing, ASCII print strings, --root on ops tools, --dry-run on writers, RESULT
via agent_log, help text on every option, output paths named `--out` / `--out-<kind>`
(OUT_NAMES), `--verbose` (agent_log.std_parser(verbose=True)) rather than a raised line budget. Libs (`*_lib.py`, agent_log's siblings without a main guard) are skipped.

`--smoke-run` also executes every tool in a throwaway copy of the repo (never the live tree): bad flag and bad
`--root` must exit 2 with an `error:` line, and each SMOKE case (read-only or `--dry-run` args) must not crash,
must end in a RESULT line, stay under the line budget, print ASCII and repo-relative paths, have no console noise
(debug/progress/banner lines, repeated lines, stderr on success), and (dry runs) leave
the copy unchanged. The per-run table (rc, lines, seconds) goes to the summary file.
"""
from __future__ import annotations
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

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

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402

import agent_log
import repo_lib

MEDIA_IMPORTS = ("PIL", "numpy", "cv2", "wave", "scipy")
# printers: stdout is the payload (prompt text to copy), so no RESULT line, no --root
PRINTERS = {"bible_prompt", "attack_keyframes", "i2v_seeds", "read_summary"}
NO_ROOT: set[str] = set()
EXEMPT_RESULT = {"agent_log", "wdb_scratch_server"}  # run helper itself; long-running HTTP server
WRITERS = {
    "doc_patch", "code_map", "tunables", "build_changelog",
    "week_pin", "list_unused_funcs", "task", "split_funcs", "facade_requal",
    "move_script_cluster", "archive_prior_changelogs", "enable_texture_mips", "ci_archive",
}
# flags `--help` must list (tool contract extras beyond --root/--dry-run); web_perf is advisory, so it needs --strict to fail
REQUIRED_HELP = {"web_perf": ("--flow", "--baseline", "--save-baseline", "--strict", "--repeat", "--site"), "export_web": ("--out",)}
ADVISORY_PS1_OK = ("python",)
# --smoke-run: tool stem -> arg lists run in the sandbox copy. A tool not listed gets only the bad-flag and bad-root probes.
# Keep every case read-only or --dry-run. No Godot, network or long-running tools here.
# A case is an arg list, or (arg list, allowed exit codes) when a clean `error:` exit 2 is the right answer in the sandbox.
_ERR = (0, 1, 2)
SMOKE: dict[str, list] = {
    "review_shots": [["--selftest"]],
    "run_isolated_grok": [["--selftest"]],
    "agent_log": [["smoke-job"], ["--selftest"]],
    "anim_review": [["pack", "--dry-run"], ["regen", "--dry-run"], ["tree", "--dry-run"]],
    "archive_prior_changelogs": [["--dry-run"]],
    "attack_keyframes": [["--beats"]],
    "bible_prompt": [["--gender", "female"], ["--enemy", "archer"], ["--list-enemies"]],
    "task": [["list"], ["check"], ["show", "opt-003"], ["--dry-run", "index"], ["--dry-run", "update", "opt-003", "--status", "open"]],
    "bot_smokes": [["--doctor"], ["--for", "scripts/app.gd"]],
    "bot_punch_list": [[], ["--bot"]],
    "bot_warnscan": [["--list"]],
    "build_changelog": [["--dry-run"]],
    "check_load_graph": [[], ["--bot"]],
    "check_script_cap": [[], ["--git-changed"], ["--sweep"], ["--bot"], ["--bot", "--sweep"], ["--bot", "--list", "--over-kb", "8"], ["--selftest"]],
    "ci_archive": [["--dry-run"], ["--selftest"]],
    "check_shot_gaps": [[]],
    "check_tool_docs": [[]],
    "clean_agent_logs": [["--dry-run"]],
    "code_map": [["check"], ["row", "scripts/app.gd"]],
    "doc_patch": [["next-label"], ["--dry-run", "replace-file", "design/tools.md", "--from-file", "design/tools.md"]],
    "enable_texture_mips": [["--dry-run"]],
    "facade_requal": [["scripts/graphics/mesh_commit.gd", "--check"]],
    "file_stat": [["--path", "tools"], ["tools/lib/agent_log.py"]],
    "gen_prompt_glyphs": [["--dry-run"]],
    "godot_lib": [["--display"]],
    "img_inspect": [["selftest"]],
    "lint_hostify": [[]],
    "list_changed": [[], ["--history", "AGENTS.md", "BOT.md"]],
    "list_dupes": [["--lang", "py"]],
    "list_facade_cluster": [["scripts/graphics/mesh_commit.gd"]],
    "list_oversize_docs": [[], ["--bot"]],
    "list_route": [[], ["debug.smokes"], ["--digest", "--door", "debug"]],
    "list_scenes": [[]],
    "list_unused_funcs": [["--dry-run"]],
    "list_xref": [["bot_status"], ["bot_status", "--all"]],
    "pack_locomotion": [["--dry-run"]], "pack_oneshot": [["--dry-run"]], "pack_turntable": [(["--dry-run"], _ERR)],
    "pages_game_hash": [[]],
    "process_gear_icons": [(["--dry-run"], _ERR)], "process_world_pass": [(["--dry-run"], _ERR)],
    "read_summary": [["bot-status"], ["bot-status", "--index"]],
    "run_shot_flow": [["--list"], ["--survey", "--flow", "camp-inventory"], ["--selftest"]],
    "show_png": [["--selftest"]], "shot_crop": [["--selftest"]], "commit_slice": [["--selftest"]],
    "make_sfx": [["--list"], ["--dry-run", "--prefix", "p2_"], ["--check", "--prefix", "p9_"]],
    "move_script_cluster": [(["--stem", "zzz", "--from-dir", "scripts/zzz", "--to-dir", "scripts/yyy", "--dry-run"], _ERR)],
    "show_func": [(["--path", "scripts/graphics/mesh_commit.gd", "--name", "no_such_func"], _ERR)],
    "split_funcs": [["scripts/graphics/mesh_commit.gd", "--list"]],
    "summarize_scripts": [[]],
    "bot_load_audit": [["--selftest"]],
    "open_slice": [["--dry-run", "--ref", "HEAD"], ["--dry-run", "--ref", "HEAD", "player"], ["--selftest"]],
    "start_build_slice": [["--door", "debug", "--job", "debug.smokes", "--dry-run", "--ref", "HEAD"], ["--selftest"]],
    "tunables": [["get", "--key", "x"], ["get", "x"]],
    "week_pin": [["--dry-run", "--id", "smoke", "--label", "l", "--desc", "d", "--commit", "abc"], ["--dry-run", "--web", "5"], ["--dry-run", "--build", "6"]],
    "week_start": [["--dry-run"]],
}
ABS_ROOT_TOOLS = {"list_xref", "open_slice", "show_func", "file_stat", "list_changed", "read_summary", "check_shot_gaps", "run_shot_flow", "run_godot_import_check"}  # may print a WARN with an absolute path when the scanned root differs
SMOKE_MAX_LINES = 30  # stdout line budget per smoke run (summary + RESULT; the rest goes to the summary file)
SMOKE_LIST_LINES = 60  # a --list / list run prints the catalog itself
TRACKED_GDIGNORE = ("_cache", "_logs", "_old", "_out", "_pages", "_src")  # root tool folders present in every clone
SMOKE_LINES: dict[str, int] = {}  # per-tool budget override; prefer agent_log.fold + --verbose to raising a budget
# Output-path flags must be `--out` (one file or folder) or `--out-<kind>` (`--out-md`, `--out-json`); these names may only be aliases.
OUT_NAMES = {"--output", "--outdir", "--out-dir", "--dest", "--md", "--png", "--json-out", "--findings-md", "--report-out"}
SMOKE_NO_RESULT = PRINTERS | {"agent_log", "wdb_scratch_server"}
NOISE_PAT = re.compile(r"^(DEBUG|debug:|TRACE)|\r|\d+%\|| ={5,}|^-{10,}$")  # debug prints, progress bars, banners
STDERR_OK = {"agent_log"}  # stems whose stderr on success is expected

def console_noise(stem: str, rc: int, out: str, err: str) -> list[str]:
    """Lines that are not the result, a needed status or an actionable error."""
    found = []
    lines = out.splitlines()
    for i, ln in enumerate(lines):
        if NOISE_PAT.search(ln):
            found.append(f"noisy line {i + 1}: {ln.strip()[:60]!r}")
            break
    dup = [ln for i, ln in enumerate(lines[1:], 1) if ln.strip() and ln == lines[i - 1]]
    if dup:
        found.append(f"repeated line {dup[0].strip()[:60]!r}")
    if rc == 0 and err.strip() and stem not in STDERR_OK:
        found.append(f"stderr on success: {err.strip().splitlines()[0][:60]!r}")
    return found

PRINT_STR = re.compile(r"print\(\s*f?[\"']([^\"']*)[\"']")

def snapshot(root: Path) -> tuple:
    logs = root / "_logs"
    files = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in logs.rglob("*") if p.is_file()) if logs.is_dir() else []
    return (tuple(repo_lib.git_changed(root) or ()), tuple(files))

def classify(src: str) -> str:
    mods = set(re.findall(r"^\s*(?:import|from)\s+(\w+)", src, re.M))
    return "media" if mods & set(MEDIA_IMPORTS) else "ops"

def units(tools: Path) -> dict[str, tuple[Path, list[str], str]]:
    """module stem -> (module file, argv prefix that runs it, label): every entry subcommand plus libs under tools/lib/ with a main guard (run directly)."""
    out: dict[str, tuple[Path, list[str], str]] = {}
    for e, rows in boot.entries(tools).items():
        for sub, mod, _ in rows:
            stem = mod.rsplit("/", 1)[-1]
            out[stem] = (tools / "lib" / f"{mod}.py", [sys.executable, str(tools / f"{e}.py"), *([sub] if sub else [])], f"{e}.py" + (f" {sub}" if sub else ""))
    for p in sorted((tools / "lib").rglob("*.py")):
        if "imglib" in p.parts or "__pycache__" in p.parts:
            continue
        if p.stem not in out and p.stem != "boot" and "__main__" in p.read_text(encoding="utf-8-sig"):
            out[p.stem] = (p, [sys.executable, str(p)], f"lib/{p.relative_to(tools / 'lib').as_posix()}")
    return out

def check_entry(root: Path, path: Path, bad: list[str]) -> None:
    """A top-level entry: a table and a dispatch call, nothing else; bare run lists, an unknown subcommand is a usage error."""
    src = path.read_text(encoding="utf-8-sig")
    if src.splitlines()[:1] != ["#!/usr/bin/env python3"]:
        bad.append(f"SHEBANG {path.name}: first line must be #!/usr/bin/env python3")
    tree = ast.parse(src)
    if any(isinstance(n, (ast.FunctionDef, ast.ClassDef)) for n in ast.walk(tree)):
        bad.append(f"ENTRY   {path.name}: an entry tool holds only its table (move the logic into tools/lib/)")
    rows = boot.entries(path.parent).get(path.stem)
    if not rows:
        bad.append(f"ENTRY   {path.name}: no COMMANDS or MODULE table (top-level tools/*.py are entry tools only)")
        return
    for sub, mod, _ in rows:
        if not (path.parent / "lib" / f"{mod}.py").is_file():
            bad.append(f"ENTRY   {path.name}: {sub or 'MODULE'} -> lib/{mod}.py does not exist")
    if rows[0][0] is None:
        return
    for argv, want in (([], 0), (["--help"], 0), (["no-such-sub"], 2)):
        p = subprocess.run([sys.executable, str(path), *argv], cwd=root, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
        if p.returncode != want or (want == 0 and not all(s in p.stdout for s, _, _ in rows)) or (want == 2 and "error:" not in p.stderr):
            bad.append(f"ENTRY   {path.name} {' '.join(argv) or '(bare)'}: want exit {want}" + (" listing every subcommand" if want == 0 else " + error: line"))

def check_py(root: Path, path: Path, bad: list[str], tally: dict[str, int], cmd: list[str] | None = None) -> None:
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
    try:
        compile(src, str(path), "exec")
    except SyntaxError as exc:
        bad.append(f"COMPILE {path.name}: {exc.msg} line {exc.lineno}")
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
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "add_argument"):
            continue
        names = [a.value for a in node.args if isinstance(a, ast.Constant) and isinstance(a.value, str)]
        if not any(k.arg == "help" for k in node.keywords):
            bad.append(f"HELPTXT {path.name}: {names[0] if names else '?'} (line {node.lineno}) has no help= text")
        if names and names[0] in OUT_NAMES:
            bad.append(f"OUTFLAG {path.name}: {names[0]} (line {node.lineno}) must be --out or --out-<kind>; keep {names[0]} as an alias after it")
    if not re.search(r"ArgumentParser\(|std_parser\(|timing_parser\(|run_writer\(", src):
        return  # never execute a tool that cannot parse --help
    before = snapshot(root)
    try:
        proc = subprocess.run(
            [*(cmd or [sys.executable, str(path)]), "--help"], cwd=root, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL
        )
    except subprocess.TimeoutExpired:
        bad.append(f"HELP    {path.name}: --help timed out")
        return
    if proc.returncode != 0:
        bad.append(f"HELP    {path.name}: --help exit {proc.returncode}")
    elif "usage" not in proc.stdout.lower():
        bad.append(f"HELP    {path.name}: --help printed no usage")
    for flag in REQUIRED_HELP.get(name, ()):
        if flag not in proc.stdout:
            bad.append(f"FLAG    {path.name}: --help does not list {flag}")
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

def smoke_one(sb: Path, stem: str, case: "list[str] | tuple", bad: list[str], table: list[str], unit: tuple) -> None:
    args, ok_codes = (case[0], case[1]) if isinstance(case, tuple) else (case, (0, 1))
    label = f"{unit[2]} {' '.join(args)}".strip()
    t0 = time.time()
    try:
        proc = subprocess.run([*unit[1], *args], cwd=sb, capture_output=True, text=True,
                              timeout=120, stdin=subprocess.DEVNULL, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "GODOT_BIN": str(sb / "no-godot")})
    except subprocess.TimeoutExpired:
        bad.append(f"TIMEOUT {label}")
        return
    out, err = proc.stdout, proc.stderr
    lines = len(out.splitlines())
    table.append(f"{unit[2]:28} rc={proc.returncode} lines={lines:<4} {time.time() - t0:5.1f}s  {' '.join(args)}")
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
        bad.append(f"RESULT  {label}: last line is not RESULT")  # pass or fail: finish() always prints it last
    budget = SMOKE_LINES.get(stem, SMOKE_LIST_LINES if {"--list", "list"} & set(args) else SMOKE_MAX_LINES)
    if lines > budget and "--json" not in args:
        bad.append(f"NOISE   {label}: {lines} lines (budget {budget}; fold with agent_log.fold and add --verbose)")
    for msg in console_noise(stem, proc.returncode, out, err):
        bad.append(f"CONSOLE {label}: {msg}")
    if not out.isascii() and stem not in PRINTERS:
        bad.append(f"ASCII   {label}: non-ASCII output")
    if sb.as_posix() in out and "--doctor" not in args and stem not in ABS_ROOT_TOOLS:  # these print the absolute root they scanned / run from  # --doctor echoes the GODOT_BIN pin (a machine path)
        bad.append(f"ABSPATH {label}: prints absolute paths (use repo-relative)")
    if "--dry-run" in args and "--help" not in args:
        rc, status = repo_lib.run_git(sb, "status", "--porcelain")
        if status.strip():
            bad.append(f"DRYRUN  {label}: changed files: {status.strip().splitlines()[0][:80]}")
            subprocess.run(["git", "checkout", "-q", "--", "."], cwd=sb)
            subprocess.run(["git", "clean", "-qfd"], cwd=sb)

def smoke_run(root: Path, only: list[str], bad: list[str]) -> tuple[int, int, list[str]]:
    sb = make_sandbox(root)
    for path in (root / "tools").rglob("*.py"):  # the live tools, not the committed ones
        (sb / path.relative_to(root)).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, sb / path.relative_to(root))
    table: list[str] = []
    found = units(sb / "tools")
    stems = sorted(found)
    runs = tools = 0
    try:
        lock = threading.Lock()
        def process_stem(stem: str) -> tuple[int, int, list[str], list[str]]:
            local_bad: list[str] = []
            local_table: list[str] = []
            unit = found[stem]
            src = unit[0].read_text(encoding="utf-8-sig")
            if (only and stem not in only) or stem.endswith("_lib") or "__main__" not in src or src.lstrip("#!/usr/bin/env python3\n ").startswith('"""Shim'):
                return 0, 0, local_bad, local_table
            cases = [["--nope"]]
            helptext = subprocess.run([*unit[1], "--help"], cwd=sb,
                                      capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60).stdout
            has_json = "--json" in helptext
            if "--root" in helptext:
                cases.append(["--root", "/nonexistent/wdb-smoke-root"])
            mine = SMOKE.get(stem, [])
            if mine and has_json and stem not in SMOKE_NO_RESULT:
                first = mine[0][0] if isinstance(mine[0], tuple) else mine[0]
                mine = mine + [(["--json"] + first, (0, 1, 2))]
            nruns = 0
            for args in cases + mine:
                nruns += 1
                with lock:
                    smoke_one(sb, stem, args, local_bad, local_table, unit)
            return 1, nruns, local_bad, local_table

        stems_to_run = [s for s in stems if not ((only and s not in only) or s.endswith("_lib"))]
        with ThreadPoolExecutor(max_workers=min(8, max(1, len(stems_to_run)))) as ex:
            futs = [ex.submit(process_stem, s) for s in stems_to_run]
            for fut in as_completed(futs):
                t_add, r_add, b_add, tab_add = fut.result()
                tools += t_add
                runs += r_add
                bad.extend(b_add)
                table.extend(tab_add)
    finally:
        if os.environ.get("WDB_KEEP_SANDBOX"):
            table.append(f"sandbox kept: {sb}")
        else:
            shutil.rmtree(sb, ignore_errors=True)
    return tools, runs, table

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check the entry tools and their subcommand modules against the CLI contract.", json_out=True)
    ap.add_argument("--only", action="append", default=[], help="Only these module stems or entry names (repeatable or comma separated; .py optional; an entry means all its subcommands).")
    ap.add_argument("--full", action="store_true", help="Check every tool (default: tools with uncommitted changes or in unpushed commits).")
    ap.add_argument("--smoke-run", action="store_true", help="Also run every tool's probes and SMOKE cases in a throwaway repo copy (about a minute).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    tools = root / "tools"
    bad: list[str] = []
    tally = {"checked": 0, "libs": 0, "entries": 0}
    found = units(tools)
    entries = {p.stem: p for p in sorted(tools.glob("*.py"))}
    by_entry = {e: [m.rsplit("/", 1)[-1] for _, m, _ in rows] for e, rows in boot.entries(tools).items()}
    args.only = [x.strip().removesuffix(".py") for o in args.only for x in o.split(",") if x.strip()]
    unknown = [x for x in args.only if x not in found and x not in entries]
    if unknown:
        agent_log.fail(f"--only: no such tool: {', '.join(unknown)} (a module stem like run_shots or an entry like shots)")
    args.only = sorted({s for x in args.only for s in ([x] if x in found else by_entry.get(x, []))} | {x for x in args.only if x in entries})
    if args.only:
        paths = [found[s][0] for s in args.only if s in found] + [entries[e] for e in args.only if e in entries]
    elif args.full:
        paths = [u[0] for u in found.values()] + list(entries.values())
    else:
        # default: tools with uncommitted changes plus tools in commits not yet on the upstream branch
        proc = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all", "tools/"], cwd=root, capture_output=True, text=True)
        names = [line[3:].strip().split(" -> ")[-1] for line in proc.stdout.splitlines()]
        ahead = subprocess.run(["git", "diff", "--name-only", "@{upstream}...HEAD", "--", "tools/"], cwd=root, capture_output=True, text=True)
        names += [line.strip() for line in ahead.stdout.splitlines()]
        dirty = {(root / n).resolve() for n in names if n.endswith(".py")}
        paths = [p for p in [u[0] for u in found.values()] + list(entries.values()) if p.resolve() in dirty]
        if not paths:
            print("tool-cli: no uncommitted or unpushed tools (use --full for everything)")
            return agent_log.emit_result("INFO", None, checked=0)
    lock = threading.Lock()
    def check_one(path: Path) -> None:
        local_bad: list[str] = []
        local_tally = {"checked": 0, "libs": 0}
        if path.parent == tools:
            check_entry(root, path, local_bad)
            local_tally["entries"] = 1
        else:
            unit = next((u for u in found.values() if u[0] == path), None)
            check_py(root, path, local_bad, local_tally, unit[1] if unit else None)
        with lock:
            bad.extend(local_bad)
            tally["checked"] += local_tally["checked"]
            tally["libs"] += local_tally["libs"]
            tally["entries"] += local_tally.get("entries", 0)
    with ThreadPoolExecutor(max_workers=min(8, max(1, len(paths)))) as ex:
        list(ex.map(check_one, paths))
    bad += [f"{d}: root underscore folder without .gdignore (Godot would import and pack it; any agent_log run adds it)"
            for d in agent_log.gdignore_underscore(root, fix=False)]
    tracked = set(subprocess.run(["git", "ls-files", "-z", "--", "_*/.gdignore"], cwd=root, capture_output=True, text=True).stdout.split("\0"))
    bad += [f"{d}/.gdignore: not tracked (fresh clones would lack it)" for d in TRACKED_GDIGNORE if f"{d}/.gdignore" not in tracked]
    smoke: dict = {}
    table: list[str] = []
    if args.smoke_run:
        n_tools, n_runs, table = smoke_run(root, [s for s in args.only if s in found], bad)
        smoke = {"smoke_tools": n_tools, "smoke_runs": n_runs}
    lines = [f"tool-cli: entries={tally['entries']} checked={tally['checked']} libs={tally['libs']} problems={len(bad)}"] + bad
    status = "FAIL" if bad else "PASS"
    return agent_log.finish("tool-cli", root, "\n".join(lines + table), status, args=args, echo="\n".join(lines),
                            entries=tally["entries"], checked=tally["checked"], problems=len(bad), **smoke)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
