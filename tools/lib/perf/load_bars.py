#!/usr/bin/env python3
"""Record both loading bars against time and chart them: the web landing bar (tools/data/web_shell.html) and the in-game
Placeholdia loader (scripts/ui/loader.gd, ?wdb-loader-trace).

    python tools/perf.py bars --site DIR [--mbps 16] [--tag NAME]
    python tools/perf.py bars --desktop [--tag NAME]

--desktop runs the game itself (Godot pin, OpenGL on $DISPLAY) twice instead: cold (shader caches cleared) then warm.

Runs headless Chrome twice on one profile: cold (cache empty, network throttled to --mbps) then cached (reload).
Each run boots straight into Play (?wdb-load-timing-smoke) and samples every 40 ms: the drawn fill ratio of the web bar,
its % label and status, and every LOADTRACE row of the game bar (target, shown, label). Writes
_logs/load-bars/<tag>.json and <tag>.png (fill and label vs time; the game bar's frame gaps show as flat steps).
Flags a run where a label reads 100% while its fill is under 99%, or the fill goes backwards.
"""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log

SAMPLE = r"""
(() => {
  const W = window.__lb = {rows: [], t0: performance.now()};
  const tick = () => {
    const f = document.getElementById('wdb-fill'), tr = document.getElementById('wdb-track');
    const p = document.getElementById('wdb-pct'), s = document.getElementById('wdb-status');
    if (f && tr && document.getElementById('wdb-boot')) {
      const w = tr.getBoundingClientRect().width;
      W.rows.push([Math.round(performance.now() - W.t0), w > 0 ? f.getBoundingClientRect().width / w : 0,
                   p ? p.textContent : '', s ? s.textContent : '', f.classList.contains('is-wait') ? 1 : 0]);
      setTimeout(tick, 40);
    } else if (W.rows.length) {
      W.gone = Math.round(performance.now() - W.t0);
    } else {
      setTimeout(tick, 40);
    }
  };
  tick();
})();
"""

def _pct(text: str) -> float | None:
    t = text.strip().split("%")[0].split()[-1] if "%" in text else ""
    try:
        return float(t) / 100.0
    except ValueError:
        return None

def run(page, url: str, timeout_s: int) -> dict:
    game: list[list] = []
    t0 = time.time()

    def on_msg(m):
        if m.text.startswith("LOADTRACE "):
            parts = m.text.split(" ", 4)
            game.append([round((time.time() - t0) * 1000), float(parts[2]), float(parts[3]), parts[4] if len(parts) > 4 else ""])

    page.on("console", on_msg)
    page.goto(url, wait_until="commit")
    end = time.time() + timeout_s
    while time.time() < end:
        page.wait_for_timeout(250)
        if game and game[-1][2] >= 0.999 and "100%" in game[-1][3]:
            break
    page.wait_for_timeout(300)
    lb = page.evaluate("window.__lb || {rows: []}")
    page.remove_listener("console", on_msg)
    off = round((time.time() - t0) * 1000) - round(page.evaluate("performance.now() - window.__lb.t0")) if lb.get("rows") else 0
    web = [[r[0] + off, r[1], r[2], r[3], r[4]] for r in lb["rows"]]
    return {"web": web, "web_gone_ms": (lb.get("gone") or 0) + off, "game": game}

def problems(run_: dict) -> list[str]:
    out = []
    for name, rows, fi, li in (("web", run_["web"], 1, 2), ("game", run_["game"], 2, 3)):
        hi = 0.0
        for r in rows:
            if name == "web" and r[4]:
                continue
            if r[fi] + 0.004 < hi:
                out.append(f"{name}: fill went back {hi:.3f} -> {r[fi]:.3f} at {r[0]} ms")
                break
            hi = max(hi, r[fi])
        for r in rows:
            p = _pct(str(r[li]).split("|")[0])
            if p is not None and p >= 0.995 and r[fi] < 0.99:
                out.append(f"{name}: label 100% with fill {r[fi]:.3f} at {r[0]} ms")
                break
        gaps = [(b[0] - a[0], a[0]) for a, b in zip(rows, rows[1:])]
        if gaps:
            g, at = max(gaps)
            out.append(f"{name}: longest frozen gap {g} ms at {at} ms") if g > 600 else None
    return out

