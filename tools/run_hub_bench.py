#!/usr/bin/env python3
"""Two hub bench walks, about 30 s each. Per-path Godot lock; never kills godot*.

    python tools/run_hub_bench.py [--leg both|desktop|web] [--timeout-sec 240]
Desktop: a gl_compatibility window. Web: a local export in a visible Edge window
(Chrome if Edge is not installed). The web window keeps the browser frame cap
and GPU vsync. Neither leg is headless. --headless on the desktop leg is not
an FPS reading.
Summary: _logs/hub-bench/<stamp>-hub-bench.txt.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def _hitches(path: str) -> list[dict]:
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
        if isinstance(row, dict) and row.get("ev") == "hitch":
            rows.append(row)
    rows.sort(key=lambda r: float(r.get("dt_ms", 0)), reverse=True)
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


def _slow_lines(rows: list[dict]) -> list[str]:
    slow = []
    for row in rows[:8]:
        slow.append(
            "dt_ms=%s why=%s where=%s anim=%s ui=%s cell=%s"
            % (
                row.get("dt_ms", ""),
                row.get("why", ""),
                row.get("where", ""),
                row.get("anim", ""),
                row.get("ui", ""),
                row.get("cell", ""),
            )
        )
    return slow


def _bench_row(path: Path) -> dict | None:
    if not path.is_file():
        return None
    found = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict) and row.get("ev") == "bench":
            found = row
    return found


def _stop_profile(profile: Path) -> None:
    needle = str(profile).replace("'", "''")
    script = (
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.CommandLine -and $_.CommandLine.Contains('%s') } | "
        "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
        % needle
    )
    subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True)


def _desktop(root: Path, args, out_log: Path, err_log: Path) -> tuple[int, list[str]]:
    kind = "headless" if args.headless else godot_lib.pick_display()[0]
    gui = kind != "headless" and kind != "none"
    fresh = Path(root) / "_logs" / "hub-bench-fresh"
    if fresh.exists():
        shutil.rmtree(fresh)
    fresh.mkdir(parents=True)
    print("Running hub bench desktop (display=%s, fresh=%s)..." % (kind, fresh))
    gargs = (
        godot_lib.headless_args(root, "--wdb-hub-bench", "--wdb-hitch-mult=1")
        if not gui
        else GUI_HEAD + ["--path", str(root), "--", "--wdb-hub-bench", "--wdb-hitch-mult=1"]
    )
    old_appdata = os.environ.get("APPDATA")
    os.environ["APPDATA"] = str(fresh)
    try:
        r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=gui)
    finally:
        if old_appdata is None:
            os.environ.pop("APPDATA", None)
        else:
            os.environ["APPDATA"] = old_appdata
    hb = godot_lib.grep_logs([err_log, out_log], r"^HB:")
    errs = godot_lib.grep_logs(
        [err_log, out_log],
        r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to|Lambda capture at index",
    )
    stat = _hb_stat(hb)
    rows = _hitches(stat["path"])
    slow = _slow_lines(rows)
    fail = int(r["status"] == "TIMEOUT")
    fail += int(r["status"].startswith("EXIT=") and r["status"] != "EXIT=0")
    fail += int(bool(errs)) + int(not stat["ok"])
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
        "",
        "--- HB lines ---",
    ]
    body += hb or ["(no HB: lines)"]
    body += ["", "--- slowest hitches ---"] + (slow or ["(none)"])
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    if args.headless:
        body.append("headless is not an FPS reading")
    return fail, body


def _web(root: Path, args) -> tuple[int, list[str]]:
    import hitch_sink
    import web_perf_lib

    browser, kind = web_perf_lib.find_browser(args.browser)
    if not browser:
        return 1, ["web", "no Edge or Chrome: pass --browser or set CHROME_BIN"]
    site = Path(root) / "_logs" / "hub-bench-web"
    print("Exporting web build for hub bench -> %s" % site)
    if site.exists():
        shutil.rmtree(site)
    exp = subprocess.run(
        [sys.executable, str(Path(__file__).resolve().parent / "export_web.py"), "--out", str(site)],
        cwd=str(root),
    )
    if exp.returncode != 0 or not (site / "index.html").is_file():
        return 1, ["web export failed exit=%s site=%s" % (exp.returncode, site)]
    hitch = Path(root) / "_logs" / "web-perf" / "hitch.jsonl"
    if hitch.exists():
        hitch.unlink()
    profile = Path(root) / "_logs" / "hub-bench-browser"
    _stop_profile(profile)
    if profile.exists():
        shutil.rmtree(profile, ignore_errors=True)
    profile.mkdir(parents=True)
    try:
        srv = hitch_sink.serve(site, root, 8060)
    except OSError as exc:
        return 1, ["web", "hitch sink failed: %s" % exc]
    port = int(srv.server_address[1])
    url = "http://127.0.0.1:%d/index.html?wdb-hub-bench&wdb-hitch-mult=1" % port
    print("Running hub bench web (browser=%s kind=%s headed=1 cap=1 url=%s)..." % (Path(browser).name, kind, url))
    proc = subprocess.Popen(
        [
            browser,
            "--user-data-dir=" + str(profile),
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--autoplay-policy=no-user-gesture-required",
            "--new-window",
            "--window-size=1280,720",
            url,
        ]
    )
    row = None
    deadline = time.time() + max(args.timeout_sec, 180)
    try:
        while time.time() < deadline:
            row = _bench_row(hitch)
            if row is not None:
                break
            if proc.poll() is not None and row is None:
                time.sleep(1.0)
                row = _bench_row(hitch)
                break
            time.sleep(0.5)
    finally:
        _stop_profile(profile)
        if proc.poll() is None:
            proc.terminate()
        srv.shutdown()
    if row is None:
        return 1, ["web", "browser=%s kind=%s headed=1" % (Path(browser).name, kind), "no bench row (window did not finish)"]
    pct = float(row.get("fps_pct", 0))
    frames = int(row.get("frames", 0))
    ok = int(row.get("ok", 0)) == 1
    fail = int(not ok) + _fps_fail(pct, frames)
    rows = [r for r in _hitches(str(hitch))]
    slow = _slow_lines(rows)
    body = [
        "web browser=%s kind=%s headed=1 cap=1" % (Path(browser).name, kind),
        "fps_pct=%s frames=%s slow=%s sec=%s ok=%s worst=%s bar=99" % (
            pct, frames, row.get("slow", ""), row.get("sec", ""), row.get("ok", ""), row.get("worst_ms", ""),
        ),
        "",
        "--- slowest hitches ---",
    ]
    body += slow or ["(none)"]
    return fail, body


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Two ~30s hub bench walks (desktop window and a visible web export), plus a hitch summary.", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=240, help="Desktop Godot timeout, and the web wait after export (default 240).")
    ap.add_argument("--headless", action="store_true", help="desktop driver only; not an FPS reading")
    ap.add_argument("--leg", choices=("both", "desktop", "web"), default="both", help="Which walks to run (default both).")
    ap.add_argument("--browser", default="", help="Force the web window binary. Default: Edge if installed, else Chrome.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    out_log = agent_log.run_path("hub-bench", root, "out.log")
    err_log = agent_log.run_path("hub-bench", root, "err.log")
    fail = 0
    body = ["hub bench root=.", "leg=%s" % args.leg]
    if args.leg in ("both", "desktop"):
        d_fail, d_body = _desktop(root, args, out_log, err_log)
        fail += d_fail
        body += d_body
    if args.leg in ("both", "web"):
        w_fail, w_body = _web(root, args)
        fail += w_fail
        body += w_body
    echo = body[:8]
    return agent_log.finish(
        "hub-bench",
        root,
        "\n".join(body),
        "FAIL" if fail else "PASS",
        args=args,
        legacy=False,
        echo="\n".join(echo),
        retry=("hub-bench", body),
        fail_signals=fail,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
