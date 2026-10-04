#!/usr/bin/env python3
"""Print one routes.yaml door or job card. Do not dump the graph.

    python tools/list_route.py --door ui          # door card + what to read: the one job doc that matches, others only on their trigger
    python tools/list_route.py --job ui.pause     # job card + read list
    python tools/list_route.py --digest --door ui # several jobs (a survey): each doc's Status / Read when and its headings with line numbers;
                                                  # open a section by line range after choosing, not the whole sibling
"""

from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from load_routes import job_index, job_read_when, load_routes, shot_flows, smoke_phases


FULL_GATES = False  # set by --gates


def _ascii(text: str) -> str:
    for a, b in (("\u2014", "-"), ("\u2013", "-"), ("\u2192", "->"), ("\u2019", "'"), ("\u201c", '"'), ("\u201d", '"'), ("\u00d7", "x")):
        text = text.replace(a, b)
    return text.encode("ascii", "replace").decode("ascii")


def _digest(root: Path, rel_path: str) -> list[str]:
    """Status, Read when and the headings (with line numbers, code fences skipped) of one doc."""
    f = root / rel_path
    if not f.is_file():
        return [f"{rel_path}\t(missing)"]
    out, fence = [f"{rel_path}"], False
    for n, line in enumerate(f.read_text(encoding="utf-8-sig").splitlines(), 1):
        if line.startswith("```"):
            fence = not fence
        elif not fence and (line.startswith("#") or line.startswith(("Status:", "Read when:"))):
            out.append(f"  L{n}\t{_ascii(line.strip())[:110]}")
    return out


def _digest_lines(root: Path, data: dict, door: str, job: str) -> list[str]:
    doors = data.get("doors") if isinstance(data.get("doors"), dict) else {}
    spec = doors.get(door) if isinstance(doors, dict) else None
    if not isinstance(spec, dict):
        return []
    files = [str(spec.get("file") or "")]
    jobs = spec.get("jobs") if isinstance(spec.get("jobs"), dict) else {}
    files += [str(p) for k, p in jobs.items() if isinstance(p, str) and (not job or f"{door}.{k}" == job)]
    lines: list[str] = []
    for rel_path in [f for f in files if f]:
        lines += _digest(root, rel_path)
    return lines


def _gate_lines(data: dict) -> list[str]:
    gates = data.get("gates")
    if not isinstance(gates, dict):
        return []
    parts = []
    for spec in gates.values():
        if isinstance(spec, dict):
            stem = str(spec.get("file") or "").removeprefix("design/").removesuffix(".md")
            parts.append("%s=%s" % (stem, spec.get("when") or "") if FULL_GATES else stem)
    if not parts:
        return []
    if FULL_GATES:
        return ["gates\tdesign/<name>.md, open only when its when matches: " + " ".join(parts)]
    return [f"gates\t{len(parts)} gate docs, open one only when its trigger applies; `list_route.py --gates` lists names and triggers"]


def _door_card(data: dict, door_name: str) -> list[str]:
    doors = data.get("doors")
    if not isinstance(doors, dict) or door_name not in doors:
        names = ", ".join(sorted(doors.keys())) if isinstance(doors, dict) else ""
        agent_log.fail("unknown door %s. No door = a new or undocumented system: plan it and ask the User via ask_user_question, never guess. doors: %s" % (door_name, names))
    spec = doors[door_name]
    if not isinstance(spec, dict):
        agent_log.fail("bad door %s" % door_name)
    path = spec.get("file") or ""
    when = spec.get("read_when") or ""
    lines = [
        "door\t%s\t%s" % (door_name, path),
        "read_when\t%s" % when,
    ]
    jobs = spec.get("jobs") or {}
    if isinstance(jobs, dict) and jobs:
        when_map = job_read_when(data)
        for job_name, job_path in jobs.items():
            jid = "%s.%s" % (door_name, job_name)
            target = job_path if isinstance(job_path, str) else ""
            lines.append(
                "job\t%s\t%s\tread_when=%s" % (jid, target, when_map.get(jid, ""))
            )
    else:
        lines.append("job\t(none)")
    lines.extend(_gate_lines(data))
    lines.append("smokes\t%s" % ",".join(map(str, smoke_phases(data, door=door_name))))
    lines.append("flows\t%s" % (",".join(shot_flows(data, door=door_name)) or "none"))
    lines.append("read\topen the one job doc whose read_when matches the task; not its siblings")
    lines.append("survey\tseveral jobs: `python tools/list_route.py --digest --door %s` (headings with line numbers), then open only the sections you choose" % door_name)
    lines.append("also\tgates only if their trigger applies; `code_map.py row` / `show_func.py` for scripts, not whole files")
    return lines


