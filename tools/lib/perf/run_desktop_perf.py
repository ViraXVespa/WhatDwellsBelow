#!/usr/bin/env python3
"""Desktop release vs debug perf: drive exported Linux builds with OS-level keys, time frames from outside the game.

    python tools/perf.py desktop [--builds release,debug] [--export] [--sec 8] [--runs 1] [--write-md]

Builds: preset `Linux` (release template, no scripts/debug, no _*) -> _out/linux/, preset `Linux Debug` (debug template,
debug code kept) -> _out/linux-debug/. `--export` re-exports both first (binaries stay in untracked _out/).
Each run starts its own Xvfb display (1920x1080, GLX, software GL), an empty XDG_DATA_HOME (no real save), launches
the build with the engine's `--print-fps` (release-safe; one `Project FPS: N (X mspf)` line a second) and drives it with
xdotool keys only: title idle, Enter (Play) -> hub, camp idle, camp walk (d/a loop on the spawn road), W to the Floor Crystal, E, Enter
(Enter dungeon) -> dungeon idle, dungeon walk (WASD box). The dungeon seed is random per run. Each phase keeps the 1-second samples inside its window and reports
mean mspf and the worst 1-second mspf. Load phases report seconds from the key press to the first sample after it
that is within 25% of the next phase's median (approximate). A screenshot per phase lands in _logs/desktop-perf/ so the
route can be checked by eye. Not a gate; software GL; compare only within one `machine=` (design/benchmarks/README.md).
--write-md appends the table to design/benchmarks/desktop-release.md with the bench_env line.
"""
from __future__ import annotations

import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import bench_env

FPS_RE = re.compile(r"Project FPS: (\d+) \(([\d.]+) mspf\)")
BUILDS = {"release": ("Linux", "_out/linux/wdb.x86_64", "--export-release"),
          "debug": ("Linux Debug", "_out/linux-debug/wdb.x86_64", "--export-debug")}
PHASES = ["title-idle", "camp-idle", "camp-walk", "dungeon-idle", "dungeon-walk"]


def export(root: Path, godot: str, name: str) -> None:
    preset, out, flag = BUILDS[name]
    (root / out).parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([godot, "--headless", "--path", str(root), flag, preset, str(root / out)],
                       capture_output=True, text=True, timeout=900)
    if r.returncode != 0 or not (root / out).is_file():
        raise SystemExit("export failed for %s: %s" % (preset, r.stderr[-800:]))


