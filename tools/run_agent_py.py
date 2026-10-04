#!/usr/bin/env python3
"""Run a python script; delete it afterwards when it lives under _logs/agent-py/.

    python3 tools/run_agent_py.py --script _logs/agent-py/patch.py
    python3 tools/run_agent_py.py --script tools/x.py --keep-script
Checked-in scripts are never deleted; --cleanup outside _logs/agent-py/ is refused.
Prefer a real tool (see design/tools.md) over a scratch. Summary: _logs/agent-py/<stamp>-agent-py.txt
Old spellings: -Script -KeepScript -Cleanup.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Run an agent python script and clean up its ephemeral copy.")
    ap.add_argument("--script", "-Script", required=True, help="Python source file to run as an agent script.")
    ap.add_argument("--keep-script", "-KeepScript", action="store_true", help="Keep the script after the run.")
    ap.add_argument("--cleanup", "-Cleanup", action="store_true", help="Delete the script after the run (only scripts under _logs/agent-py/).")
    ap.add_argument("script_args", nargs="*", help="Arguments passed to the script.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    out_dir = agent_log.ensure_agent_log_dir("agent-py", root)
    path = Path(args.script)
    path = (path if path.is_absolute() else root / path).resolve()
    if not path.is_file():
        agent_log.fail(f"script not found: {path}")
    under = out_dir.resolve() in path.parents
    if args.cleanup and not under and not args.keep_script:
        agent_log.fail(f"refusing --cleanup for a script outside _logs/agent-py/: {path}")
    do_clean = under and not args.keep_script
    p = subprocess.run([sys.executable, str(path), *args.script_args], cwd=root, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    text = (p.stdout + p.stderr).rstrip()
    if len(text) > 4000:
        text = text[:4000] + "\n...[truncated]"
    cleaned = False
    if do_clean:
        try:
            path.unlink()
            cleaned = True
        except OSError as e:
            text += f"\ncleanup_error={e}"
    body = [f"script={agent_log.rel(root, path)}", f"under_agent_py={under} cleanup={do_clean} keep={args.keep_script}", "",
            "----- stdout/stderr -----", text, "----- end -----"]
    rc = agent_log.finish("agent-py", root, "\n".join(body), "PASS" if p.returncode == 0 else "FAIL", args=args,
                          exit=p.returncode, cleaned=cleaned)
    return p.returncode or rc


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
