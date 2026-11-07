"""Shared, unchanged benchmark report assembly and summary output."""
from __future__ import annotations

from pathlib import Path

import agent_log
import bench_env
import godot_lib


def report_lines(title: str, path: str, hub) -> list[str]:
    ordered = hub._read_rows(path)
    bench = None
    for item in ordered:
        if item.get("ev") == "bench":
            bench = item
    hitch_rows = [item for item in ordered if item.get("ev") == "hitch"]
    ranked = sorted(hitch_rows, key=lambda row: float(row.get("dt_ms", 0) or 0), reverse=True)
    report = [title, "path=%s" % path, hub._present_line(bench), "", "--- HB lines ---"]
    report += hub._hb_lines(ordered) or ["(no HB: lines)"]
    report += ["", "--- slow shape ---"] + hub._shape_lines(hitch_rows, bench)
    report += ["", "--- slowest hitches ---"] + (hub._slow_lines(ranked) or ["(none)"])
    return report


def begin_run(job: str, title: str, root: Path, args):
    out_log = agent_log.run_path(job, root, "out.log")
    err_log = agent_log.run_path(job, root, "err.log")
    body = [title + " root=.", "leg=%s" % args.leg]
    body.append(bench_env.env_line(
        godot=bench_env.godot_version(str(godot_lib.godot_exe())),
        renderer="gl_compatibility",
        browser="see web leg" if args.leg in ("both", "web") else "n/a",
        vsync="see present line", cap="max_fps 120", headless=bool(args.headless),
    ))
    return out_log, err_log, body


def finish_run(job: str, root: Path, args, body: list[str], fail: int, hub) -> int:
    echo = hub._echo_lines(body)
    summary_dir = root / "_logs" / job
    summary_dir.mkdir(parents=True, exist_ok=True)
    (summary_dir / "summary.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
    return agent_log.finish(job, root, "\n".join(body), "FAIL" if fail else "PASS",
        args=args, legacy=False, echo="\n".join(echo), retry=(job, hub._retry_lines(body)), fail_signals=fail)


def selftest() -> int:
    from types import SimpleNamespace
    rows = [{"ev": "bench", "n": 1}, {"ev": "hitch", "dt_ms": 9},
            {"ev": "hitch", "dt_ms": 20}, {"ev": "bench", "n": 2}]
    hub = SimpleNamespace(_read_rows=lambda path: rows, _present_line=lambda row: "bench=" + str(row["n"]),
        _hb_lines=lambda ordered: [], _shape_lines=lambda hitches, bench: ["shape=" + str(len(hitches))],
        _slow_lines=lambda ranked: [str(row["dt_ms"]) for row in ranked])
    result = report_lines("title", "fixture", hub)
    bad = [] if result == ["title", "path=fixture", "bench=2", "", "--- HB lines ---", "(no HB: lines)",
                         "", "--- slow shape ---", "shape=2", "", "--- slowest hitches ---", "20", "9"] else ["report ordering/latest bench"]
    return agent_log.selftest_result(bad)
