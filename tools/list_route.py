#!/usr/bin/env python3
"""Print one routes.yaml door or job card. Do not dump the graph."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import agent_log

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from load_routes import job_index, job_read_when, load_routes


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def _gate_lines(data: dict) -> list[str]:
    lines = []
    gates = data.get("gates")
    if not isinstance(gates, dict):
        return lines
    for name, spec in gates.items():
        if not isinstance(spec, dict):
            continue
        path = spec.get("file") or ""
        when = spec.get("when") or ""
        lines.append("gate\t%s\t%s\twhen=%s" % (name, path, when))
    return lines


def _door_card(data: dict, door_name: str) -> list[str]:
    doors = data.get("doors")
    if not isinstance(doors, dict) or door_name not in doors:
        names = ", ".join(sorted(doors.keys())) if isinstance(doors, dict) else ""
        raise SystemExit("unknown door %s. doors: %s" % (door_name, names))
    spec = doors[door_name]
    if not isinstance(spec, dict):
        raise SystemExit("bad door %s" % door_name)
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
    lines.append("note\topen one job sibling only; gates only if when matches")
    return lines


def _job_card(data: dict, job_id: str) -> list[str]:
    idx = job_index(data)["by_id"]
    if job_id not in idx:
        if "." not in job_id:
            raise SystemExit("use --job door.job (example: debug.smokes)")
        names = ", ".join(sorted(idx.keys()))
        raise SystemExit("unknown job %s. jobs: %s" % (job_id, names))
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
    lines.append("note\topen this job sibling only; gates only if when matches")
    return lines


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print one door or job card from design/routes.yaml."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--door", default="")
    parser.add_argument("--job", default="")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not args.door and not args.job:
        print("usage: python tools/list_route.py --door dungeon")
        print("       python tools/list_route.py --job debug.smokes")
        return 2
    root = Path(args.root).expanduser().resolve()
    data = load_routes(root)
    if args.job:
        lines = _job_card(data, args.job.strip())
    else:
        lines = _door_card(data, args.door.strip())
    body = "\n".join(lines) + "\n"
    out = agent_log.ensure_agent_log_dir("route", ROOT) / "summary.txt"
    _write(out, body)
    print(body, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())