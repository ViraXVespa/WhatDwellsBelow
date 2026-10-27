# Tools: performance, hitches and load time

Status: protocol  
Read when: measuring frame time, hitches, load time or web performance, or reading a benchmark run  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Records: `design/benchmarks/` (index in `save-tech.md`). Perf numbers compare only within one machine and one mode.

Entries here: `perf.py`; their code: `tools/lib/perf/`.

## Jobs

- **Hub frame time and hitches:** `perf.py hub --leg desktop` (or `web`, `both`). Reprint a run: `perf.py hub --report HITCH.jsonl`. Web layer cost: `perf.py hub --leg web --layers` (standing at the dummy) and `perf.py hub --leg web --walk-layers` (full bench, then each hidden group during the fill). Neither scores the 99% bar.
- **Web perf (advisory):** `release.py export-web --debug --out DIR`, then `perf.py web --site DIR --flow camp-idle,camp-pause --baseline tools/data/web-perf-baseline.json`. Release numbers: `perf.py web --release-ref`.
- **Load time:** `perf.py load` (title to Placeholdia), `perf.py load --leg dungeon`. Web loading bars: `perf.py bars --site DIR` (`--desktop` for the desktop game). First menu opens: `gate.py bot-smokes --phases 6` (open timing).
- **Desktop release vs debug:** `perf.py desktop --export` (`--write-md` records it).
- **Dungeon generation:** `perf.py map` (one seed), `--seeds 42 7 9`, `--sweep --count N`.
- **Raw hitch rows while playing a web build:** `perf.py hitch --site DIR`, open http://127.0.0.1:8060.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `perf.py hub` | Hub frame-time bench: two ~30 s walks, `--leg desktop\|web\|both`. A leg fails under 99% of frames at 60 FPS or when the bench row lacks its fields. Desktop: compatibility window, vsync off at 120 cap, empty AppData (never the real save); `--headless` drives it but is not an FPS reading. Web: local export in a visible fullscreen Edge (Chrome fallback, `--browser`), browser pacing on. Prints `HB:` lines, dt percentiles, the slow shape and the slowest hitch rows. `--report JSONL` reprints from a hitch file (job `hub-bench-report`); `--layers` (web, standing) and `--walk-layers` (web, full bench, layers during the fill) time each hidden layer, not scored. Summary: `hub-bench`. | D | `--help` | N |
| `perf.py web` | Advisory perf of the EXPORTED web build in headless Edge (Chrome fallback; `pip install playwright`). Never a gate, not an FPS reading. Export first: `release.py export-web --debug --out DIR`, then `--site DIR` (the default `_out/web` may be stale release). `--flow A,B` (`web-perf-flows.json`), `--baseline tools/data/web-perf-baseline.json` flags WORSE (`--strict` exits 1), `--save-baseline`, `--repeat N`, `--mbps`. `--release-ref` exports preset `Web` and uses the release baseline (never mixed). Browser 60 Hz pacing is off by default; `--vsync` keeps it, so compare in one mode. `--video DIR` also records each run to `DIR/<flow>.webm` (needs `python -m playwright install ffmpeg`). `--selftest` offline. Summary: `web-perf`. | BD | `--help` | Y |
| `perf.py hitch` | Serve an exported web build on 127.0.0.1 (`--site DIR`, `--port 8060`) and append the game's hitch rows to `_logs/web-perf/hitch.jsonl`. `perf.py web` serves through it and prints the rows as `hitch run<i>` lines. | WD | `--help` | N |
| `perf.py bars` | Web landing bar and in-game loader progress vs time in headless Chrome, cold (`--mbps`, default 16) then cached; JSON + PNG chart in `_logs/load-bars/` (`--chart JSON` redraws; `--desktop` traces the desktop game). Flags a fill going back or 100% shown early. | BD | `--help` | Y |
| `perf.py load` | Load-timing smoke. `--leg hub` (default): Title -> Placeholdia, summary `load-timing`. `--leg dungeon`: Placeholdia -> Dungeon, summary `dungeon-load-timing`. | WD | `--help` | N |
| `perf.py desktop` | Desktop release vs debug perf: `--export` exports `Linux` / `Linux Debug` to `_out/linux*/`, runs each on its own Xvfb with empty XDG data, drives it with keys (title, camp, crystal, dungeon) and times frames from `--print-fps`; screenshots per phase. `--builds`, `--sec`, `--runs`; `--write-md` appends to the desktop-release benchmark. Software GL; not a gate. Summary: `desktop-perf`. | D | `--help` | N |
| `perf.py map` | Dungeon generation map smoke, summary `dungeon-map`. `--seeds 42,7,9` or `--sweep --count N`: one row per seed, summary `dungeon-map-sweep`. | WD | `--help` | N |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `data/web-perf-flows.json` | Flows for `perf.py web` (`_boot` is the shared prefix). `dungeon-fight` runs the playtester: compare its fps only with itself; INVALID runs are never baselined; `expect_change` pairs must differ (else STUCK). `dungeon-music-cold` is the web music regression: cold cache, `mbps`, a `cpu` throttle step, an audio-thread probe (`audio`, `audio_reset`) and `assert` limits (audio gaps 0, music-phase frame p95); an ASSERT fails the run. |
| `data/web-perf-baseline.json` | `--save-baseline` numbers (box, w7 tip, median of 2, Chrome frame pacing off: uncapped, the default). Compare in the same mode (not `--vsync`); re-save per machine. |
| `data/web-perf-release-baseline.json` | `perf.py web --release-ref --save-baseline` numbers: release export, hook-free flows, with the `env` line. Not comparable to `web-perf-baseline.json`. |
