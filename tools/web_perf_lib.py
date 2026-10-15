"""Browser side of tools/web_perf.py: init script, flow replay, one measured page load. Advisory; see web_perf.py."""
from __future__ import annotations

import statistics
import time
from pathlib import Path

# Runs before the page: per-phase rAF frame times, wasm compile timing, 500 ms JS heap / wasm memory (engine.rtenv.HEAPU8) sampler.
INIT = """
window.__wp={ph:'_boot',e:{},sw:[],f:{},t:0,comp:[],cerr:{},cmsg:[],load:[],heap:0,wasm:0,gone:0,seen:0,errs:0,t0:performance.now()};
(function(){var W=window.__wp;
['instantiateStreaming','compileStreaming','instantiate','compile'].forEach(function(k){var o=WebAssembly[k];
if(!o)return;WebAssembly[k]=function(){var s=performance.now();return o.apply(WebAssembly,arguments).then(function(r){
W.comp.push([k,s,performance.now()]);return r})}});
function samp(){try{var h=performance.memory?performance.memory.usedJSHeapSize:0;if(h>W.heap)W.heap=h;
var b=engine.rtenv.HEAPU8.buffer.byteLength;if(b>W.wasm)W.wasm=b}catch(x){}}
setInterval(samp,500);
(function l(t){var b=document.getElementById('wdb-boot');if(b)W.seen=1;
if(W.seen&&!b&&!W.gone){W.gone=performance.now()}
if(W.t&&W.gone){(W.f[W.ph]=W.f[W.ph]||[]).push(t-W.t);(W.e[W.ph]=W.e[W.ph]||[]).push(t)}W.t=t;requestAnimationFrame(l)})(0);
window.addEventListener('error',function(){W.errs++});
var ce=console.error;console.error=function(){var a0=arguments[0];if(typeof a0=='string'&&a0.indexOf('LOAD: ')==0){samp();W.load.push(a0.slice(6)+' wasm='+Math.round(W.wasm/1048576));return}W.cerr[W.ph]=(W.cerr[W.ph]||0)+1;if(W.cmsg.length<4&&W.ph[0]!='_')W.cmsg.push(W.ph+': '+Array.prototype.join.call(arguments,' ').slice(0,140));return ce.apply(console,arguments)};window.__wpSamp=samp})();
"""
# Audio probe (flows with "audio": true): every connection to an AudioContext destination goes through a tap that feeds an
# AudioWorklet on the audio thread, so a starved buffer (an all-zero render quantum after sound began) is counted even while
# the page's main thread is stalled. {"audio_reset": true} zeroes the counters; the report gets audio_gaps (runs of 2+ silent
# quanta, ~5 ms; only the browser music context window.wdbMusic.cx when the page has one), audio_gap_ms (longest) and audio_silent_ms.
AUDIO = r"""
(function(){var A=window.__wpA={q:0,on:0,zero:0,gaps:0,run:0,longest:0,rate:48000,ports:[]};
var src="class P extends AudioWorkletProcessor{constructor(){super();this.s={q:0,on:0,zero:0,gaps:0,run:0,longest:0};"+
"this.port.onmessage=()=>{this.s={q:0,on:this.s.on,zero:0,gaps:0,run:0,longest:0}};this.n=0}"+
"process(i){var s=this.s,c=i[0]&&i[0][0],z=true;if(c){for(var k=0;k<c.length;k++){if(c[k]!==0){z=false;break}}}s.q++;"+
"if(!z){s.on=1;if(s.run>=2){s.gaps++}s.run=0}else if(s.on){s.zero++;s.run++;if(s.run>s.longest)s.longest=s.run}"+
"if(++this.n%24==0)this.port.postMessage(s);return true}}registerProcessor('wp-probe',P)";
var url=URL.createObjectURL(new Blob([src],{type:'application/javascript'}));
var taps=new WeakMap(),oc=AudioNode.prototype.connect;
AudioNode.prototype.connect=function(d){if(d instanceof AudioDestinationNode){var cx=d.context,t=taps.get(cx);
if(!t){t=cx.createGain();taps.set(cx,t);oc.call(t,d);A.rate=cx.sampleRate;cx.audioWorklet.addModule(url).then(function(){
var p=new AudioWorkletNode(cx,'wp-probe');oc.call(t,p);oc.call(p,d);A.ports.push(p.port);
p.port.onmessage=function(e){A.last=A.last||[];A.st=A.st||new Map();A.st.set(p,e.data)}})}
var a=Array.prototype.slice.call(arguments);a[0]=t;return oc.apply(this,a)}return oc.apply(this,arguments)};
window.__wpAudioReset=function(){A.ports.forEach(function(p){p.postMessage(0)});A.st=new Map()};
window.__wpAudio=function(){var o={gaps:0,zero:0,longest:0,on:0,q:0},mc=window.wdbMusic&&window.wdbMusic.cx;if(A.st)A.st.forEach(function(s,p){if(mc&&p.context!==mc)return;o.gaps+=s.gaps+(s.run>=2?1:0);
o.zero+=s.zero;o.longest=Math.max(o.longest,s.longest);o.on|=s.on;o.q+=s.q});var ms=128000/A.rate;
return {audio_on:o.on,audio_gaps:o.gaps,audio_gap_ms:Math.round(o.longest*ms),audio_silent_ms:Math.round(o.zero*ms),audio_ms:Math.round(o.q*ms)}}})();
"""
# Headless Chrome paces rAF to 60 Hz, so frame times snap to 16.7 ms steps (33.4 p95 was two vsyncs, not game cost):
# a WebGL page sits at 59.5 fps with the defaults and ~1300 fps with these. --vsync in web_perf.py restores the pacing.
UNCAP = ["--disable-frame-rate-limit", "--disable-gpu-vsync", "--disable-background-timer-throttling", "--disable-renderer-backgrounding"]
PLAY = ("stuck_t", "seed", "floor", "end_cond", "duration", "kills", "dmg_dealt", "dmg_taken", "crits", "combat_t", "near_death",
        "think_ms", "think_max_ms", "think_n", "phys_ms", "gate_s", "gate_over", "unstick_n", "stuck_max", "time_scale")
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
        elif "audio_reset" in s:
            page.evaluate("window.__wpAudioReset&&window.__wpAudioReset()")
        elif "cpu" in s:  # CPU throttle factor (CDP), a forced low frame rate from this step on
            page.__wp_cdp.send("Emulation.setCPUThrottlingRate", {"rate": float(s["cpu"])})
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
            s0 = page.evaluate("performance.now()")
            png = page.screenshot(path=str(out / ("%s-%s.png" % (tag, s["shot"]))))
            page.evaluate("s=>window.__wp.sw.push([s,performance.now()])", s0)
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