def chart(runs: dict, path: Path) -> None:
    from PIL import Image, ImageDraw
    W, H, pad = 1200, 360, 50
    img = Image.new("RGB", (W, H * len(runs)), (250, 248, 242))
    d = ImageDraw.Draw(img)
    for k, (name, r) in enumerate(runs.items()):
        y0 = k * H
        rows_w = [x for x in r["web"] if not x[4]]
        span = max([x[0] for x in r["web"]] + [x[0] for x in r["game"]] + [1])
        sx = lambda t: pad + (W - 2 * pad) * t / span  # noqa: E731
        sy = lambda v: y0 + H - pad - (H - 2 * pad) * v  # noqa: E731
        d.rectangle([pad, sy(1), W - pad, sy(0)], outline=(120, 110, 90))
        for v in (0.25, 0.5, 0.75):
            d.line([pad, sy(v), W - pad, sy(v)], fill=(225, 220, 205))
        for s in range(0, int(span / 1000) + 1, max(1, int(span / 10000))):
            d.text((sx(s * 1000) - 6, sy(0) + 6), f"{s}s", fill=(90, 80, 60))

        def line(pts, col, w=2):
            if len(pts) > 1:
                d.line(pts, fill=col, width=w)
        line([(sx(x[0]), sy(x[1])) for x in rows_w], (200, 140, 30))
        line([(sx(x[0]), sy(_pct(x[2]) or 0)) for x in rows_w if _pct(x[2]) is not None], (120, 60, 160), 1)
        line([(sx(x[0]), sy(x[2])) for x in r["game"]], (40, 120, 60))
        line([(sx(x[0]), sy(x[1])) for x in r["game"]], (160, 200, 160), 1)
        line([(sx(x[0]), sy(_pct(x[3].split("|")[0]) or 0)) for x in r["game"]], (30, 60, 160), 1)
        for x in r["game"]:
            d.line([sx(x[0]), sy(0) - 3, sx(x[0]), sy(0)], fill=(40, 120, 60))
        d.text((pad, y0 + 8), f"{name}: web fill (orange) / web label (purple); game shown (green), target (pale), label (blue); ticks = game frames", fill=(30, 30, 30))
        for i, p in enumerate(problems(r)[:3]):
            d.text((pad, y0 + 22 + 12 * i), p, fill=(170, 30, 30))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)

