#!/usr/bin/env python3
"""One fresh-save dungeon playtest, about 30 s of acting. Same window rules as the hub bench.

    python tools/perf.py dungeon [--leg both|desktop|web] [--timeout-sec 360]
Desktop: a gl_compatibility window, vsync off, max_fps 120, empty AppData.
Web: a new export in a visible fullscreen Edge window (Chrome if Edge is not installed).
Frames count only while the dungeon is showing and the loader bar is down.
--headless on the desktop leg is not an FPS reading.
Summary: _logs/dungeon-bench/<stamp>-dungeon-bench.txt.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import agent_log  # noqa: E402
import bench_env  # noqa: E402
import godot_lib  # noqa: E402
import run_hub_bench  # noqa: E402

FLAG = "--wdb-dungeon-bench"
EXTRA = ["--wdb-seed=42", "--wdb-pt-sec=30"]
QUERY = "&wdb-seed=42&wdb-pt-sec=30"
JOB = "dungeon-bench"


def _report(root: Path, args) -> int:
    if not Path(args.report).is_file():
        msg = "error: --report file not found: %s" % args.report
        return agent_log.finish(JOB + "-report", root, msg, "FAIL", args=args, legacy=False, echo=msg)
    ordered = run_hub_bench._read_rows(args.report)
    bench = None
    for item in ordered:
        if item.get("ev") == "bench":
            bench = item
    hitch_rows = [item for item in ordered if item.get("ev") == "hitch"]
    ranked = sorted(hitch_rows, key=lambda row: float(row.get("dt_ms", 0) or 0), reverse=True)
    report = [
        "dungeon bench report",
        "path=%s" % args.report,
        run_hub_bench._present_line(bench),
        "",
        "--- HB lines ---",
    ]
    report += run_hub_bench._hb_lines(ordered) or ["(no HB: lines)"]
    report += ["", "--- slow shape ---"] + run_hub_bench._shape_lines(hitch_rows, bench)
    report += ["", "--- slowest hitches ---"] + (run_hub_bench._slow_lines(ranked) or ["(none)"])
    return agent_log.finish(
        JOB + "-report",
        root,
        "\n".join(report),
        "PASS",
        args=args,
        legacy=False,
        echo="\n".join(report),
        fail_signals=0,
    )


def _layers_line(lines: list[str]) -> str:
    """First unhidden window. keep=1 only when its submit stays near 35 ms."""
    fields = run_hub_bench._layer_fields(lines)
    base = None
    for kind, submit, count in fields:
        if kind == "base" and base is None:
            base = (submit, count)
    keep = 0
    if base is not None and 30.0 <= base[0] <= 45.0 and base[1] >= 20:
        keep = 1
    shown = "missing" if base is None else "%.1f" % base[0]
    return "layers base=%s keep=%d" % (shown, keep)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "One ~30s fresh dungeon playtest (desktop window and a visible web export), plus a hitch summary.",
        json_out=True,
    )
    ap.add_argument("--timeout-sec", type=int, default=360, help="Desktop Godot timeout, and the web wait after export (default 360).")
    ap.add_argument("--headless", action="store_true", help="desktop driver only; not an FPS reading")
    ap.add_argument("--leg", choices=("both", "desktop", "web"), default="both", help="Which runs to launch (default both).")
    ap.add_argument("--browser", default="", help="Force the web window binary. Default: Edge if installed, else Chrome.")
    ap.add_argument("--report", default="", help="Reprint slow shape and HB lines from a hitch JSONL. Does not launch a run.")
    ap.add_argument("--walk-layers", action="store_true", help="Web only: during play, time each hidden group, then noenv, linear, rest, and empty. empty1 and empty05 repeat empty with scaling_3d_scale pinned at 1.0 and 0.5. Does not score the 99 percent bar. Keep the reading only when the unhidden submit stays near 35 ms.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.report:
        return _report(root, args)
    out_log = agent_log.run_path(JOB, root, "out.log")
    err_log = agent_log.run_path(JOB, root, "err.log")
    fail = 0
    body = ["dungeon bench root=.", "leg=%s" % args.leg]
    body.append(bench_env.env_line(
        godot=bench_env.godot_version(str(godot_lib.godot_exe())),
        renderer="gl_compatibility",
        browser="see web leg" if args.leg in ("both", "web") else "n/a",
        vsync="see present line",
        cap="max_fps 120",
        headless=bool(args.headless),
    ))
    if args.leg in ("both", "desktop") and not args.walk_layers:
        d_fail, d_body = run_hub_bench._desktop(
            root, args, out_log, err_log,
            flag=FLAG, fresh_name="dungeon-bench-fresh", label="dungeon bench", extra=EXTRA,
        )
        fail += d_fail
        body += d_body
    if args.leg in ("both", "web") or args.walk_layers:
        layer_query = ""
        extra_query = QUERY
        if args.walk_layers:
            # Windows after bare, including the two scale pins, need the dungeon past the scored 30 s.
            layer_query = "&wdb-dungeon-walk-layers"
            extra_query = "&wdb-seed=42&wdb-pt-sec=50"
        w_fail, w_body = run_hub_bench._web(
            root, args,
            flag=FLAG, site_prefix="dungeon-bench-web", profile_name="dungeon-bench-browser",
            label="dungeon bench", extra_query=extra_query, layer_query=layer_query,
        )
        if args.walk_layers:
            w_body.append(_layers_line(w_body))
        fail += w_fail
        body += w_body
    echo = run_hub_bench._echo_lines(body)
    summary_dir = root / "_logs" / JOB
    summary_dir.mkdir(parents=True, exist_ok=True)
    (summary_dir / "summary.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
    return agent_log.finish(
        JOB,
        root,
        "\n".join(body),
        "FAIL" if fail else "PASS",
        args=args,
        legacy=False,
        echo="\n".join(echo),
        retry=(JOB, run_hub_bench._retry_lines(body)),
        fail_signals=fail,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