def _load_marks(lines: list[str]) -> list[list]:
    """`LOAD: mark=ID t=T dt=D vram=V` lines the engine prints under ?wdb-load-timing-smoke (hub) or ?wdb-dungeon-load-timing-smoke -> [id, t, dt, vram, wasm_mb]."""
    out = []
    for ln in lines:
        kv = dict(x.split("=", 1) for x in ln.split() if "=" in x)
        if "mark" in kv:
            out.append([kv["mark"], int(kv.get("t", 0)), int(kv.get("dt", 0)), int(kv.get("vram", 0)), int(kv.get("wasm", 0))])
    return out

def _drop_shots(fs: list[float], ends: list[float], sw: list[list[float]]) -> tuple[list[float], int]:
    """A page screenshot stalls rAF as it returns: drop the frame spanning each shot's end, plus the next frame when it is over 100 ms (the settle)."""
    keep, n, after = [], 0, False
    for d, t in zip(fs, ends):
        if any(t - d <= b < t for _, b in sw):
            n, after = n + 1, True
            continue
        if after and d > 100:
            n, after = n + 1, False
            continue
        after = False
        keep.append(d)
    return keep, n

def _stats(fs: list[float], long_ms: float) -> dict:
    fs = sorted(fs) or [0.0]
    n = len(fs)
    return {"frames": n, "avg_fps": round(1000 / statistics.mean(fs), 1) if fs[-1] else 0,
            "avg_frame_ms": round(statistics.mean(fs), 1), "p95_frame_ms": round(fs[max(int(n * 0.95) - 1, 0)], 1),
            "max_frame_ms": round(fs[-1], 1), "long_frames": sum(1 for x in fs if x > long_ms)}