def desktop(root: Path, timeout_s: int) -> dict:
    import shutil
    import subprocess
    import godot_lib

    exe = str(godot_lib.godot_exe(""))
    caches = [root / ".godot" / "shader_cache", Path.home() / ".local/share/godot/app_userdata/What Dwells Below/shader_cache",
              Path.home() / ".local/share/godot/app_userdata/What Dwells Below/vulkan",
              Path.home() / ".local/share/godot/app_userdata/What Dwells Below/loader_steps.cfg"]
    runs = {}
    for name in ("desktop cold", "desktop warm"):
        if name.endswith("cold"):
            for c in caches:
                shutil.rmtree(c, ignore_errors=True) if c.is_dir() else c.unlink(missing_ok=True)
        r = subprocess.run([exe, "--path", str(root), "--rendering-driver", "opengl3", "--resolution", "1280x720", "--",
                            "--wdb-load-timing-smoke", "--wdb-loader-trace"], capture_output=True, text=True, timeout=timeout_s)
        game = []
        for ln in (r.stdout + r.stderr).splitlines():
            if ln.startswith("LOADSTEPS "):
                print(name, ln)
            if ln.startswith("LOADTRACE "):
                parts = ln.split(" ", 4)
                game.append([int(parts[1]), float(parts[2]), float(parts[3]), parts[4] if len(parts) > 4 else ""])
        t0 = game[0][0] if game else 0
        runs[name] = {"web": [], "web_gone_ms": 0, "game": [[g[0] - t0] + g[1:] for g in game]}
    return runs

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Chart both loading bars (web landing + in-game) vs time, cold and cached.", json_out=True)
    ap.add_argument("--site", default="", help="Exported web build dir (tools/release.py export-web --out DIR).")
    ap.add_argument("--mbps", type=float, default=16.0, help="Cold-run download throttle in Mbit/s (default 16).")
    ap.add_argument("--tag", default="load-bars", help="Output name under _logs/load-bars/.")
    ap.add_argument("--timeout-sec", type=int, default=240, help="Per-run timeout in seconds (default 240).")
    ap.add_argument("--desktop", action="store_true", help="Trace the desktop game (cold + warm shader cache) instead of web.")
    ap.add_argument("--chart", default="", help="Only redraw the chart from a saved _logs/load-bars JSON.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.chart:
        src = Path(args.chart)
        chart(json.loads(src.read_text(encoding="utf-8")), src.with_suffix(".png"))
        return agent_log.emit_result("PASS", chart=src.with_suffix(".png").as_posix())
    if args.desktop:
        runs = desktop(root, args.timeout_sec)
        return _report(root, args, runs)
    site = Path(args.site).resolve()

    class H(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def end_headers(self):
            if self.path.split("?")[0].endswith((".wasm", ".pck", ".js")):
                self.send_header("Cache-Control", "max-age=3600")
            super().end_headers()

    class S(http.server.ThreadingHTTPServer):
        def handle_error(self, *a):
            pass

    srv = S(("127.0.0.1", 0), functools.partial(H, directory=str(site)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = "http://127.0.0.1:%d/index.html?wdb-load-timing-smoke&wdb-loader-trace" % srv.server_address[1]
    from playwright.sync_api import sync_playwright
    runs = {}
    with sync_playwright() as pw:
        br = pw.chromium.launch(channel="chrome", args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        ctx = br.new_context(viewport={"width": 1280, "height": 720}, service_workers="block")
        page = ctx.new_page()
        page.add_init_script(SAMPLE)
        cdp = ctx.new_cdp_session(page)
        cdp.send("Network.enable")
        cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 20, "downloadThroughput": args.mbps * 125000, "uploadThroughput": args.mbps * 125000})
        runs["cold %g Mbit/s" % args.mbps] = run(page, url, args.timeout_sec)
        cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 0, "downloadThroughput": -1, "uploadThroughput": -1})
        runs["cached"] = run(page, url, args.timeout_sec)
        br.close()
    srv.shutdown()
    return _report(root, args, runs)

def _report(root: Path, args, runs: dict) -> int:
    out = root / "_logs" / "load-bars"
    out.mkdir(parents=True, exist_ok=True)
    (out / f"{args.tag}.json").write_text(json.dumps(runs), encoding="utf-8")
    try:
        chart(runs, out / f"{args.tag}.png")
    except ImportError:
        print(f"no PIL in this python: draw it with  python tools/perf.py bars --chart _logs/load-bars/{args.tag}.json")
    body = []
    for name, r in runs.items():
        g = r["game"]
        body.append(f"{name}: web bar gone at {r['web_gone_ms']} ms; game bar {g[0][0] if g else '-'} -> {g[-1][0] if g else '-'} ms ({len(g)} frames)")
        body += ["  " + p for p in problems(r)]
    bad = sum(1 for r in runs.values() for p in problems(r) if "longest" not in p)
    return agent_log.finish("load-bars", root, "\n".join(body + ["", f"chart {agent_log.rel(root, out / (args.tag + '.png'))}"]),
                            "FAIL" if bad else "PASS", args=args, problems=bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
