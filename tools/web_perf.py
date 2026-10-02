#!/usr/bin/env python3
"""Advisory performance run of the EXPORTED web build (docs/ or _pages/) in headless Chrome.

  python3 tools/web_perf.py [--site docs] [--flow title-idle|camp-walk] [--save-baseline F | --baseline F]

Serves --site (or uses --url), loads it, replays a flow from tools/web-perf-flows.json (key, hold, click, wait,
shot steps; shots land in _logs/web-perf/), and records load time (navigation to first frame after the engine overlay hides), per-frame
times (avg/p95/max fps, frames over --long-ms), JS heap and wasm/DOM counters (CDP), and asset
transfer sizes. Writes _logs/web-perf/report.json. --baseline F diffs against a saved report; a metric
worse than --max-worse-pct is flagged WORSE (RESULT INFO, exit 0 unless --strict). Needs
`pip install playwright` and a Chrome/Chromium (--chrome or $CHROME_BIN or PATH); no browser download.
Software GL in headless boxes is slow: compare runs on the same machine only. Not a numbered smoke.
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
import time
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

JOB = "web-perf"
FLOWS = "tools/web-perf-flows.json"
RAF = ("window.__wp={f:[],t:0};(function l(t){if(window.__wp.t){window.__wp.f.push(t-window.__wp.t)}"
       "window.__wp.t=t;requestAnimationFrame(l)})(0);requestAnimationFrame(function l(t){requestAnimationFrame(l)});")
UP = {"load_ms", "avg_frame_ms", "p95_frame_ms", "max_frame_ms", "long_frames", "heap_mb", "transfer_mb"}


def serve(site: Path):
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    h = functools.partial(Quiet, directory=str(site))
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def run_flow(page, steps: list[dict], out: Path) -> None:
    for s in steps:
        if "wait" in s:
            page.wait_for_timeout(int(s["wait"]))
        elif "click" in s:  # [x, y] as fractions of the viewport (also focuses the canvas)
            v = page.viewport_size
            page.mouse.click(v["width"] * s["click"][0], v["height"] * s["click"][1])
        elif "shot" in s:
            page.screenshot(path=str(out / (s["shot"] + ".png")))
        elif "key" in s:
            page.keyboard.press(s["key"])
        elif "hold" in s:
            page.keyboard.down(s["hold"])
            page.wait_for_timeout(int(s.get("ms", 500)))
            page.keyboard.up(s["hold"])


def measure(url: str, chrome: str, steps: list[dict], long_ms: float, timeout_s: int, size: tuple[int, int], out: Path) -> dict:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as pw:
        br = pw.chromium.launch(executable_path=chrome, headless=True,
                                args=["--enable-precise-memory-info", "--use-gl=angle", "--use-angle=swiftshader",
                                      "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required"])
        ctx = br.new_context(viewport={"width": size[0], "height": size[1]}, service_workers="block")
        page = ctx.new_page()
        page.add_init_script(RAF)
        cdp = ctx.new_cdp_session(page)
        cdp.send("Performance.enable")
        t0 = time.time()
        page.goto(url, wait_until="commit")
        page.wait_for_function("(()=>{const s=document.getElementById('status');window.__wp.seen=window.__wp.seen||!!s;"
                               "return window.__wp.seen&&!s&&!!document.getElementById('canvas')})()",
                               timeout=timeout_s * 1000)
        load_ms = (time.time() - t0) * 1000
        page.evaluate("window.__wp.f.length=0")
        run_flow(page, steps, out)
        frames = page.evaluate("window.__wp.f")
        m = {x["name"]: x["value"] for x in cdp.send("Performance.getMetrics")["metrics"]}
        res = page.evaluate("performance.getEntriesByType('resource').map(r=>[r.name.split('/').pop(),r.transferSize||r.encodedBodySize||0])")
        br.close()
    fs = sorted(frames) or [0.0]
    return {
        "load_ms": round(load_ms), "frames": len(frames),
        "avg_fps": round(1000 / statistics.mean(fs), 1) if frames else 0,
        "avg_frame_ms": round(statistics.mean(fs), 1), "p95_frame_ms": round(fs[int(len(fs) * 0.95) - 1 if len(fs) > 1 else 0], 1),
        "max_frame_ms": round(fs[-1], 1), "long_frames": sum(1 for x in fs if x > long_ms),
        "heap_mb": round(m.get("JSHeapUsedSize", 0) / 1048576, 1), "dom_nodes": int(m.get("Nodes", 0)),
        "transfer_mb": round(sum(b for _, b in res) / 1048576, 2),
        "assets": sorted(({"file": n, "kb": round(b / 1024)} for n, b in res if b > 262144), key=lambda a: -a["kb"]),
    }


def diff(cur: dict, base: dict, pct: float) -> list[str]:
    out = ["NOTE baseline flow %s differs from %s" % (base.get("flow"), cur.get("flow"))] if base.get("flow") != cur.get("flow") else []
    for k in sorted(UP):
        a, b = cur.get(k), base.get(k)
        if isinstance(a, (int, float)) and isinstance(b, (int, float)) and b > 0 and (a - b) * 100 / b > pct:
            out.append("WORSE %s %s -> %s (+%.0f%%)" % (k, b, a, (a - b) * 100 / b))
    if cur.get("avg_fps") and base.get("avg_fps") and (base["avg_fps"] - cur["avg_fps"]) * 100 / base["avg_fps"] > pct:
        out.append("WORSE avg_fps %s -> %s" % (base["avg_fps"], cur["avg_fps"]))
    return out


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Advisory perf run of the exported web build in headless Chrome.", json_out=True)
    ap.add_argument("--site", default="docs", help="Exported site dir (default docs).")
    ap.add_argument("--url", default="", help="Test this URL instead of serving --site.")
    ap.add_argument("--flow", default="title-idle", help="Flow name in %s." % FLOWS)
    ap.add_argument("--chrome", default=os.environ.get("CHROME_BIN", ""), help="Chrome/Chromium binary (default PATH).")
    ap.add_argument("--long-ms", type=float, default=50.0, help="A frame over this many ms is long (default 50).")
    ap.add_argument("--timeout-sec", type=int, default=120, help="Load timeout.")
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--height", type=int, default=720)
    ap.add_argument("--baseline", default="", help="Saved report to diff against.")
    ap.add_argument("--save-baseline", default="", help="Copy this run's report here.")
    ap.add_argument("--max-worse-pct", type=float, default=25.0, help="Flag a metric worse by more than this (default 25).")
    ap.add_argument("--strict", action="store_true", help="Exit 1 when a metric is WORSE (default advisory).")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    flows = json.loads((root / FLOWS).read_text(encoding="utf-8"))
    if args.flow not in flows:
        agent_log.fail("unknown flow %s. flows: %s" % (args.flow, ", ".join(sorted(flows))))
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
            agent_log.fail("no exported site at %s (python3 tools/export_web.py)" % args.site)
        srv = serve(site)
        url = "http://127.0.0.1:%d/index.html" % srv.server_address[1]
    try:
        shots = root / "_logs" / JOB
        shots.mkdir(parents=True, exist_ok=True)
        rep = measure(url, chrome, flows[args.flow]["steps"], args.long_ms, args.timeout_sec, (args.width, args.height), shots)
    except Exception as e:  # load timeout, Chrome launch
        return agent_log.finish(JOB, root, "error: %s" % str(e).splitlines()[0], "FAIL", args=args, flow=args.flow)
    finally:
        if srv:
            srv.shutdown()
    rep.update(flow=args.flow, site=args.site if not args.url else args.url, chrome=Path(chrome).name)
    out = root / "_logs" / JOB / "report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(rep, indent=1), encoding="utf-8")
    if args.save_baseline:
        bp = root / args.save_baseline
        bp.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(out, bp)
    worse = []
    if args.baseline:
        worse = diff(rep, json.loads((root / args.baseline).read_text(encoding="utf-8")), args.max_worse_pct)
    lines = ["%s=%s" % (k, v) for k, v in rep.items() if k != "assets"] + ["big_asset %(file)s %(kb)s KB" % a for a in rep["assets"][:5]] + worse
    worse = [w for w in worse if w.startswith("WORSE")] if not args.baseline else worse
    n_worse = sum(1 for w in worse if w.startswith("WORSE"))
    status = "FAIL" if n_worse and args.strict else ("INFO" if n_worse else "PASS")
    return agent_log.finish(JOB, root, "\n".join(lines), status, args=args, flow=args.flow, load_ms=rep["load_ms"],
                            avg_fps=rep["avg_fps"], p95_ms=rep["p95_frame_ms"], long=rep["long_frames"],
                            heap_mb=rep["heap_mb"], mb=rep["transfer_mb"], worse=n_worse)


if __name__ == "__main__":
    raise SystemExit(main())
