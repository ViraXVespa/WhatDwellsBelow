#!/usr/bin/env python3
"""Phase smoke runner (Windows/any host). Per-path Godot lock; never kills godot*.

    python3 tools/run_smokes.py [--phases 1,2,3] [--timeout-sec 120] [--verbose-godot]
Old PowerShell spellings work: -Phases 4,5 -TimeoutSec 60 -VerboseGodot.
Summary: _logs/smokes/summary.txt. Bot VM: use bot_smokes.py instead.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Run Godot phase smokes (--wdb-phaseN-smoke).", json_out=True)
    ap.add_argument("--phases", "-Phases", nargs="+", default=["1,2,3,4,5,6,7,8,9"], help="Phase numbers, 1,2,6 or 1 2 6.")
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=120)
    ap.add_argument("--verbose-godot", "-VerboseGodot", action="store_true")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    phases = agent_log.split_list(args.phases, int)
    d = agent_log.ensure_agent_log_dir("smokes", root)
    for f in d.glob("p*-*.log"):
        m = re.match(r"p(\d+)-(err|out)\.log$", f.name)
        if m and int(m.group(1)) not in phases:
            f.unlink()
    body = [f"root=. phases={','.join(map(str, phases))} timeoutSec={args.timeout_sec}", ""]
    fail = 0
    for n in phases:
        se, so = d / f"p{n}-err.log", d / f"p{n}-out.log"
        ga = godot_lib.headless_args(root)
        if args.verbose_godot:
            ga.append("--verbose")
        ga += ["--", f"--wdb-phase{n}-smoke"]
        print(f"Running phase {n}...")
        r = godot_lib.run_godot(root, root, ga, so, se, args.timeout_sec)
        if r["timed_out"] or r["exit_code"] != 0:
            fail += 1
        head = f"p{n} {r['status']} ms={r['ms']} errBytes={r['err_bytes']}"
        print(head)
        hits = godot_lib.grep_logs([se, so], r"^P\d:|SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to")
        body += [head, "--- highlights ---"] + (hits[:80] or ["(no P*/SCRIPT ERROR highlights - check logs if TIMEOUT)"]) + [""]
        if r["status"] != "TIMEOUT" and any(re.search(r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to", h) for h in hits):
            fail += 1
    return agent_log.finish("smokes", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, fail_signals=fail)


if __name__ == "__main__":
    raise SystemExit(main())
