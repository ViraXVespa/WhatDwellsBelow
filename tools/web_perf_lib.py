"""Browser side of tools/web_perf.py: init script, flow replay, one measured page load. Advisory; see web_perf.py."""
from __future__ import annotations

import statistics
import time
from pathlib import Path

# Runs before the page: per-phase rAF frame times, wasm compile timing, 500 ms JS heap / wasm memory (engine.rtenv.HEAPU8) sampler.
INIT = """
window.__wp={ph:'_boot',f:{},t:0,comp:[],cerr:{},cmsg:[],heap:0,wasm:0,gone:0,seen:0,errs:0,t0:performance.now()};
(function(){var W=window.__wp;
['instantiateStreaming','compileStreaming','instantiate','compile'].forEach(function(k){var o=WebAssembly[k];
if(!o)return;WebAssembly[k]=function(){var s=performance.now();return o.apply(WebAssembly,arguments).then(function(r){
W.comp.push([k,s,performance.now()]);return r})}});
function samp(){try{var h=performance.memory?performance.memory.usedJSHeapSize:0;if(h>W.heap)W.heap=h;
var b=engine.rtenv.HEAPU8.buffer.byteLength;if(b>W.wasm)W.wasm=b}catch(x){}}
setInterval(samp,500);
(function l(t){var b=document.getElementById('wdb-boot');if(b)W.seen=1;
if(W.seen&&!b&&!W.gone){W.gone=performance.now()}
if(W.t&&W.gone){(W.f[W.ph]=W.f[W.ph]||[]).push(t-W.t)}W.t=t;requestAnimationFrame(l)})(0);
window.addEventListener('error',function(){W.errs++});
var ce=console.error;console.error=function(){var m=Array.prototype.join.call(arguments,' ');if(/keyboard_get_keycode_from_physical|Not supported by this display server/.test(m))return ce.apply(console,arguments);W.cerr[W.ph]=(W.cerr[W.ph]||0)+1;if(W.cmsg.length<4&&W.ph[0]!='_')W.cmsg.push(W.ph+': '+Array.prototype.join.call(arguments,' ').slice(0,140));return ce.apply(console,arguments)};window.__wpSamp=samp})();
"""
PLAY = ("stuck_t", "seed", "floor", "end_cond", "duration", "kills", "dmg_dealt", "dmg_taken", "crits", "combat_t", "near_death")
READY = "!!window.__wp.gone&&!!document.getElementById('canvas')"


def _lum(png: bytes) -> float:
    try:
        import io

        from PIL import Image, ImageStat
        return round(ImageStat.Stat(Image.open(io.BytesIO(png)).convert("L")).mean[0], 1)
    except ImportError:
        return -1.0


def run_flow(page, steps: list[dict], out: Path, tag: str) -> tuple[dict, dict]:
    """Replay steps. Returns ({shot name: mean luminance 0-255, -1 without Pillow}, {settle mark: ms}); web_perf.py flags expect_change pairs that look alike (stuck menu)."""
    shots, marks = {}, {}
    for s in steps:
        if "phase" in s:
            page.evaluate("p=>{window.__wp.ph=p}", s["phase"])
        elif "wait" in s:
            page.wait_for_timeout(int(s["wait"]))
        elif "settle" in s:  # after "min" ms: wait for fresh frames, the last 12 all under 110 ms (a scene-change stall is over)
            t0 = time.time()
            page.wait_for_timeout(int(s.get("min", 0)))
            try:
                page.wait_for_function("(()=>{const W=window.__wp,f=Object.values(W.f).pop()||[];return performance.now()-W.t<200&&f.length>12&&"
                                       "f.slice(-12).every(x=>x<110)})()", timeout=int(s["settle"]))
            except Exception:
                pass
            if s.get("as"):
                marks[s["as"]] = round((time.time() - t0) * 1000)
        elif "eval" in s:  # JS in the page, e.g. window.wdbPlaytest(30) (needs ?wdb-playtest in the flow query)
            page.evaluate(s["eval"])
        elif "waitplay" in s:  # wait for the playtester's finished run (window.__wdbPlay), at most "waitplay" ms
            try:
                page.wait_for_function("!!window.__wdbPlay", timeout=int(s["waitplay"]))
            except Exception:
                pass
        elif "click" in s:  # [x, y] as viewport fractions
            v = page.viewport_size
            page.mouse.click(v["width"] * s["click"][0], v["height"] * s["click"][1])
        elif "shot" in s:
            png = page.screenshot(path=str(out / ("%s-%s.png" % (tag, s["shot"]))))
            shots[s["shot"]] = _lum(png)
        elif "key" in s:
            page.keyboard.press(s["key"])
        elif "hold" in s:
            keys = s["hold"] if isinstance(s["hold"], list) else [s["hold"]]
            for k in keys:
                page.keyboard.down(k)
            page.wait_for_timeout(int(s.get("ms", 500)))
            for k in keys:
                page.keyboard.up(k)
    return shots, marks


