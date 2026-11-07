# Gameplay clips and reference comparisons

Status: protocol
Read when: recording or editing a gameplay comparison or promotional clip

## Record

- Desktop: `shots.py movie NAME` records a catalog scenario with Godot movie maker and cuts between timeline marks. `--game DIR` uses another checkout.
- Web: `perf.py web --flow NAME --video DIR` records real-time browser video, including boot; trim it afterward.
- `tools/data/movies.json` owns movies, still views and named sets. Views may use a flow/state, a scenario or a full-floor map with overlays. List actual names with `shots.py movie --list`; do not invent scenarios.

## Compare references

`shots.py movie --refs A,B NAMES` creates temporary reference worktrees, installs this checkout's recording tooling, imports, records and compares the selected names. It lists injected dependencies in `compare.json`. Unchanged or camera-size-only pairs are excluded from the reel.

Outputs include a captioned reel, X/GIF exports, A/B/heat contact sheet and comparison metadata under the run's `_logs/movie/` directory. Recordings can take minutes per scenario/reference; inspect existing artifacts before repeating costly runs. Authentic video review is still required. Software-renderer captures do not establish User-PC performance.

## Edit and export

`media.py clip` wraps ffmpeg. Common sequence: `sbs` or `ba`, captions, then `export --for x` or `--for gif`. Outputs stay ignored/outside the repo, never committed media. X export checks 140 seconds/512 MB; GIF checks 15 MB.

`ba BEFORE AFTER` chooses a changed-area zoom/wipe for a small change, a wipe for a subtle change, or side-by-side for a strong wide change. Override with `--layout` or `--box`; it reports the choice. `--style promo` adds eased wipe chips and an optional native end card.

Framing supports crop, zoom, fit, transitions, wipe, picture-in-picture and box/arrow marks. A box may use pixels, fractions or a catalog movie region. Compose/spec paths resolve relative to the spec. Portrait `--size 720x900 --fill track|focus|box --box B` crops each segment before redrawing chips; tall titles are centred. Callouts use owned half-open windows and held/eased slots that avoid comparison identities. Native end cards retain the target size.

Exact schemas/examples and compatibility rules are in `tools/lib/media/clip_compose.py`, `clip_fx.py`, `clip_promo.py` and `clip_track.py`; use `media.py clip --help` rather than guessing flags. The media bot chooses only from the catalog, under its own task/permission rules.
