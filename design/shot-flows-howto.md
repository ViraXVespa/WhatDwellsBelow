# Shot-flow how-to

Read `design/shot-flows.md` for the full schema. This file only restates what is already documented there.

## Flow location and header
A flow is `tools/data/shot-flows/<name>.json` with a setup header and `steps`.
The header fills unset CLI defaults for scene, HUD, camera, viewport (`width`, `height`, and `dpr`), seed and timing.
`about` describes intent. `covers` names UI states. `covered_by` suppresses a redundant flow. `smoke: true` enables headless assertion coverage.
Optional `mask` rectangles (coordinates at 1920x1080) and tolerance exclude live animation from baseline diffs. `publish` controls staged outputs.

## Documented step ops
- `interact`: `kind` or `target`, `near` (walks next to it first)
- `press`: `pad` (A B X Y LB RB START BACK UP DOWN LEFT RIGHT LS RS) or `action` or `key`, `times`
- `device`: `kind` pad or kb
- `shot`: `name`, `texts`, `crop`, `pad` (saves `NN-name.png` plus texts json; `crop` is a Control path)
- `assert`: `target` plus one of equals/not_equals/contains/gt/lt/is_null
- `assert_texts`: `root`, `min_font`, `max_chars`, `must_contain`, `forbid`
- `set` / `call`: seed state or call a method (`target`, `value` or `method`+`args`)
- `repeat`: `max`, `until`, `steps`
- `freeze`: `group`, `on` (disables processing of a node group)
- `sweep`: full-floor capture (driven by `shots.py capture --full-map`)
- `walk_to`: `x`, `z`, `near`, `must`, `max_ms` (walk to a ground point via App.playtest)
- `drive`: `move`, `aim`, `attack`, `ms`
- `tap`: `action`
- `mark`: `name` (frame marker for movies; proof flow `camp-walk-drive`)
- `camera`: `at` [x,z] or `target` REF (+ `offset`), `zoom`, `ms`, `ease` linear|inout, `wait`, `follow`
- `wait` / `settle`: `ms` or `frames`
- `seed`, `hud`, `texts`, `log`

## Targets
Targets are dotted paths rooted at an autoload (`App`), scene host, `kind:NAME`, `group:NAME` or `node:Path`.
The first failed operation stops the flow with `SHOT: fail op=... why=...`.

## New UI state checklist (from the doc)
1. Run `shots.py flow --list` and copy the nearest relevant flow. Set its setup, states, assertions and `covers`.
2. Map it under the job's own `shot_flows` key in routes. Do not borrow a door's unrelated frames.
3. Run `shots.py flow --flow NAME` or `--job door.job`. Capture the baseline in the session that changes the screen.
4. Iterate one state with `--flow NAME --state STATE`.

All coordinates for masks are at 1920x1080. Do not invent step fields that are not listed above.
