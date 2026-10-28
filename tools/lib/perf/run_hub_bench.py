#!/usr/bin/env python3
"""Two hub bench walks, about 30 s each. Per-path Godot lock; never kills godot*.

    python tools/perf.py hub [--leg both|desktop|web] [--timeout-sec 240]
Desktop: a gl_compatibility window. Web: a local export in a visible Edge window
(Chrome if Edge is not installed). The web window keeps the browser frame cap
and GPU vsync. Neither leg is headless. --headless on the desktop leg is not
an FPS reading.
Summary: _logs/hub-bench/<stamp>-hub-bench.txt.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import bench_env
import godot_lib

def _read_rows(path: str) -> list[dict]:
    p = Path(path)
    if path == "" or not p.is_file():
        return []
    rows: list[dict] = []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            rows.append(row)
    return _latest_gen(rows)

def _latest_gen(rows: list[dict]) -> list[dict]:
    # bench_gen is the log generation. `gen` on a hitch row is the hub generated-node count.
    gens: list[int] = []
    for row in rows:
        if "bench_gen" not in row:
            continue
        try:
            gens.append(int(row["bench_gen"]))
        except (TypeError, ValueError):
            continue
    if not gens:
        return rows
    keep = max(gens)
    return [row for row in rows if int(row.get("bench_gen", -1)) == keep]

def _hitch_rows(path: str) -> list[dict]:
    return [row for row in _read_rows(path) if row.get("ev") == "hitch"]

def _hitches(path: str) -> list[dict]:
    rows = _hitch_rows(path)
    rows.sort(key=lambda r: float(r.get("dt_ms", 0) or 0), reverse=True)
    return rows

# Same window the game uses: project.godot is gl_compatibility / opengl3. No --headless,
# so the present path is in the frame time.
GUI_HEAD = ["--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]

def _field(line: str, key: str) -> str:
    token = key + "="
    if token not in line:
        return ""
    rest = line.split(token, 1)[1]
    if key == "path":
        return rest.strip()
    return rest.split()[0].strip()

def _hb_stat(lines: list[str]) -> dict:
    stat = {"ok": False, "fps_pct": 0.0, "frames": 0, "path": "", "sec": ""}
    for line in lines:
        if "ok=1" in line:
            stat["ok"] = True
        if "fps_pct=" in line:
            stat["fps_pct"] = float(_field(line, "fps_pct") or 0)
            stat["frames"] = int(float(_field(line, "frames") or 0))
            stat["sec"] = _field(line, "sec")
        if "path=" in line:
            stat["path"] = _field(line, "path")
    return stat

def _fps_fail(pct: float, frames: int) -> int:
    if frames <= 0:
        return 1
    return 0 if pct >= 99.0 else 1

# Chromium's --disable-frame-rate-limit also turns on --disable-gpu-vsync and
# drops present back-pressure. That combination bugchecked this GPU. Never pass them.
_GPU_UNCAP = ("--disable-frame-rate-limit", "--disable-gpu-vsync")
_PRESENT_KEYS = (
    "vsync", "max_fps", "refresh_hz", "paced", "renderer",
    "win_w", "win_h", "screen_w", "screen_h",
    "dt_p50_ms", "dt_p95_ms", "frames", "fps_pct",
    "pause_slow", "n_edge", "n_stutter", "n_spike", "slow_run_n", "slow_run_med_ms",
)

_KNOWN_GLES_LEAKS = ("N5GLES34MeshE", "N5GLES37TextureE")

def _is_known_gles_leak(line: str) -> bool:
    return "leaked at exit" in line and any(t in line for t in _KNOWN_GLES_LEAKS)

def _slow_lines(rows: list[dict]) -> list[str]:
    slow = []
    for row in rows:
        if int(row.get("paused", 0) or 0) == 1 or int(row.get("bar", 0) or 0) == 1:
            continue
        slow.append(
            "t=%s dt_ms=%s why=%s where=%s anim=%s ui=%s cell=%s proc_ms=%s phys_ms=%s draw=%s tree_ms=%s submit_ms=%s after_ms=%s"
            % (
                row.get("t", ""),
                row.get("dt_ms", ""),
                row.get("why", ""),
                row.get("where", ""),
                row.get("anim", ""),
                row.get("ui", ""),
                row.get("cell", ""),
                row.get("proc_ms", ""),
                row.get("phys_ms", ""),
                row.get("draw", ""),
                row.get("tree_ms", ""),
                row.get("submit_ms", ""),
                row.get("after_ms", ""),
            )
        )
        if len(slow) >= 8:
            break
    return slow

def _refresh_ms(bench: dict | None) -> float:
    hz = 60.0
    if bench and bench.get("refresh_hz"):
        try:
            hz = float(bench["refresh_hz"])
        except (TypeError, ValueError):
            hz = 60.0
    if hz <= 1.0:
        hz = 60.0
    return 1000.0 / hz

def _clusters(rows: list[dict]) -> list[list[dict]]:
    clusters: list[list[dict]] = []
    cur: list[dict] = []
    prev_t: float | None = None
    prev_frame: int | None = None
    for row in rows:
        try:
            t = float(row.get("t", 0) or 0)
        except (TypeError, ValueError):
            t = 0.0
        frame_raw = row.get("frame")
        frame: int | None = None
        if frame_raw is not None:
            try:
                frame = int(frame_raw)
            except (TypeError, ValueError):
                frame = None
        split = False
        if cur:
            if frame is not None and prev_frame is not None:
                split = frame - prev_frame > 2
            elif prev_t is not None and t - prev_t > 0.35:
                split = True
        if split and cur:
            clusters.append(cur)
            cur = []
        cur.append(row)
        prev_t = t
        if frame is not None:
            prev_frame = frame
    if cur:
        clusters.append(cur)
    return clusters

def _median(vals: list[float]) -> float:
    if not vals:
        return 0.0
    ordered = sorted(vals)
    return ordered[len(ordered) // 2]

def _run_line(rows: list[dict]) -> str:
    dts: list[float] = []
    anims: list[str] = []
    phases: list[str] = []
    cells: list[str] = []
    why_empty = 0
    held = 0
    paused = 0
    prev_proc = None
    phys_vals: list[float] = []
    draw_vals: list[float] = []
    tree_vals: list[float] = []
    submit_vals: list[float] = []
    after_vals: list[float] = []
    for row in rows:
        try:
            dts.append(float(row.get("dt_ms", 0) or 0))
        except (TypeError, ValueError):
            dts.append(0.0)
        anim = str(row.get("anim", ""))
        if anim and anim not in anims:
            anims.append(anim)
        phase = str(row.get("phase", ""))
        if phase and phase not in phases:
            phases.append(phase)
        cell = str(row.get("cell", ""))
        if cell:
            cells.append(cell)
        if not row.get("why"):
            why_empty += 1
        if int(row.get("paused", 0) or 0) == 1:
            paused += 1
        proc = row.get("proc_ms")
        if int(row.get("proc_held", 0) or 0) == 1 or (prev_proc is not None and proc == prev_proc):
            held += 1
        prev_proc = proc
        try:
            phys_vals.append(float(row.get("phys_ms", 0) or 0))
        except (TypeError, ValueError):
            phys_vals.append(0.0)
        try:
            draw_vals.append(float(row.get("draw", 0) or 0))
        except (TypeError, ValueError):
            draw_vals.append(0.0)
        for key, bucket in (("tree_ms", tree_vals), ("submit_ms", submit_vals), ("after_ms", after_vals)):
            try:
                bucket.append(float(row.get(key, 0) or 0))
            except (TypeError, ValueError):
                bucket.append(0.0)
    cell_txt = ""
    if cells:
        cell_txt = cells[0] if cells[0] == cells[-1] else "%s..%s" % (cells[0], cells[-1])
    return (
        "n=%d t=%s-%s play=%s-%s dt_med=%s phase=%s anim=%s cell=%s why_empty=%d proc_held=%d paused=%d phys_med=%s draw_med=%s tree_med=%s submit_med=%s after_med=%s"
        % (
            len(rows),
            rows[0].get("t", ""),
            rows[-1].get("t", ""),
            rows[0].get("play_s", ""),
            rows[-1].get("play_s", ""),
            _median(dts),
            ",".join(phases),
            ",".join(anims[:6]),
            cell_txt,
            why_empty,
            held,
            paused,
            _median(phys_vals),
            _median(draw_vals),
            _median(tree_vals),
            _median(submit_vals),
            _median(after_vals),
        )
    )

def _shape_lines(hitch_rows: list[dict], bench: dict | None) -> list[str]:
    refresh = _refresh_ms(bench)
    edge = 0
    stutter = 0
    spike = 0
    pause = 0
    bar = 0
    live: list[dict] = []
    for row in hitch_rows:
        if int(row.get("paused", 0) or 0) == 1:
            pause += 1
            continue
        if int(row.get("bar", 0) or 0) == 1:
            bar += 1
            continue
        live.append(row)
        try:
            dt = float(row.get("dt_ms", 0) or 0)
        except (TypeError, ValueError):
            dt = 0.0
        if dt >= 100.0:
            spike += 1
        elif dt >= refresh * 2.0:
            stutter += 1
        else:
            edge += 1
    lines = ["edge=%d stutter=%d spike=%d pause_rows=%d bar_rows=%d" % (edge, stutter, spike, pause, bar)]
    if bench and "slow_run_n" in bench:
        lines.append(
            "bench_run n=%s med_ms=%s pause_slow=%s"
            % (bench.get("slow_run_n", ""), bench.get("slow_run_med_ms", ""), bench.get("pause_slow", ""))
        )
    clusters = [cluster for cluster in _clusters(live) if len(cluster) >= 4]
    clusters.sort(key=len, reverse=True)
    if not clusters:
        lines.append("sustained=(none)")
        return lines
    lines.append("sustained:")
    for cluster in clusters[:3]:
        lines.append(_run_line(cluster))
    return lines

def _browser_notes(profile: Path) -> list[str]:
    """Console lines from the headed browser log. Not an FPS reading."""
    names = ("browser.log", "chrome_debug.log")
    found: list[Path] = []
    if profile.is_dir():
        for name in names:
            direct = profile / name
            if direct.is_file():
                found.append(direct)
        for child in profile.iterdir():
            if child.is_dir():
                for name in names:
                    nested = child / name
                    if nested.is_file():
                        found.append(nested)
    if not found:
        return ["browser_log=(missing)"]
    log_path = max(found, key=lambda item: item.stat().st_mtime)
    text = log_path.read_text(encoding="utf-8", errors="replace")
    keep: list[str] = []
    for line in text.splitlines():
        # Game output only. Browser-process ERRORs stay in the log file.
        if "index.js" not in line and "HB:" not in line and "SCRIPT ERROR" not in line:
            continue
        keep.append(line.strip()[:240])
    if not keep:
        return ["browser_log=%s bytes=%d console=(none)" % (log_path.name, log_path.stat().st_size)]
    out = ["browser_log=%s bytes=%d console_lines=%d" % (log_path.name, log_path.stat().st_size, len(keep))]
    out.extend(keep[-30:])
    return out

def _sink_tail(path: Path) -> list[str]:
    if not path.is_file():
        return ["sink=(missing)"]
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = [line for line in text.splitlines() if line.strip()]
    out = ["sink_bytes=%d rows=%d" % (path.stat().st_size, len(lines))]
    for line in lines[-6:]:
        out.append(line[:240])
    return out

def _hb_lines(rows: list[dict]) -> list[str]:
    out: list[str] = []
    for row in rows:
        if row.get("ev") == "hb" and row.get("msg"):
            out.append(str(row["msg"]))
    return out

def _present_line(row: dict | None) -> str:
    if not row:
        return "present=(no bench row)"
    return (
        "present vsync=%s max_fps=%s refresh_hz=%s paced=%s renderer=%s win=%sx%s screen=%sx%s dt_p50_ms=%s dt_p95_ms=%s"
        % (
            row.get("vsync", ""),
            row.get("max_fps", ""),
            row.get("refresh_hz", ""),
            row.get("paced", ""),
            row.get("renderer", ""),
            row.get("win_w", ""),
            row.get("win_h", ""),
            row.get("screen_w", ""),
            row.get("screen_h", ""),
            row.get("dt_p50_ms", ""),
            row.get("dt_p95_ms", ""),
        )
    )

def _present_fail(row: dict | None) -> int:
    if not row:
        return 1
    for key in _PRESENT_KEYS:
        if key not in row:
            return 1
    return 0

def _bench_row(path: Path) -> dict | None:
    found = None
    for row in _read_rows(str(path)):
        if row.get("ev") == "bench":
            found = row
    return found

def _profile_pids(profile: Path) -> list[int]:
    needle = str(profile).replace("'", "''")
    script = (
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.CommandLine -and $_.CommandLine.Contains('%s') } | "
        "ForEach-Object { $_.ProcessId }"
        % needle
    )
    found = subprocess.run(
        ["powershell", "-NoProfile", "-Command", script],
        capture_output=True, text=True,
    )
    pids: list[int] = []
    for line in (found.stdout or "").splitlines():
        line = line.strip()
        if line.isdigit():
            pids.append(int(line))
    return pids

def _clear_gpu_shader_caches() -> list[str]:
    """Driver shader caches survive a new Edge profile. A warm GPU reports the cached number."""
    local = os.environ.get("LOCALAPPDATA", "")
    if not local:
        return []
    cleared: list[str] = []
    for rel in (
        "D3DSCache",
        "NVIDIA Corporation/NV_Cache",
        "NVIDIA/GLCache",
        "NVIDIA/DXCache",
        "NVIDIA Corporation/DXCache",
    ):
        path = Path(local) / rel
        if not path.exists():
            continue
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)
        if not path.exists():
            cleared.append(rel)
    return cleared

def _stop_profile(profile: Path) -> None:
    for pid in _profile_pids(profile):
        subprocess.run(
            ["powershell", "-NoProfile", "-Command", "Stop-Process -Id %d -Force -ErrorAction SilentlyContinue" % pid],
            capture_output=True,
        )

def _desktop(
    root: Path,
    args,
    out_log: Path,
    err_log: Path,
    flag: str = "--wdb-hub-bench",
    fresh_name: str = "hub-bench-fresh",
    label: str = "hub bench",
    extra: list[str] | None = None,
) -> tuple[int, list[str]]:
    kind = "headless" if args.headless else godot_lib.pick_display()[0]
    gui = kind != "headless" and kind != "none"
    fresh = Path(root) / "_logs" / fresh_name
    if fresh.exists():
        shutil.rmtree(fresh)
    fresh.mkdir(parents=True)
    print("Running %s desktop (display=%s, fresh=%s)..." % (label, kind, fresh))
    user = [flag, "--wdb-hitch-mult=1"]
    if extra:
        user.extend(extra)
    gargs = (
        godot_lib.headless_args(root, *user)
        if not gui
        else GUI_HEAD + ["--path", str(root), "--", *user]
    )
    # Fresh user:// (the bench refuses a warm save): APPDATA on Windows, XDG_DATA_HOME on Linux.
    old = {k: os.environ.get(k) for k in ("APPDATA", "XDG_DATA_HOME")}
    os.environ.update({k: str(fresh) for k in old})
    try:
        r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=gui)
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    hb = godot_lib.grep_logs([err_log, out_log], r"^HB:")
    errs = godot_lib.grep_logs(
        [err_log, out_log],
        r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to|Lambda capture at index",
    )
    stat = _hb_stat(hb)
    bench = _bench_row(Path(stat["path"])) if stat["path"] else None
    ordered = _hitch_rows(stat["path"]) if stat["path"] else []
    rows = sorted(ordered, key=lambda r: float(r.get("dt_ms", 0) or 0), reverse=True)
    slow = _slow_lines(rows)
    fail = int(r["status"] == "TIMEOUT")
    fail += int(r["status"].startswith("EXIT=") and r["status"] != "EXIT=0")
    fail += int(bool(errs)) + int(not stat["ok"])
    fail += _present_fail(bench)
    if args.headless:
        fail += 1
    else:
        fail += _fps_fail(stat["fps_pct"], stat["frames"])
    body = [
        "desktop root=.",
        "status=%s wall_ms=%s errBytes=%s outBytes=%s headed=%s" % (
            r["status"], r["ms"], r["err_bytes"], r["out_bytes"], 0 if args.headless else 1,
        ),
        "fps_pct=%s frames=%s sec=%s bar=99" % (stat["fps_pct"], stat["frames"], stat["sec"]),
        _present_line(bench),
        "",
        "--- HB lines ---",
    ]
    body += hb or ["(no HB: lines)"]
    body += ["", "--- slow shape ---"] + _shape_lines(ordered, bench)
    body += ["", "--- slowest hitches ---"] + (slow or ["(none)"])
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    if args.headless:
        body.append("headless is not an FPS reading")
    return fail, body

def _fresh_web_site(root: Path, prefix: str = "hub-bench-web") -> Path:
    """A new folder every run. The same path on port 8060 is the service worker's scope."""
    logs = root / "_logs"
    logs.mkdir(parents=True, exist_ok=True)
    for old in logs.glob(prefix + "*"):
        if old.is_dir():
            shutil.rmtree(old, ignore_errors=True)
    return logs / ("%s-%s" % (prefix, time.strftime("%Y%m%d-%H%M%S")))