def _stats(fs: list[float], long_ms: float) -> dict:
    fs = sorted(fs) or [0.0]
    n = len(fs)
    return {"frames": n, "avg_fps": round(1000 / statistics.mean(fs), 1) if fs[-1] else 0,
            "avg_frame_ms": round(statistics.mean(fs), 1), "p95_frame_ms": round(fs[max(int(n * 0.95) - 1, 0)], 1),
            "max_frame_ms": round(fs[-1], 1), "long_frames": sum(1 for x in fs if x > long_ms)}


def measure(url: str, chrome: str, steps: list[dict], long_ms: float, timeout_s: int, size: tuple[int, int], out: Path,
            tag: str, mbps: float = 0.0, query: str = "") -> dict:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as pw:
        br = pw.chromium.launch(executable_path=chrome, headless=True,
                                args=["--enable-precise-memory-info", "--use-gl=angle", "--use-angle=swiftshader",
                                      "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required"])
        ctx = br.new_context(viewport={"width": size[0], "height": size[1]}, device_scale_factor=1, service_workers="block")
        page = ctx.new_page()
        errs: list[str] = []
        page.on("pageerror", lambda e: errs.append(str(e)[:80]))
        page.add_init_script(INIT)
        cdp = ctx.new_cdp_session(page)
        cdp.send("Performance.enable")
        if mbps > 0:
            cdp.send("Network.enable")
            cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 20,
                                                          "downloadThroughput": mbps * 125000, "uploadThroughput": mbps * 125000})
        t0 = time.time()
        page.goto(url + (("&" if "?" in url else "?") + query if query else ""), wait_until="commit")
        page.wait_for_function(READY, timeout=timeout_s * 1000)
        wall_ms = (time.time() - t0) * 1000
        shots, marks = run_flow(page, steps, out, tag)
        page.evaluate("window.__wpSamp()")
        w = page.evaluate("window.__wp")
        play = page.evaluate("window.__wdbPlay||null")
        m = {x["name"]: x["value"] for x in cdp.send("Performance.getMetrics")["metrics"]}
        res = page.evaluate("performance.getEntriesByType('resource').map(r=>[r.name.split('/').pop().split('?')[0],"
                            "r.transferSize||r.encodedBodySize||0,r.startTime,r.responseEnd])")
        br.close()
    tm = {n: (s, e) for n, _, s, e in res if n.endswith((".wasm", ".pck"))}
    wasm, pck = tm.get("index.wasm", (0, 0)), tm.get("index.pck", (0, 0))
    comp = max((e - s for k, s, e in w["comp"] if k != "compile"), default=0)
    gone = w["gone"]
    ph = {k: _stats(v, long_ms) for k, v in w["f"].items()}
    meas = [x for k, v in w["f"].items() if not k.startswith("_") for x in v]
    rep = {"load_ms": round(gone), "wall_ms": round(wall_ms), "wasm_dl_ms": round(wasm[1] - wasm[0]),
           "wasm_compile_ms": round(comp), "pck_end_ms": round(pck[1]), "init_ms": round(gone - max(pck[1], wasm[1])),
           **_stats(meas, long_ms), "heap_mb": round(max(w["heap"], m.get("JSHeapUsedSize", 0)) / 1048576, 1),
           "wasm_mem_mb": round(w["wasm"] / 1048576, 1), "dom_nodes": int(m.get("Nodes", 0)),
           "transfer_mb": round(sum(b for _, b, _, _ in res) / 1048576, 2), "page_errors": len(errs) + w["errs"],
           "phases": ph, "marks": marks, "console_msgs": w["cmsg"], "console_errors": {k: v for k, v in w["cerr"].items() if not k.startswith("_")}, "play": {k: play[k] for k in PLAY if k in play} if play else {}, "shots": shots,
           "assets": sorted(({"file": n, "kb": round(b / 1024)} for n, b, _, _ in res if b > 262144), key=lambda a: -a["kb"])}
    return rep
