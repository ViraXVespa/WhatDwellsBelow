#!/usr/bin/env python3
"""Shot-gap check: which UI states (menus, NPC panels, pages) have no shot flow, and are flows/published shots healthy.

  python3 tools/check_shot_gaps.py [--changed [REF]] [--advisory] [--strict] [--json]

States come from tools/shot-flows/states.json (regexes over the UI/interact sources; add a source for a new
menu). A flow covers a state when it lists it in `covers`, or derives it (an `interact` op for kind K covers
interact:K; an assert on host.ui.mode equals M covers ui:M). Reports:
  gap       a state no flow covers (INFO; FAIL with --strict). Ignored states are listed in states.json `ignore`.
  new       with --changed [REF] (default origin/main): states that exist now but not at REF; uncovered ones FAIL.
  problem   a flow with no shot or no assert, a covers entry naming no state, a publish manifest that is
            missing files or stale (file sha differs from shots.json).
RESULT PASS = no gaps or problems, INFO = gaps only, FAIL = problems, uncovered new states, or gaps under --strict.
Gate mode (routes.yaml shot_gaps): Bot = required (bot_smokes.py, run_build_gate.py --batch call it with --changed and
FAIL on a new gap); Build = advisory (run_smokes.py, plain run_build_gate.py pass --advisory: prints, status INFO, exit 0).
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import run_shot_flow
from agent_log import rel

CFG = "tools/shot-flows/states.json"


def _text_at(root: Path, ref: str, path: str) -> str:
    if not ref:
        p = root / path
        return p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
    r = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=root, capture_output=True, text=True, errors="replace")
    return r.stdout if r.returncode == 0 else ""


def _files_at(root: Path, ref: str, glob: str) -> list[str]:
    if not ref:
        return sorted(rel(root, p) for p in root.glob(glob) if p.is_file())
    r = subprocess.run(["git", "ls-tree", "-r", "--name-only", ref], cwd=root, capture_output=True, text=True)
    pat = re.compile("^" + re.escape(glob).replace(r"\*", "[^/]*") + "$")
    return sorted(f for f in r.stdout.splitlines() if pat.match(f))


def find_states(root: Path, cfg: dict, ref: str = "") -> dict[str, str]:
    """state id -> source file, from the working tree (ref='') or from a git ref."""
    out: dict[str, str] = {}
    for src in cfg.get("sources", []):
        rx = re.compile(src["regex"])
        for f in _files_at(root, ref, src["glob"]):
            for m in rx.finditer(_text_at(root, ref, f)):
                out.setdefault(str(src.get("prefix", "")) + m.group(1), f)
    return out


def derived_cover(steps: list) -> set[str]:
    cov: set[str] = set()
    for s in steps:
        if not isinstance(s, dict):
            continue
        if s.get("op") == "interact" and s.get("kind"):
            cov.add("interact:" + str(s["kind"]))
        if s.get("op") == "assert" and str(s.get("target", "")).endswith("ui.mode") and "equals" in s:
            cov.add("ui:" + str(s["equals"]))
        cov |= derived_cover(s.get("steps", []))
    return cov


def count_ops(steps: list, op: str) -> int:
    return sum((1 if isinstance(s, dict) and s.get("op") == op else 0) + (count_ops(s.get("steps", []), op) if isinstance(s, dict) else 0)
               for s in steps)


def flow_problems(root: Path, name: str, flow: dict, states: dict) -> list[str]:
    probs = []
    steps = flow.get("steps", [])
    if count_ops(steps, "shot") == 0:
        probs.append(f"{name}: no shot step")
    if count_ops(steps, "assert") + count_ops(steps, "assert_texts") == 0:
        probs.append(f"{name}: no assert (a shot of the wrong state would pass)")
    for c in flow.get("covers", []):
        if c not in states:
            probs.append(f"{name}: covers {c} but no such state in the sources")
    pub = flow.get("publish") or {}
    if pub.get("dir") and run_shot_flow.publish_blocked(root, root / pub["dir"]):
        probs.append(f"{name}: publish.dir {pub['dir']} is under assets/ (tooling never publishes there; use _out/shots/{name})")
    elif pub.get("dir"):
        d = root / pub["dir"]
        man = d / (str(pub.get("prefix", "")) + "shots.json")
        if not man.is_file():
            probs.append(f"{name}: publish.dir {pub['dir']} has no shots.json (run run_shot_flow.py --flow {name} --publish)")
        else:
            for row in json.loads(man.read_text(encoding="utf-8")).get("frames", []):
                f = d / row["file"]
                if not f.is_file():
                    probs.append(f"{name}: published {row['file']} missing")
                elif hashlib.sha256(f.read_bytes()).hexdigest() != row["sha256"]:
                    probs.append(f"{name}: published {row['file']} differs from shots.json (edited by hand?)")
    return probs


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Report UI states with no shot flow, new states in this diff, and flow/published-shot problems.",
                             json_out=True)
    p.add_argument("--changed", nargs="?", const="origin/main", default=None, metavar="REF",
                   help="also list states new since REF (default origin/main); uncovered ones FAIL")
    p.add_argument("--advisory", action="store_true",
                   help="print everything but never FAIL (Build gate); the Bot gate runs without it")
    p.add_argument("--strict", action="store_true", help="FAIL on any uncovered state, not just new ones")
    args = p.parse_args(argv)
    root = agent_log.resolve_root(args)
    cfg = json.loads((root / CFG).read_text(encoding="utf-8"))
    ignore = cfg.get("ignore", {})
    states = find_states(root, cfg)
    flows = run_shot_flow.list_flows(root)
    covered: dict[str, list[str]] = {}
    problems: list[str] = []
    for n, f in flows.items():
        for c in set(f.get("covers", [])) | derived_cover(f.get("steps", [])):
            covered.setdefault(c, []).append(n)
        problems += flow_problems(root, n, f, states)
    gaps = sorted(s for s in states if s not in covered and s not in ignore)
    new: list[str] = []
    if args.changed is not None:
        base = find_states(root, cfg, args.changed)
        new = sorted(s for s in states if s not in base)
    new_gaps = [s for s in new if s in gaps]
    lines = [f"shot-gaps root=. states={len(states)} covered={len(states) - len(gaps) - sum(1 for s in states if s in ignore and s not in covered)} "
             f"ignored={sum(1 for s in states if s in ignore)} flows={len(flows)}"]
    lines += [f"gap      {s}  ({states[s]})" for s in gaps]
    lines += [f"new      {s}  covered={'no' if s in gaps else 'yes'}" for s in new]
    lines += [f"problem  {x}" for x in problems]
    status = "PASS"
    if gaps:
        status = "INFO"
    if problems or new_gaps or (args.strict and gaps):
        status = "INFO" if args.advisory else "FAIL"
        if args.advisory:
            lines.append("advisory: new gaps / problems above do not fail this gate (Build); Bot gate requires them fixed")
    out_dir = agent_log.ensure_agent_log_dir("shot-gaps", root)
    summary = out_dir / "summary.txt"
    res = agent_log.result_line(status, rel(root, summary), states=len(states), gaps=len(gaps), new_gaps=len(new_gaps),
                                problems=len(problems), flows=len(flows))
    summary.write_text("\n".join(lines + [res]) + "\n", encoding="utf-8")
    if args.json:
        agent_log.print_json({"status": status, "states": states, "gaps": gaps, "new": new, "problems": problems,
                              "covered": covered})
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