def measure(url: str, chrome: str, steps: list[dict], long_ms: float, timeout_s: int, size: tuple[int, int], out: Path,
            tag: str, mbps: float = 0.0, query: str = "", audio: bool = False, vsync: bool = False) -> dict:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as pw:
        br = pw.chromium.launch(executable_path=chrome, headless=True,
                                args=["--enable-precise-memory-info", "--use-gl=angle", "--use-angle=swiftshader",
                                      "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required"]
                                + ([] if vsync else UNCAP))
        ctx = br.new_context(viewport={"width": size[0], "height": size[1]}, device_scale_factor=1, service_workers="block")
        page = ctx.new_page()
        errs: list[str] = []
        page.on("pageerror", lambda e: errs.append(str(e)[:80]))
        page.add_init_script(INIT)
        if audio:
            page.add_init_script(AUDIO)
        cdp = ctx.new_cdp_session(page)
        page.__wp_cdp = cdp
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
        aud = page.evaluate("window.__wpAudio?window.__wpAudio():{}")
        m = {x["name"]: x["value"] for x in cdp.send("Performance.getMetrics")["metrics"]}
        res = page.evaluate("performance.getEntriesByType('resource').map(r=>[r.name.split('/').pop().split('?')[0],"
                            "r.transferSize||r.encodedBodySize||0,r.startTime,r.responseEnd])")
        br.close()
    tm = {n: (s, e) for n, _, s, e in res if n.endswith((".wasm", ".pck"))}
    wasm, pck = tm.get("index.wasm", (0, 0)), tm.get("index.pck", (0, 0))
    comp = max((e - s for k, s, e in w["comp"] if k != "compile"), default=0)
    gone = w["gone"]
    cut = {k: _drop_shots(v, w["e"].get(k, []), w["sw"]) for k, v in w["f"].items()}
    ph = {k: dict(_stats(v, long_ms), shot_excluded=n) for k, (v, n) in cut.items()}
    meas = [x for k, (v, _) in cut.items() if not k.startswith("_") for x in v]
    rep = {"load_ms": round(gone), "wall_ms": round(wall_ms), "wasm_dl_ms": round(wasm[1] - wasm[0]),
           "wasm_compile_ms": round(comp), "pck_end_ms": round(pck[1]), "init_ms": round(gone - max(pck[1], wasm[1])),
           **_stats(meas, long_ms), "shot_excluded": sum(n for k, (_, n) in cut.items() if not k.startswith("_")), "heap_mb": round(max(w["heap"], m.get("JSHeapUsedSize", 0)) / 1048576, 1),
           "wasm_mem_mb": round(w["wasm"] / 1048576, 1), "dom_nodes": int(m.get("Nodes", 0)),
           "transfer_mb": round(sum(b for _, b, _, _ in res) / 1048576, 2), "page_errors": len(errs) + w["errs"],
           "phases": ph, "marks": marks, "load_marks": _load_marks(w["load"]), "console_msgs": w["cmsg"], "console_errors": {k: v for k, v in w["cerr"].items() if not k.startswith("_")}, "audio": aud, "play": {k: play[k] for k in PLAY if k in play} if play else {}, "shots": shots,
           "assets": sorted(({"file": n, "kb": round(b / 1024)} for n, b, _, _ in res if b > 262144), key=lambda a: -a["kb"])}
    return rep
