#!/usr/bin/env python3
"""Advisory performance run of the EXPORTED web build in headless Chrome. Never a gate.

  python tools/web_perf.py [--site DIR | --url U] [--flow NAME[,NAME]|all] [--save-baseline F | --baseline F]

Serves --site (default docs; use a fresh `export_web.py --out DIR`, docs/ may be stale) and replays flows from
tools/web-perf-flows.json (steps: phase wait settle key hold click eval waitplay shot; `query` adds URL args like wdb-seed=42; `boot` prepends the splash/title steps). Reports load_ms
(navigation to the engine overlay gone), its breakdown (wasm_dl_ms, wasm_compile_ms, init_ms), frame ms/fps and long
frames per phase, JS heap and wasm memory peaks (sampled every 500 ms; wasm memory never shrinks), transfer sizes and
page errors. Writes a stamped _logs/web-perf/<stamp>-report.json per run. --baseline F diffs against a saved file (tools/web-perf-baseline.json);
a metric worse than its threshold is WORSE; a playtester flow whose run errors, stalls or ends early is INVALID (flagged, never baselined) (RESULT INFO, exit 0 unless --strict). --repeat N takes the median of N runs.
--mbps throttles the network. Needs `pip install playwright` and Chrome/Chromium; no browser download. Software GL:
compare runs on the same machine only. Not a numbered smoke.
"""
from __future__ import annotations

import functools
import http.server
import json
import os
import shutil
import statistics
import sys
import threading
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import web_perf_lib

JOB = "web-perf"
FLOWS = "tools/web-perf-flows.json"
# metric: (max worse %, min absolute change). Down-is-bad metrics are in DOWN. Wall-clock and JS heap (GC timing, bimodal 77/136 MB in camp) are noisy, so wide; wasm_mem_mb is the steady one.
UP = {"load_ms": (40, 1500), "init_ms": (50, 1000), "avg_frame_ms": (30, 5), "p95_frame_ms": (40, 10), "long_frames": (60, 5),
      "heap_mb": (60, 40), "wasm_mem_mb": (10, 16), "transfer_mb": (5, 0.5), "page_errors": (0, 1)}
DOWN = {"avg_fps": (30, 3)}
SCALAR = ("load_ms", "wall_ms", "wasm_dl_ms", "wasm_compile_ms", "pck_end_ms", "init_ms", "frames", "avg_fps", "avg_frame_ms",
          "p95_frame_ms", "max_frame_ms", "long_frames", "heap_mb", "wasm_mem_mb", "dom_nodes", "transfer_mb", "page_errors")


