# Desktop release vs debug perf

Status: record
Read when: comparing desktop release and debug frame cost

`python tools/run_desktop_perf.py --export --runs 2 --write-md`. Compare rows only within one `machine=`.
Release = preset `Linux` (release template, `scripts/debug` and `_*` excluded; `run_release_smoke.py --pck _out/linux` finds 0 debug paths). Debug = preset `Linux Debug` (debug template, debug code on: hitch log, idle playtester). Input is xdotool keys on a private Xvfb; timing is the engine `--print-fps` line (1 s averages), so worst = worst 1 s, not worst frame.

## 2026-10-20 20:54 CDT, runs=2, 8 s phases, commit 9a009b7e (+ tool)
env: machine="bot-box" cpu="Intel(R) Xeon(R) Processor x8" gpu="unknown" ram_gb="16" os="Debian GNU/Linux 13 (trixie) (6.12.94+)" browser="n/a" godot="4.7.2.stable.official.ed1daf0bf" renderer="gl_compatibility (software GL, Xvfb)" vsync="driver default" cap="none" res="1920x1080" headless="0"

| Phase | Release (mean / worst 1 s mspf) | Debug (mean / worst 1 s mspf) |
|---|---|---|
| title-idle | 9.7 / 10.1 | 9.8 / 10.1 |
| camp-idle | 12.8 / 13.2 | 13.5 / 14.6 |
| camp-walk | 12.9 / 13.4 | 13.1 / 13.8 |
| dungeon-idle | 9.0 / 9.3 | 8.3 / 8.5 |
| dungeon-walk | 9.0 / 9.9 | 9.0 / 9.8 |
| hub-load (approx) | 3.7 s | 3.8 s |
| dungeon-load (approx) | 2.7 s | 2.7 s |

Read: release and debug are within about 5% everywhere (camp idle 12.8 vs 13.5 ms, -5%; dungeon idle 9.0 vs 8.3 ms, +8%, random dungeon per run). Loads match. Software GL dominates, so script and debug-code cost barely shows; the web release win (load time) does not repeat here.
