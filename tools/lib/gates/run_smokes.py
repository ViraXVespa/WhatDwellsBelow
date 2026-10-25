#!/usr/bin/env python3
"""Phase smoke runner (Windows/any host). Per-path Godot lock; never kills godot*.

    python tools/gate.py smokes [--phases 1,2,3 | --door D | --job door.job] [--timeout-sec 120] [--verbose-godot]
--door / --job pick the phases mapped in routes.yaml `smokes` (Build prove). Neither: all nine.
CamelCase spellings work too: -Phases 4,5 -TimeoutSec 60 -VerboseGodot.
Summary: _logs/smokes/<stamp>-smokes.txt. Bot VM: use gate.py bot-smokes instead.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib
from load_routes import SMOKE_PHASES, check_route, load_routes, smoke_phases

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Run Godot phase smokes (--wdb-phaseN-smoke).", json_out=True)
    ap.add_argument("--phases", nargs="+", default=[",".join(map(str, SMOKE_PHASES))], help="Phase numbers, 1,2,6 or 1 2 6.")
    ap.add_argument("--door", default="", help="Run the phases mapped to this routes.yaml door.")
    ap.add_argument("--job", default="", help="Run the phases mapped to this routes.yaml door.job.")
    ap.add_argument("--timeout-sec", type=int, default=120, help="Seconds per smoke phase (default 120).")
    ap.add_argument("--no-gaps", action="store_true", help="skip the mid-slice check_shot_gaps --changed print (the END gate is gate.py build, required per routes.yaml)")
    ap.add_argument("--verbose-godot", action="store_true", help="Pass --verbose to Godot (leak detail rows).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    phases = agent_log.split_list(args.phases, int)
    bad = [n for n in phases if n not in SMOKE_PHASES]
    if bad:
        agent_log.fail(f"bad phase {bad[0]} in --phases. Valid phases are {SMOKE_PHASES[0]}-{SMOKE_PHASES[-1]} (example: --phases 1,2,6)")
    if args.door or args.job:
        bad_route = check_route(load_routes(root), args.door, args.job)
        if bad_route:
            agent_log.fail(bad_route)
        phases = smoke_phases(load_routes(root), door=args.door.strip(), job=args.job.strip())
    body = [f"root=. phases={','.join(map(str, phases))} timeoutSec={args.timeout_sec}", ""]
    fail = 0
    for n in phases:
        se, so = agent_log.run_path("smokes", root, f"p{n}-err.log"), agent_log.run_path("smokes", root, f"p{n}-out.log")
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
    if not args.no_gaps:
        from load_routes import shot_gaps_mode
        if shot_gaps_mode(load_routes(root), "build") != "off":
            adv = subprocess.run([*boot.cmd("check_shot_gaps"),
                                  "--changed", "--advisory", "--root", str(root)], check=False)
            body += [f"--- shot gaps advisory exit={adv.returncode} (mid-slice print; the END gate gate.py build is required) ---", ""]
    return agent_log.finish("smokes", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, retry=(f"gate.py smokes phases {','.join(map(str, phases))}", body), fail_signals=fail)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