def _web(
    root: Path,
    args,
    flag: str = "--wdb-hub-bench",
    site_prefix: str = "hub-bench-web",
    profile_name: str = "hub-bench-browser",
    label: str = "hub bench",
    extra_query: str = "",
) -> tuple[int, list[str]]:
    import hitch_sink
    import web_perf_lib

    fill_aba = bool(getattr(args, "fill_aba", False))
    walk_layers = bool(getattr(args, "walk_layers", False))
    isolate = bool(getattr(args, "isolate", False))
    browser, kind = web_perf_lib.find_browser(args.browser)
    if not browser:
        return 1, ["web", "no Edge or Chrome: pass --browser or set CHROME_BIN"]
    site = _fresh_web_site(root, site_prefix)
    print("Exporting web build for %s -> %s" % (label, site))
    exp = subprocess.run(
        [*boot.cmd("export_web"), "--debug", "--out", str(site)],
        cwd=str(root),
        capture_output=True,
        text=True,
    )
    for ln in (exp.stdout or "").splitlines():
        if ln.startswith("RESULT"):
            print(ln)
    if exp.returncode != 0 or not (site / "index.html").is_file():
        return 1, ["web export failed exit=%s site=%s" % (exp.returncode, site)]
    hitch = Path(root) / "_logs" / "web-perf" / "hitch.jsonl"
    if hitch.exists():
        hitch.unlink()
    profile = Path(root) / "_logs" / profile_name
    _stop_profile(profile)
    if profile.exists():
        shutil.rmtree(profile, ignore_errors=True)
    profile.mkdir(parents=True)
    cleared = _clear_gpu_shader_caches()
    print("shader_cache_cleared=%s" % (",".join(cleared) if cleared else "none"))
    try:
        srv = hitch_sink.serve(site, root, 0)
    except OSError as exc:
        return 1, ["web", "hitch sink failed: %s" % exc]
    port = int(srv.server_address[1])
    ready = False
    for _ in range(20):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.25):
                ready = True
                break
        except OSError:
            time.sleep(0.1)
    if not ready:
        return 1, ["web", "hitch sink not listening on %d" % port]
    qflag = flag[2:] if flag.startswith("--") else flag
    url = "http://127.0.0.1:%d/index.html?%s&wdb-hitch-mult=1%s" % (port, qflag, extra_query)
    if fill_aba:
        url += "&wdb-hub-fill-aba"
    elif walk_layers:
        url += "&wdb-hub-walk-layers"
    elif isolate:
        url += "&wdb-hub-isolate"
    print("Running %s web (browser=%s kind=%s headed=1 cap=1 fullscreen=1 url=%s)..." % (label, Path(browser).name, kind, url))
    # Fullscreen at device pixels. A 1280x720 window makes the adaptive canvas
    # render small. These flags do not disable GPU vsync or the frame cap.
    argv = [
        browser,
        "--user-data-dir=" + str(profile),
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-sync",
        "--edge-skip-compat-layer-relaunch",
        "--disable-gpu-shader-disk-cache",
        "--disable-extensions",
        "--autoplay-policy=no-user-gesture-required",
        "--new-window",
        "--start-fullscreen",
        "--force-device-scale-factor=1",
        "--enable-logging",
        "--log-file=" + str(profile / "browser.log"),
        url,
    ]
    for flag in _GPU_UNCAP:
        if flag in argv:
            srv.shutdown()
            return 1, ["web", "refusing %s; the browser frame cap and GPU vsync stay on" % flag]
    proc = subprocess.Popen(argv)
    _raise_bench_window(proc)
    row = None
    started = time.time()
    limit = max(args.timeout_sec, 180)
    deadline = started + limit
    cap = started + limit + 180
    # Edge's starter process often exits after it hands the window to a child.
    # That exit is not the window dying. Wait for the bench row, or until no
    # process still has this profile. A growing sink means the page is still
    # inside a long frame, so the deadline moves forward up to three minutes.
    grace_until = time.time() + 8.0
    next_pid_check = 0.0
    last_size = -1
    try:
        while time.time() < deadline:
            row = _bench_row(hitch)
            if row is not None:
                break
            size = hitch.stat().st_size if hitch.is_file() else 0
            if size != last_size:
                last_size = size
                deadline = min(cap, max(deadline, time.time() + 30))
            if proc.poll() is not None and time.time() >= next_pid_check:
                next_pid_check = time.time() + 2.0
                alive = _profile_pids(profile)
                if not alive and time.time() > grace_until:
                    time.sleep(1.0)
                    row = _bench_row(hitch)
                    break
            time.sleep(0.5)
    finally:
        launcher_exit = proc.poll()
        _stop_profile(profile)
        if proc.poll() is None:
            proc.terminate()
        srv.shutdown()
    if row is None:
        why = "timed out" if time.time() >= deadline else "browser process exited"
        return 1, [
            "web",
            "browser=%s kind=%s headed=1 fullscreen=1" % (Path(browser).name, kind),
            "no bench row (%s) launcher_exit=%s" % (why, launcher_exit),
        ] + _sink_tail(hitch) + _browser_notes(profile)
    pct = float(row.get("fps_pct", 0))
    frames = int(row.get("frames", 0))
    ok = int(row.get("ok", 0)) == 1
    ordered_all = _read_rows(str(hitch))
    isolate_lines = [
        str(item.get("msg", ""))
        for item in ordered_all
        if "isolate layer=" in str(item.get("msg", ""))
    ]
    if isolate or walk_layers or fill_aba:
        fail = 0 if isolate_lines else 1
    else:
        fail = int(not ok) + _fps_fail(pct, frames) + _present_fail(row)
    ordered = [item for item in ordered_all if item.get("ev") == "hitch"]
    rows = sorted(ordered, key=lambda r: float(r.get("dt_ms", 0) or 0), reverse=True)
    slow = _slow_lines(rows)
    body = [
        "web browser=%s kind=%s headed=1 cap=1" % (Path(browser).name, kind),
        "fps_pct=%s frames=%s slow=%s sec=%s ok=%s worst=%s bar=99" % (
            pct, frames, row.get("slow", ""), row.get("sec", ""), row.get("ok", ""), row.get("worst_ms", ""),
        ),
        _present_line(row),
        "",
        "--- HB lines ---",
    ]
    body += _hb_lines(ordered_all) or ["(no HB: lines)"]
    body += ["", "--- slow shape ---"] + _shape_lines(ordered, row)
    body += ["", "--- slowest hitches ---"] + (slow or ["(none)"])
    if fill_aba:
        body.append(_aba_line(isolate_lines))
    notes = _browser_notes(profile)
    if any("ERROR" in line.upper() or "WASM" in line.upper() for line in notes):
        body += ["", "--- browser console ---"] + notes
    return fail, body