def serve(site: Path):
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(site)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def median(runs: list[dict]) -> dict:
    rep = dict(runs[len(runs) // 2])
    for k in SCALAR:
        rep[k] = round(statistics.median(r[k] for r in runs), 2)
    rep["runs"] = len(runs)
    if len({len(r.get("load_marks", [])) for r in runs}) == 1:  # engine load marks: median of each mark across the runs
        rep["load_marks"] = [[m[0]] + [int(statistics.median(r["load_marks"][i][j] for r in runs)) for j in range(1, 5)]
                             for i, m in enumerate(runs[0].get("load_marks", []))]
    rep["invalid"] = sorted({x for r in runs for x in r.get("invalid", [])})
    if any(r["play"] for r in runs):
        rep["play_runs"] = [r["play"] for r in runs]  # per-run playtester telemetry: what differs between runs
    return rep


def diff(cur: dict, base: dict, pct: float | None) -> list[str]:
    out = []
    for table, sign in ((UP, 1), (DOWN, -1)):
        for k, (lim, floor) in sorted(table.items()):
            a, b = cur.get(k), base.get(k)
            if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
                continue
            d = (a - b) * sign
            if d > floor and (b <= 0 or d * 100 / b > (lim if pct is None else pct)):
                out.append("WORSE %s %s -> %s" % (k, b, a))
    return out


def health(rep: dict) -> list[str]:
    """Playtester health for one run (flows with a play result or a waitplay step); a non-empty list = INVALID, never baselined."""
    p, bad = rep["play"], []
    if not p:
        return ["INVALID no playtester result (never started or stalled)"]
    if p.get("end_cond") != "interrupted playtest":
        bad.append("INVALID run ended early: %s" % p.get("end_cond"))
    if p.get("kills", 0) < 1:
        bad.append("INVALID playtester made no kills")
    if p.get("stuck_t", 0) > 5.0:
        bad.append("INVALID playtester stuck %ss" % p.get("stuck_t"))
    if p.get("stuck_max", 0) > 6.0:
        bad.append("INVALID playtester was stuck %ss before an unstick" % p.get("stuck_max"))
    if p.get("gate_over", 0) > 0:
        bad.append("INVALID playtester gate (menu/load/pause) never opened for 15s")
    if p.get("time_scale", 1.0) != 1.0:
        bad.append("INVALID playtester ran at time_scale %s (frame times skewed)" % p.get("time_scale"))
    ce = sum(rep["console_errors"].values())
    if ce:
        bad.append("INVALID %d console errors during the run, first: %s" % (ce, " | ".join(rep.get("console_msgs", []))[:300]))
    mx = max((v["max_frame_ms"] for k, v in rep["phases"].items() if not k.startswith("_")), default=0)
    if mx > 1500:
        bad.append("INVALID frame stall %sms" % mx)
    return bad


def stuck(flow: dict, shots: dict) -> list[str]:
    """expect_change: [[shot_a, shot_b], ...]; mean luminance within 10% means the flow stayed on that screen."""
    out = []
    for a, b in flow.get("expect_change") or []:
        if shots.get(a, -1) >= 0 and shots.get(b, -1) >= 0 and abs(shots[a] - shots[b]) * 100 / max(shots[a], 1) < 10:
            out.append("STUCK shots %s and %s look the same (luminance %s vs %s): the flow did not change screens" % (a, b, shots[a], shots[b]))
    return out


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Advisory perf run of the exported web build in headless Chrome.", json_out=True)
    ap.add_argument("--site", default="docs", help="Exported site dir (default docs; may be stale, export with export_web.py --out).")
    ap.add_argument("--url", default="", help="Test this URL instead of serving --site.")
    ap.add_argument("--flow", default="title-idle", help="Flow name(s), comma separated, or all (see %s)." % FLOWS)
    ap.add_argument("--chrome", default=os.environ.get("CHROME_BIN", ""), help="Chrome/Chromium binary (default PATH).")
    ap.add_argument("--long-ms", type=float, default=50.0, help="A frame over this many ms is long (default 50).")
    ap.add_argument("--timeout-sec", type=int, default=120, help="Load timeout.")
    ap.add_argument("--width", type=int, default=1280, help="Viewport width in px (default 1280).")
    ap.add_argument("--height", type=int, default=720, help="Viewport height in px (default 720).")
    ap.add_argument("--mbps", type=float, default=0.0, help="Throttle the network to this many Mbit/s (default off).")
    ap.add_argument("--repeat", type=int, default=1, help="Runs per flow; the report holds the median (default 1).")
    ap.add_argument("--baseline", default="", help="Saved report (e.g. tools/web-perf-baseline.json) to diff against.")
    ap.add_argument("--save-baseline", default="", help="Write this run's report here (merges flows into an existing file).")
    ap.add_argument("--max-worse-pct", type=float, default=None, help="One percent for every metric (default: per-metric table).")
    ap.add_argument("--strict", action="store_true", help="Exit 1 when a metric is WORSE or a flow is STUCK (default advisory).")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    flows = json.loads((root / FLOWS).read_text(encoding="utf-8"))
    boot = flows.pop("_boot")
    names = sorted(flows) if args.flow == "all" else [n for n in args.flow.split(",") if n]
    for n in names:
        if n not in flows:
            agent_log.fail("unknown flow %s. flows: %s" % (n, ", ".join(sorted(flows))))
    chrome = args.chrome or shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser") or ""
    if not chrome:
        agent_log.fail("no Chrome/Chromium: pass --chrome or set CHROME_BIN")
    try:
        import playwright  # noqa: F401
    except ImportError:
        agent_log.fail("playwright missing: pip install playwright (uses the system Chrome, no browser download)")
    site, srv, url = root / args.site, None, args.url
    if not url:
        if not (site / "index.html").is_file():
            agent_log.fail("no exported site at %s (python tools/export_web.py --out DIR)" % args.site)
        srv = serve(site)
        url = "http://127.0.0.1:%d/index.html" % srv.server_address[1]
    shots = root / "_logs" / JOB
    shots.mkdir(parents=True, exist_ok=True)
    reps: dict[str, dict] = {}
    try:
        for n in names:
            steps = (boot if flows[n].get("boot") else []) + flows[n]["steps"]
            runs = [web_perf_lib.measure(url, chrome, steps, args.long_ms, args.timeout_sec, (args.width, args.height), shots,
                                         n, args.mbps, flows[n].get("query", "")) for _ in range(max(args.repeat, 1))]
            for r in runs:
                r["invalid"] = health(r) if flows[n].get("playtest") else []
            reps[n] = median(runs)
    except Exception as e:  # load timeout, Chrome launch
        return agent_log.finish(JOB, root, "error: %s" % str(e).splitlines()[0], "FAIL", args=args, flow=args.flow)
    finally:
        if srv:
            srv.shutdown()
    label = ""
    if (site / "build_id.txt").is_file():
        label = (site / "build_id.txt").read_text(encoding="utf-8").strip()
    full = {"build_id": label, "site": args.site if not args.url else args.url, "chrome": Path(chrome).name,
            "viewport": "%dx%d" % (args.width, args.height), "flows": reps}
    out = agent_log.run_path(JOB, root, "report.json")
    out.write_text(json.dumps(full, indent=1), encoding="utf-8")
    if args.save_baseline:
        bp = root / args.save_baseline
        old = json.loads(bp.read_text(encoding="utf-8")) if bp.is_file() else {"flows": {}}
        old.update({k: v for k, v in full.items() if k != "flows"})
        old["flows"].update({n: {k: v for k, v in r.items() if k != "assets"} for n, r in reps.items() if not r["invalid"]})
        bp.parent.mkdir(parents=True, exist_ok=True)
        bp.write_text(json.dumps(old, indent=1) + "\n", encoding="utf-8")
    base = json.loads((root / args.baseline).read_text(encoding="utf-8")) if args.baseline else {"flows": {}}
    lines, flags = ["build_id=%s chrome=%s viewport=%s report=%s" % (label, full["chrome"], full["viewport"], agent_log.rel(root, out))], 0
    for n, r in reps.items():
        lines.append("flow %s" % n)
        lines += ["  %s=%s" % (k, r[k]) for k in SCALAR]
        lines += ["  mark %s=%s" % kv for kv in r["marks"].items()]
        lines += ["  load %s t=%d dt=%d vram=%d wasm=%d" % tuple(m) for m in r.get("load_marks", [])]
        lines += ["  play %s" % json.dumps(p, sort_keys=True) for p in r.get("play_runs", [])]
        lines += ["  phase %s %s" % (k, " ".join("%s=%s" % (a, b) for a, b in v.items())) for k, v in r["phases"].items()]
        lines += ["  big_asset %(file)s %(kb)s KB" % a for a in r["assets"][:4]]
        notes = stuck(flows[n], r["shots"]) + r["invalid"]
        if args.save_baseline and r["invalid"]:
            notes.append("NOTE flow %s NOT saved to the baseline (INVALID run)" % n)
        if args.baseline:
            if flows[n].get("marks_only"):
                notes.append("NOTE flow %s is marks only (load lines, no frame stats): not diffed" % n)
            else:
                notes += diff(r, base["flows"][n], args.max_worse_pct) if n in base["flows"] else ["NOTE no baseline for flow %s" % n]
        lines += ["  " + x for x in notes]
        flags += sum(1 for x in notes if x.startswith(("WORSE", "STUCK", "INVALID")))
    status = "FAIL" if flags and args.strict else ("INFO" if flags else "PASS")
    first = next(iter(reps.values()))
    return agent_log.finish(JOB, root, "\n".join(lines), status, args=args, flows=",".join(names), load_ms=first["load_ms"],
                            avg_fps=first["avg_fps"], heap_mb=first["heap_mb"], wasm_mb=first["wasm_mem_mb"], flagged=flags)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
