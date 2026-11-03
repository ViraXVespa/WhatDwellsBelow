#!/usr/bin/env python3
"""One continuous sweep: hub walk, dungeon, dispel, hub walk, dungeon, quit.

    python tools/perf.py sweep [--leg desktop|web|both] [--timeout-sec 960]
Desktop: a gl_compatibility window, vsync off, max_fps 120, empty AppData.
Web: a new export in a visible fullscreen Edge window (Chrome if Edge is not installed).
Frames count while the hub or the dungeon is showing and the loader bar is down.
HB: seg= lines are each stretch. The last fps_pct is the whole run.
Each of hub1, dungeon1, hub2, and dungeon2 must be at least 99 (cold hub,
cold dungeon, warm hub, warm dungeon). pair lines compare warm minus cold.
--headless on the desktop leg is not an FPS reading.
Summary: _logs/perf-sweep/<stamp>-perf-sweep.txt.
Two cold web passes are two separate --leg web runs.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import agent_log  # noqa: E402
import bench_env  # noqa: E402
import godot_lib  # noqa: E402
import run_hub_bench  # noqa: E402

FLAG = "--wdb-perf-sweep"
EXTRA = ["--wdb-seed=42", "--wdb-pt-sec=30"]
QUERY = "&wdb-seed=42&wdb-pt-sec=30"
JOB = "perf-sweep"

# Cold is the first visit. Warm is the visit after dispel.
_PLACES = (
    ("cold_hub", "hub1"),
    ("cold_dungeon", "dungeon1"),
    ("warm_hub", "hub2"),
    ("warm_dungeon", "dungeon2"),
)
_PAIR_KEYS = ("dt_ms", "submit_ms", "tree_ms", "lit_ms", "geo_ms")
# Present only when the sweep stamped the pass. Older hitch files omit them.
_DRAW_KEYS = (
    "draw_3d", "prim_3d", "obj_3d",
    "draw_shadow", "prim_shadow", "obj_shadow",
    "draw_canvas", "prim_canvas", "obj_canvas",
)


def _seg_fps(lines: list[str]) -> dict:
    found: dict = {}
    for ln in lines:
        name = run_hub_bench._field(ln, "seg")
        if name not in ("hub1", "dungeon1", "hub2", "dungeon2"):
            continue
        try:
            found[name] = {
                "frames": int(float(run_hub_bench._field(ln, "frames") or 0)),
                "slow": int(float(run_hub_bench._field(ln, "slow") or 0)),
                "fps_pct": float(run_hub_bench._field(ln, "fps_pct") or 0),
            }
        except ValueError:
            continue
    return found


def _slow_by_seg(rows: list) -> dict:
    grouped: dict = {}
    for row in rows:
        if row.get("ev") != "hitch":
            continue
        if int(row.get("paused", 0) or 0) == 1 or int(row.get("bar", 0) or 0) == 1:
            continue
        seg = str(row.get("seg", "") or "")
        if not seg:
            continue
        grouped.setdefault(seg, []).append(row)
    return grouped


def _med_key(rows: list, key: str) -> str:
    vals = []
    for row in rows:
        if key not in row:
            continue
        try:
            vals.append(float(row.get(key) or 0))
        except (TypeError, ValueError):
            continue
    if not vals:
        return "-"
    return "%.1f" % run_hub_bench._median(vals)


def _pair_line(label: str, cold: str, warm: str, stats: dict, grouped: dict) -> str:
    left = stats.get(cold)
    right = stats.get(warm)

    def fps(row: dict | None) -> str:
        if not row:
            return "missing"
        return "%.1f" % row["fps_pct"]

    dfps = "na"
    if left and right:
        dfps = "%+.1f" % (right["fps_pct"] - left["fps_pct"])
    cold_rows = grouped.get(cold, [])
    warm_rows = grouped.get(warm, [])
    bits = [
        "pair %s" % label,
        "fps=%s->%s" % (fps(left), fps(right)),
        "dfps=%s" % dfps,
        "hitch_rows=%d->%d" % (len(cold_rows), len(warm_rows)),
    ]
    for key in _PAIR_KEYS:
        short = key[:-3] if key.endswith("_ms") else key
        bits.append("%s_med=%s->%s" % (short, _med_key(cold_rows, key), _med_key(warm_rows, key)))
    have_draw = False
    for key in _DRAW_KEYS:
        if any(key in row for row in cold_rows) or any(key in row for row in warm_rows):
            have_draw = True
            break
    if have_draw:
        for key in _DRAW_KEYS:
            bits.append("%s_med=%s->%s" % (key, _med_key(cold_rows, key), _med_key(warm_rows, key)))
    return " ".join(bits)


def _place_block(lines: list[str], hitch_path: Path | None) -> tuple[int, list[str]]:
    """Four place bars plus a cold-to-warm pair. A missing place fails."""
    stats = _seg_fps(lines)
    grouped: dict = {}
    if hitch_path is not None and hitch_path.is_file():
        grouped = _slow_by_seg(run_hub_bench._read_rows(str(hitch_path)))
    fail = 0
    out = ["", "--- places ---"]
    for label, seg in _PLACES:
        row = stats.get(seg)
        if row is None:
            fail += 1
            out.append("place %s=%s frames=0 slow=0 fps_pct=missing bar=99 fail=1" % (label, seg))
            continue
        bad = run_hub_bench._fps_fail(row["fps_pct"], row["frames"])
        fail += bad
        out.append(
            "place %s=%s frames=%d slow=%d fps_pct=%.1f bar=99 fail=%d"
            % (label, seg, row["frames"], row["slow"], row["fps_pct"], bad)
        )
    out.append(_pair_line("hub", "hub1", "hub2", stats, grouped))
    out.append(_pair_line("dungeon", "dungeon1", "dungeon2", stats, grouped))
    if hitch_path is None or not hitch_path.is_file():
        out.append("pair_rows=(no hitch file)")
    elif not any(grouped.get(seg) for _label, seg in _PLACES):
        out.append("pair_rows=seg missing on hitch rows")
    return fail, out


def _hitch_file(lines: list[str]) -> Path | None:
    for ln in lines:
        raw = run_hub_bench._field(ln, "path")
        if raw and Path(raw).is_file():
            return Path(raw)
    return None


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
        "perf sweep report",
        "path=%s" % args.report,
        run_hub_bench._present_line(bench),
        "",
        "--- HB lines ---",
    ]
    report += run_hub_bench._hb_lines(ordered) or ["(no HB: lines)"]
    report += ["", "--- slow shape ---"] + run_hub_bench._shape_lines(hitch_rows, bench)
    report += ["", "--- slowest hitches ---"] + (run_hub_bench._slow_lines(ranked) or ["(none)"])
    place_fail, place_lines = _place_block(report, Path(args.report))
    report += place_lines
    return agent_log.finish(
        JOB + "-report",
        root,
        "\n".join(report),
        "FAIL" if place_fail else "PASS",
        args=args,
        legacy=False,
        echo="\n".join(report),
        fail_signals=place_fail,
    )


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "One continuous hub, dungeon, dispel, hub, dungeon run (desktop window and a visible web export).",
        json_out=True,
    )
    ap.add_argument("--timeout-sec", type=int, default=960, help="Desktop Godot timeout, and the web wait after export (default 960).")
    ap.add_argument("--headless", action="store_true", help="desktop driver only; not an FPS reading")
    ap.add_argument("--leg", choices=("both", "desktop", "web"), default="both", help="Which runs to launch (default both).")
    ap.add_argument("--browser", default="", help="Force the web window binary. Default: Edge if installed, else Chrome.")
    ap.add_argument("--report", default="", help="Reprint seg lines and the hitch summary from a hitch JSONL. Does not launch a run.")
    # dest is not walk_layers. run_hub_bench._web reads that attribute as the hub fill isolator.
    ap.add_argument("--walk-layers", dest="sweep_layers", action="store_true", help="After the first scored hub walk, time each hidden group. Those frames are not in fps_pct. Does not change the 99%% bar.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.report:
        return _report(root, args)
    out_log = agent_log.run_path(JOB, root, "out.log")
    err_log = agent_log.run_path(JOB, root, "err.log")
    fail = 0
    body = ["perf sweep root=.", "leg=%s" % args.leg]
    body.append(bench_env.env_line(
        godot=bench_env.godot_version(str(godot_lib.godot_exe())),
        renderer="gl_compatibility",
        browser="see web leg" if args.leg in ("both", "web") else "n/a",
        vsync="see present line",
        cap="max_fps 120",
        headless=bool(args.headless),
    ))
    extra = list(EXTRA)
    query = QUERY
    if args.sweep_layers:
        extra.append("--wdb-sweep-layers")
        query += "&wdb-sweep-layers"
    if args.leg in ("both", "desktop"):
        d_fail, d_body = run_hub_bench._desktop(
            root, args, out_log, err_log,
            flag=FLAG, fresh_name="perf-sweep-fresh", label="perf sweep", extra=extra,
        )
        d_extra, d_lines = _place_block(d_body, _hitch_file(d_body))
        d_fail += d_extra
        d_body += d_lines
        fail += d_fail
        body += d_body
    if args.leg in ("both", "web"):
        w_fail, w_body = run_hub_bench._web(
            root, args,
            flag=FLAG, site_prefix="perf-sweep-web", profile_name="perf-sweep-browser",
            label="perf sweep", extra_query=query,
        )
        sink = root / "_logs" / "web-perf" / "hitch.jsonl"
        w_extra, w_lines = _place_block(w_body, sink if sink.is_file() else _hitch_file(w_body))
        w_fail += w_extra
        w_body += w_lines
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