def _layer_fields(lines: list[str]) -> list[tuple[str, float, int]]:
    found: list[tuple[str, float, int]] = []
    for ln in lines:
        kind = ""
        submit = ""
        count = ""
        for part in ln.split():
            if part.startswith("layer="):
                kind = part.split("=", 1)[1]
            elif part.startswith("submit="):
                submit = part.split("=", 1)[1]
            elif part.startswith("n="):
                count = part.split("=", 1)[1]
        if not kind or not submit:
            continue
        try:
            found.append((kind, float(submit), int(count or "0")))
        except ValueError:
            continue
    return found

def _aba_line(lines: list[str]) -> str:
    """base, bare, base2 submit medians. keep=1 only when the first fill stays near 40 ms."""
    fields = _layer_fields(lines)
    picked: dict[str, tuple[float, int]] = {}
    for kind, submit, count in fields:
        if kind in ("base", "bare", "base2") and kind not in picked:
            picked[kind] = (submit, count)
    base = picked.get("base")
    bare = picked.get("bare")
    base2 = picked.get("base2")
    keep = 0
    if base is not None and bare is not None and base2 is not None and base[0] >= 30.0 and base[1] >= 20:
        keep = 1
    def cell(row: tuple[float, int] | None) -> str:
        if row is None:
            return "missing"
        return "%.1f" % row[0]
    return "aba base=%s bare=%s base2=%s keep=%d" % (cell(base), cell(bare), cell(base2), keep)