class Run:
    def __init__(self, root: Path, binary: Path, disp: int, shots: Path, tag: str) -> None:
        self.env = dict(os.environ, DISPLAY=":%d" % disp)
        self.home = tempfile.mkdtemp(prefix="wdb-perf-")
        self.env["XDG_DATA_HOME"] = self.home
        self.xvfb = subprocess.Popen(["Xvfb", ":%d" % disp, "-screen", "0", "1920x1080x24", "+extension", "GLX"],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2)
        self.samples: list[tuple[float, float]] = []
        pre = ["stdbuf", "-oL"] if shutil.which("stdbuf") else []  # release stdout is block-buffered on a pipe
        self.game = subprocess.Popen([*pre, str(binary), "--print-fps", "--resolution", "1920x1080"], env=self.env,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        threading.Thread(target=self._read, daemon=True).start()
        self.disp, self.shots, self.tag = disp, shots, tag
        self.marks: dict[str, tuple[float, float]] = {}

    def _read(self) -> None:
        for line in self.game.stdout:
            m = FPS_RE.search(line)
            if m:
                self.samples.append((time.monotonic(), float(m.group(2))))

    def key(self, *args: str) -> None:
        subprocess.run(["xdotool", *args], env=self.env, check=False)

    def hold(self, k: str, sec: float) -> None:
        self.key("keydown", k)
        time.sleep(sec)
        self.key("keyup", k)

    def shot(self, name: str) -> None:
        try:
            from PIL import ImageGrab
            ImageGrab.grab(xdisplay=":%d" % self.disp).save(self.shots / ("%s-%s.png" % (self.tag, name)))
        except Exception:  # noqa: BLE001 - a missing screenshot never fails the timing
            pass

    def phase(self, name: str, sec: float, act=None) -> None:
        t0 = time.monotonic()
        if act:
            act()
        while time.monotonic() - t0 < sec:
            time.sleep(0.1)
        self.marks[name] = (t0 + 1.0, time.monotonic())
        self.shot(name)

    def stats(self, name: str) -> dict:
        a, b = self.marks.get(name, (0, 0))
        ms = [v for t, v in self.samples if a <= t <= b]
        if not ms:
            return {"n": 0}
        return {"n": len(ms), "mean": statistics.mean(ms), "worst": max(ms)}

    def load_s(self, t_press: float, after: str) -> float | None:
        ref = self.stats(after)
        if not ref.get("n"):
            return None
        for t, v in self.samples:
            if t > t_press + 0.5 and v <= ref["mean"] * 1.25:
                return t - t_press
        return None

    def close(self) -> None:
        for p in (self.game, self.xvfb):
            p.terminate()
            try:
                p.wait(10)
            except subprocess.TimeoutExpired:
                p.kill()
        shutil.rmtree(self.home, ignore_errors=True)


def walk(r: Run, legs: list[tuple[str, float]]) -> None:
    """Hold each key in turn (blocking). Camp uses a closed d/a loop on the open spawn road so the crystal trip after
    it starts from spawn; the dungeon uses a WASD box (walls may cut it short)."""
    for k, s in legs:
        r.hold(k, s)


def one(root: Path, name: str, sec: float, disp: int, shots: Path, idx: int) -> dict:
    r = Run(root, root / BUILDS[name][1], disp, shots, "%s%d" % (name, idx))
    try:
        time.sleep(8)
        r.phase("title-idle", sec)
        t_hub = time.monotonic()
        r.key("key", "Return")
        time.sleep(15)
        r.phase("camp-idle", sec)
        r.phase("camp-walk", sec, lambda: walk(r, [("d", 1.0), ("a", 2.0), ("d", 1.0)] * max(1, int(sec // 4))))
        time.sleep(1.0)
        r.hold("w", 1.35)
        time.sleep(0.4)
        r.key("key", "e")
        time.sleep(2)
        r.shot("loadout")
        t_dun = time.monotonic()
        r.key("key", "Return")
        time.sleep(20)
        r.phase("dungeon-idle", sec)
        r.phase("dungeon-walk", sec, lambda: walk(r, [("d", 1.0), ("s", 1.0), ("a", 1.0), ("w", 1.0)] * max(1, int(sec // 4))))
        out = {p: r.stats(p) for p in PHASES}
        out["hub-load"] = r.load_s(t_hub, "camp-idle")
        out["dungeon-load"] = r.load_s(t_dun, "dungeon-idle")
        return out
    finally:
        r.close()


def fmt(s: dict) -> str:
    return "%.1f / %.1f" % (s["mean"], s["worst"]) if s.get("n") else "n/a"


def table(res: dict[str, list[dict]]) -> list[str]:
    names = list(res)
    head = "| Phase | " + " | ".join(n.capitalize() + " (mean / worst 1 s mspf)" for n in names) + " |"
    lines = [head, "|---|" + "---|" * len(names)]
    for p in PHASES:
        cells = []
        for n in names:
            runs = [x[p] for x in res[n] if x[p].get("n")]
            cells.append(fmt({"n": len(runs), "mean": statistics.median([x["mean"] for x in runs]),
                              "worst": statistics.median([x["worst"] for x in runs])}) if runs else "n/a")
        lines.append("| %s | %s |" % (p, " | ".join(cells)))
    for p in ("hub-load", "dungeon-load"):
        cells = []
        for n in names:
            v = [x[p] for x in res[n] if x[p] is not None]
            cells.append("%.1f s" % statistics.median(v) if v else "n/a")
        lines.append("| %s (approx) | %s |" % (p, " | ".join(cells)))
    return lines


def main() -> int:
    ap = agent_log.std_parser(__doc__.splitlines()[0], writes=True)
    ap.add_argument("--builds", default="release,debug", help="Comma-separated builds to measure (default release,debug).")
    ap.add_argument("--export", action="store_true", help="re-export the builds first")
    ap.add_argument("--sec", type=float, default=8.0, help="seconds per measured phase")
    ap.add_argument("--runs", type=int, default=1, help="Repeat each build this many times (default 1).")
    ap.add_argument("--write-md", action="store_true", help="append the table to design/benchmarks/desktop-release.md")
    args = ap.parse_args()
    root = agent_log.resolve_root(args)
    names = [n for n in args.builds.split(",") if n]
    for n in names:
        if n not in BUILDS:
            raise SystemExit("unknown build " + n)
    for tool in ("Xvfb", "xdotool"):
        if not shutil.which(tool):
            raise SystemExit("missing " + tool)
    godot = os.environ.get("WDB_GODOT", "/workspace/godot/Godot_v4.7.2-stable_linux.x86_64")
    if args.dry_run:
        print("would run builds=%s runs=%d sec=%.0f export=%s" % (names, args.runs, args.sec, args.export))
        return agent_log.emit_result("PASS", dry_run=True)
    if args.export:
        for n in names:
            export(root, godot, n)
    shots = agent_log.run_path("desktop-perf", root, "shots")
    shots.mkdir(parents=True, exist_ok=True)
    res: dict[str, list[dict]] = {n: [] for n in names}
    for i in range(args.runs):
        for n in names:
            if not (root / BUILDS[n][1]).is_file():
                raise SystemExit("no %s build; pass --export" % n)
            res[n].append(one(root, n, args.sec, 90 + i, shots, i))
    env = bench_env.env_line(godot=bench_env.godot_version(godot), renderer="gl_compatibility (software GL, Xvfb)",
                             vsync="driver default", cap="none", resolution="1920x1080")
    lines = table(res)
    print(env)
    print("\n".join(lines))
    print("shots: " + str(shots))
    if args.write_md:
        md = root / "design" / "benchmarks" / "desktop-release.md"
        stamp = time.strftime("%Y-%m-%d %H:%M %Z")
        body = "\n## %s, runs=%d, %.0f s phases\n%s\n\n%s\n" % (stamp, args.runs, args.sec, env, "\n".join(lines))
        if not md.is_file():
            md.write_text("# Desktop release vs debug perf\n\nStatus: record\nRead when: comparing desktop release and debug frame cost\n\n"
                          "`python tools/perf.py desktop --export --runs 2 --write-md`. Compare rows only within one `machine=`.\n",
                          encoding="utf-8")
        with md.open("a", encoding="utf-8") as f:
            f.write(body)
    ok = all(x[p].get("n") for n in names for x in res[n] for p in PHASES)
    return agent_log.emit_result("PASS" if ok else "INFO", builds=",".join(names), runs=args.runs)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