def _job_card(data: dict, job_id: str) -> list[str]:
    idx = job_index(data)["by_id"]
    if job_id not in idx:
        if "." not in job_id:
            agent_log.fail("use --job door.job (example: debug.smokes)")
        names = ", ".join(sorted(idx.keys()))
        agent_log.fail("unknown job %s. No job = a new or undocumented area: plan it and ask the User via ask_user_question, never guess. jobs: %s" % (job_id, names))
    door_name = job_id.split(".", 1)[0]
    doors = data.get("doors") if isinstance(data.get("doors"), dict) else {}
    door_spec = doors.get(door_name) if isinstance(doors, dict) else {}
    door_file = ""
    if isinstance(door_spec, dict):
        door_file = str(door_spec.get("file") or "")
    when_map = job_read_when(data)
    lines = [
        "door\t%s\t%s" % (door_name, door_file),
        "job\t%s\t%s\tread_when=%s"
        % (job_id, idx[job_id], when_map.get(job_id, "")),
    ]
    lines.extend(_gate_lines(data))
    lines.append("smokes\t%s" % ",".join(map(str, smoke_phases(data, door=door_name, job=job_id))))
    lines.append("flows\t%s" % (",".join(shot_flows(data, door=door_name, job=job_id, job_only=True)) or "none"))
    sibs = [k for k in ((doors.get(door_name) or {}).get("jobs") or {}) if "%s.%s" % (door_name, k) != job_id] if isinstance(doors, dict) else []
    lines.append("read\t%s now (this job's doc)" % idx[job_id])
    lines.append("also\t%s only if the job doc points to it%s" % (door_file or "(no door doc)", "; another %s job (%s) only if the task names its read_when" % (door_name, ", ".join(sibs)) if sibs else ""))
    lines.append("also\tgates only if their trigger applies; `code_map.py row` / `show_func.py` for scripts, not whole files")
    return lines


def parse_args(argv: list[str]):
    parser = agent_log.std_parser("Print one door or job card from design/routes.yaml (no argument: list the doors).")
    parser.add_argument("target", nargs="?", default="", help="Door name, or door.job for a job card (same as --door / --job).")
    parser.add_argument("--door", "-Door", default="", help="Door name (print its card).")
    parser.add_argument("--job", "-Job", default="", help="Job id door.job (print its card).")
    parser.add_argument("--digest", action="store_true", help="With --door / --job: each doc's Status, Read when and headings with line numbers (for a survey over several jobs).")
    parser.add_argument("--gates", action="store_true", help="Print the full gate triggers (default: gate names only).")
    args = parser.parse_args(argv)
    global FULL_GATES
    FULL_GATES = args.gates
    if args.target and not (args.door or args.job):
        if "." in args.target:
            args.job = args.target
        else:
            args.door = args.target
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    data = load_routes(root)
    if not args.door and not args.job:
        doors = data.get("doors") if isinstance(data.get("doors"), dict) else {}
        menu = "\n".join("door\t%s\t%s" % (n, (s or {}).get("read_when", "")) for n, s in doors.items())
        menu += "\nnext\tpass a door name, or door.job for a job card (example: debug.smokes)"
        return agent_log.finish("route", root, menu, "INFO", args=args, legacy=False, doors=len(doors))
    if args.digest:
        door = args.door.strip() or args.job.split(".", 1)[0]
        lines = _digest_lines(root, data, door, args.job.strip())
        if not lines:
            agent_log.fail("--digest needs a known --door or --job")
        return agent_log.finish("route", root, "\n".join(lines), "PASS", args=args, legacy=False, door=door, cards=len(lines))
    if args.job:
        lines = _job_card(data, args.job.strip())
    else:
        lines = _door_card(data, args.door.strip())
    return agent_log.finish("route", root, "\n".join(lines), "PASS", args=args, legacy=False,
                            door=args.door or args.job.split(".", 1)[0], cards=len(lines))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