def _echo_lines(lines: list[str]) -> list[str]:
    keep = []
    for ln in lines:
        if ln.startswith(("status=", "fps_pct=", "edge=", "leg=", "desktop root=", "web browser=")):
            keep.append(ln)
        elif "isolate layer=" in ln or ln.startswith("HB: isolate") or ln.startswith("aba "):
            keep.append(ln)
        elif ln.startswith("sustained=") or ln.startswith("sustained:"):
            keep.append(ln)
    return keep or lines[:4]

def _retry_lines(lines: list[str]) -> list[str]:
    keep = []
    for ln in lines:
        if ln.startswith(("fps_pct=", "edge=", "no bench row", "hitch sink")):
            keep.append(ln)
    return keep or ["(no structured fail line)"]

def _raise_bench_window(proc: subprocess.Popen) -> None:
    if sys.platform != "win32":
        return
    try:
        import ctypes
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        found = []
        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def _enum(hwnd, _lparam):
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == proc.pid and user32.IsWindowVisible(hwnd):
                found.append(hwnd)
            return True
        for _ in range(40):
            found.clear()
            user32.EnumWindows(_enum, 0)
            if found:
                break
            time.sleep(0.1)
        if not found:
            return
        hwnd = found[0]
        fg = user32.GetForegroundWindow()
        fg_thread = user32.GetWindowThreadProcessId(fg, None) if fg else 0
        this_thread = kernel32.GetCurrentThreadId()
        if fg_thread and fg_thread != this_thread:
            user32.AttachThreadInput(fg_thread, this_thread, True)
        user32.ShowWindow(hwnd, 9)
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
        if fg_thread and fg_thread != this_thread:
            user32.AttachThreadInput(fg_thread, this_thread, False)
    except Exception:
        pass

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Two ~30s hub bench walks (desktop window and a visible web export), plus a hitch summary.", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=240, help="Desktop Godot timeout, and the web wait after export (default 240).")
    ap.add_argument("--headless", action="store_true", help="desktop driver only; not an FPS reading")
    ap.add_argument("--leg", choices=("both", "desktop", "web"), default="both", help="Which walks to run (default both).")
    ap.add_argument("--browser", default="", help="Force the web window binary. Default: Edge if installed, else Chrome.")
    ap.add_argument("--report", default="", help="Reprint slow shape and HB lines from a hitch JSONL. Does not launch a walk.")
    ap.add_argument("--layers", dest="isolate", action="store_true", help="Web only: stand at the dummy and time each hidden layer group. Does not score the 99 percent bar.")
    ap.add_argument("--isolate", dest="isolate", action="store_true", help=argparse.SUPPRESS)  # old name of --layers
    ap.add_argument("--walk-layers", action="store_true", help="Web only: run the full bench, then time each hidden layer during the fill walk. Does not score the 99 percent bar.")
    ap.add_argument("--fill-aba", action="store_true", help="Web only: full walk, then during the fill time normal, all groups hidden, normal again. Does not score the 99 percent bar. Keep it only when the first fill submit stays near 40 ms.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.report:
        if not Path(args.report).is_file():
            msg = "error: --report file not found: %s" % args.report
            return agent_log.finish("hub-bench-report", root, msg, "FAIL", args=args, legacy=False, echo=msg)
        ordered = _read_rows(args.report)
        bench = None
        for item in ordered:
            if item.get("ev") == "bench":
                bench = item
        hitch_rows = [item for item in ordered if item.get("ev") == "hitch"]
        ranked = sorted(hitch_rows, key=lambda r: float(r.get("dt_ms", 0) or 0), reverse=True)
        report = [
            "hub bench report",
            "path=%s" % args.report,
            _present_line(bench),
            "",
            "--- HB lines ---",
        ]
        report += _hb_lines(ordered) or ["(no HB: lines)"]
        report += ["", "--- slow shape ---"] + _shape_lines(hitch_rows, bench)
        report += ["", "--- slowest hitches ---"] + (_slow_lines(ranked) or ["(none)"])
        return agent_log.finish(
            "hub-bench-report",
            root,
            "\n".join(report),
            "PASS",
            args=args,
            legacy=False,
            echo="\n".join(report),
            fail_signals=0,
        )
    out_log = agent_log.run_path("hub-bench", root, "out.log")
    err_log = agent_log.run_path("hub-bench", root, "err.log")
    fail = 0
    body = ["hub bench root=.", "leg=%s" % args.leg]
    body.append(bench_env.env_line(godot=bench_env.godot_version(str(godot_lib.godot_exe())), renderer="gl_compatibility",
        browser="see web leg" if args.leg in ("both", "web") else "n/a", vsync="see present line", cap="max_fps 120", headless=bool(args.headless)))
    if args.leg in ("both", "desktop") and not args.isolate and not args.walk_layers and not args.fill_aba:
        d_fail, d_body = _desktop(root, args, out_log, err_log)
        fail += d_fail
        body += d_body
    if args.leg in ("both", "web") or args.isolate or args.walk_layers or args.fill_aba:
        w_fail, w_body = _web(root, args)
        fail += w_fail
        body += w_body
    echo = _echo_lines(body)
    summary_dir = root / "_logs" / "hub-bench"
    summary_dir.mkdir(parents=True, exist_ok=True)
    (summary_dir / "summary.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
    return agent_log.finish(
        "hub-bench",
        root,
        "\n".join(body),
        "FAIL" if fail else "PASS",
        args=args,
        legacy=False,
        echo="\n".join(echo),
        retry=("hub-bench", _retry_lines(body)),
        fail_signals=fail,
    )

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
