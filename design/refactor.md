# Refactor recipe

Status: protocol  
Read when: splitting a live script for size; Grok Bot every task; Grok Build when an edit is over 10KB; web / chat Phase 6  
See also: `design/grok-bot-session.md`, `design/doc-refactor.md`

`See also:` is an index, not a read list. Do not open those files unless this file’s `Read when`, a Job table, or the User names that work.

This file is the mechanical recipe. Session flow lives in the path files. Grok Bot uses this file on every task. Other paths use it only when they must split. Grok Bot flow routing is `design/grok-bot-session.md` (one Job-table sibling). Relocate steps that Bot must follow as a session are `design/grok-bot-relocate.md`.

Grok Build feature work is **not** a refactor. Implementation freedom (new same-system APIs, helpers, local module shape) lives in `design/grok-build.md`. This file’s **No new code** rules do not bind that work. When Build only needs the 10KB cap, use the size-split mechanics here; do not import Bot’s “do not invent a better API” leash.

## Caps

| Rule | Who |
|------|-----|
| Ship floor: every live `scripts/**/*.gd` under **10,000 bytes** | Every path that ships a `.gd` |
| Sweep target: each resulting file under **5,000 bytes** when existing code can move | Grok Bot size sweep only (`design/grok-bot-size.md`) |

Grok Build and web / chat stop once the file is under 10KB. They do not keep splitting toward 5KB.

Do not split a file that is already under the cap that applies to the current path, except Grok Bot extract work (new shared module or fitting existing owner) when that flow is the active Job-table sibling.

## No new code

This section binds **Grok Bot** and **web / chat Phase 6 size-splits** only. It does not bind Grok Build feature work.

A refactor only rearranges what already exists.

- Do not add features, tunables, comments, docs-of-taste, renames, reformats, or “while I’m here” cleanups.
- Do not invent a better API. Do not generalize two vaguely similar features into a new one.
- Do not add a helper function that was not already in the tree, except Grok Bot’s shared-module extract of **near-identical** existing bodies (same control flow; renamed locals OK).
- Web / chat size-splits MUST NOT invent new shared modules unless following the Grok Bot path.
- Edits are the minimum needed to relocate existing lines and keep the project compiling.

Grok Build size-splits MAY introduce a new **same-system** helper API when that is cleaner than a dumb line-move. A new **cross-system** owner during a Build split is `design/grok-build.md` → **Stop and propose first**. Do not create it in the split.

Adding `: Type` on a line already being moved, a `load()` / `preload()`, a one-line facade delegate, or `host` / `pt` / `ui` / `p` on a moved `static func` is wiring, not new behavior.

A non-empty `design/reuse-map.md` brief may name small kits at the surface that brief states. That is not a license to invent a widget framework. An empty template is not a kit list.

## Size split

If a file must be split:

1. Split into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, …).
2. Keep the original path as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`. Use `load()` on one side or put shared state on the host.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first. One cluster per batch. Stop so the User can compile (web / chat: so the User can paste; Grok Bot: ship the PR, report, and follow `design/grok-bot-session.md` before the next cluster).

The default new path a **size** split may create is that sibling helper. On Grok Bot and web / chat, its body is **moved code**, not newly written logic. On Grok Build, the sibling MAY be a cleaner same-system API, not only a line-move.

Grok Bot size sweep: after the split, each resulting live `.gd` should be under 5KB when whole existing functions can move (`design/grok-bot-size.md`). If one existing function is itself over 5KB, leave it whole and report it. Never leave a touched file over 10KB if a legal split can fix it.

## Grok Bot — new shared modules

Grok Bot **MAY** create shared owners when near-identical behavior spans places. Session flow: `design/grok-bot-extract.md` (ad-hoc) or `design/grok-bot-reuse.md` (staged brief).

- Prefer a **NEW shared module** over growing an existing owner (example: tooltip placement / behavior across Anvil / Analyze / Forge / Inventory).
- Near-identical = same control flow (renamed locals OK), not vaguely similar features.
- Point at an existing owner only if it already **is** that concern **and** the addition will not blow the size cap.
- Never grow an owner just to avoid a new file.
- Web / chat size-splits still do not invent new shared modules unless following this Grok Bot path.
- Grok Build does not use this Bot extract leash. Same-system APIs: just do. Cross-system owners: `design/grok-build.md` → **Stop and propose first**.
- Do not hunt the live tree to rediscover copies when the User already named the cluster. Do not treat `design/reuse-map.md` as an owners encyclopedia.

## Reuse (existing owners)

Hunt for copied logic only after size work on the current cluster, or when the active Bot flow is extract / staged reuse.

1. If the copy only lives inside one system, it belongs in a sibling of that facade — the size-split shape above. Not a new global owner.
2. If the copy is the same concern as an **existing** shared script **and** routing call sites there keeps that owner under the size cap, change the copies to call that script. Discover owners from the live tree + `design/README.md` code map, not from a standing reuse-map table. Short reminders that already ship:
   - menu tab / confirm / back / page: `scripts/ui/menu_pad.gd`
   - bottom prompt / hint strip: `scripts/ui/prompt_view.gd`
   - other existing shared scripts already in the tree (`theme.gd`, `pause_menu_util.gd`, `gear_board_tip.gd`, `plate_chrome.gd`, `tip_place.gd`, …) when they already expose the function
3. If nothing existing owns it, or the owner would blow the size cap: **Grok Bot** prefers a new shared module for near-identical spanning copies; otherwise leave the copies and report them. Do not add a new method on an existing owner just so the copies can fit. **Grok Build** may add a same-system method or helper; a new cross-system owner is propose-first.

Reuse against an existing owner is call-site edits plus using a function that already exists. Grok Bot extract to a new shared module is moved bodies into a new file, not invented logic. Do not merge pairs listed under **Do not merge** in `design/grok-bot-extract.md`.

## Types

`AGENTS.md` → GDScript types. On lines already being moved or rewritten:

- `:=` only for literals / typed built-ins Godot 4.7 infers (`0`, `1.5`, `true`, `"male"`, `Vector2.DOWN`, …).
- Otherwise `var name: Type = ...`.
- Typed `func` / `static func` args and `->` return.
- Also follow `AGENTS.md` → GDScript warnings (no `wrap` / `mini` / `name` / `size` locals, explicit `int()` on integer division and narrowing, enum `as` casts, `_` unused params).
- `unused_private_class_variable` is project-ignored (hostify `host._` fields). Do not add per-var `@warning_ignore` for it; see `AGENTS.md` -> GDScript warnings.

Do not retype a whole file for style.

## Hostify pitfalls

Facade + `static func(host, ...)` splits must keep Godot 4.7 compiling. Watch for:

1. **Bare Node props / methods on helpers** — after moving a method off a Node script, `layer`, `visible`, `process_mode`, `queue_free()`, `get_tree()`, etc. are not in scope. Use `host.layer`, `host.queue_free()`, `host.get_tree()`.
2. **Param shadowing** — never `var host := host.get_parent()` (or any `var host :=` that hides the parameter). Rename the local (`parent`, `map_host`, …).
3. **Enum / const on Object helpers** — `MOTION_MODE_FLOATING` and similar are not free names on `extends Object` helpers. Qualify: `CharacterBody3D.MOTION_MODE_FLOATING`.
4. **Facade state aliases** — if callers used `PlaytestLog.started` / `.file_name` / `.events` on the old script, the facade must still expose those names (forward to the core helper’s `static var`s). Moving state without aliases yields `Cannot find member "started" in base "..."` and a cascade `Could not resolve class` on the next preload.
5. **`:=` after `load()` / untyped `_fac`** — `const _fac = load(...)` returns untyped. Do not `var x := _fac.foo()`. Write `var x: Type = ...` (see Types above and `AGENTS.md`).
6. **Blind substring rewrites** — replacing `:= n` / bare `name` can corrupt identifiers (`var nm := name` → `var nm: String = str(n)ame`). Prefer AST-aware or line-scoped edits; re-read touched lines.
7. **Broken call commas** — hostify passes must not leave `tick_pinch(host, )` or dropped args.
8. **Cross-helper renames** — if a static was renamed (`Present.present` → `present`, `Hit.mark_post`), update every call site in the cluster in the same batch.
9. **Keep facade wrappers smoke / `call` can reach** — phase smokes still hit private names like `_pressure_spawn` / `_buy_snack` via `host.call` or `ui._…`. After moving the body to a helper, leave a one-line facade (`func _pressure_spawn() -> int: return DungeonPack.pressure_spawn(self)`) or update the smoke in the same batch.

After a hostify batch, run the **editor import** compile check via `design/pc-offload.md` / the active Bot size flow (`--headless --editor --import --path <WDB_ROOT> --quit`). Plain `--quit` alone is not sufficient — it can miss `:=` inference errors the editor surfaces on reload.

Optional advisory scan: `powershell -File tools/lint_hostify.ps1` → `_logs/hostify-lint/summary.txt` (always exit 0). Use it to spot Hostify pitfalls before or after the import check; it is not a compile substitute. After a size-split batch, prefer `powershell -File tools/run_post_split_gate.ps1` (add `-WithSmokes` when coverage matters).

## Shared calculations (gameplay + smoke)

When gameplay uses a formula (gather interval, forge→hold, damage, etc.), put it in **one** static helper and call that helper from every consumer — live systems, UI, **and** phase smokes. Do not re-derive or hardcode the same numbers in `scripts/debug/smoke_*.gd`.

Rules:

1. Prefer a small `extends Object` helper next to the owner (example: `scripts/world/gather_rules.gd` for gather timing; `ForgeP.forge_hold` for programmatic forge→hold).
2. Before asserting in a smoke, search for an existing helper (`interval_for`, `forge_hold`, …). If none exists, **extract** it from the live code first, then assert against the helper’s result. Grok Build may write that helper as a same-system API.
3. When hostifying, keep smoke-reachable facades (see Hostify pitfall 9) **and** keep smokes on the shared calc route — updating only the smoke’s hardcoded constants is a regression waiting to happen.
4. Search for duplicated literals of the same feature (example: `2.4` / `mine_time`) during size sweeps; fold them into the helper in the same batch when safe.

## Token rules

- Do not load the design corpus for a split. Code map row + the cluster is enough. Open `design/reuse-map.md` only from `design/grok-bot-reuse.md` when that brief is not the empty template.
- Measure on-disk byte length (Get-Item Length / dir). Do not guess. Do not ReadAllText + GetByteCount just to size-check.
- Do not dump whole files on Grok Build or Grok Bot when a diff / PR is enough.
- Do not restyle, do not rewrite comments, do not rename for taste — on Grok Bot and web / chat size-splits. Grok Build feature work may rename or reshape inside one system per `design/grok-build.md`.
- Do not combine a refactor with a feature — on Grok Bot and web / chat. Grok Build may split for the cap in the same slice as the feature.
- Web / chat still emits full files in Phase 4 / Phase 6 as `design/web-session.md` requires. This recipe does not change emit shape.

## After a split

Update the `design/README.md` code map when a new sibling or shared module must be listed. Do not update topic design files unless behavior changed (a legal sweep does not change behavior). Do not write extract results into `design/reuse-map.md` from Bot; web / chat Phase 7 owns that staging brief.

Grok Bot sweep notes: optional `_logs/grok-bot-sweep.md` per `design/grok-bot-session.md`. Not `design/sessions.md`. Not `design/changelog/`.

## Parked folder moves

Do **not** fold these into a size split. Bot session flow: `design/grok-bot-relocate.md`. Every `preload` / `load` / ExtResource path plus `design/README.md` code-map rows must stay correct. No behavior change.

Preferred (agent-friendly): from repo root, `powershell -File tools/move_script_cluster.ps1` (or `python tools/move_script_cluster.py`). It `git mv`s the facade + stem siblings (+ `.uid`), rewrites `res://` and bare paths under `scripts/`, `design/`, scenes, and `project.godot`, and writes `_logs/move-cluster/summary.txt`. Optional `-DryRun`, `-Wrapper` (leave `extends "res://..."` stubs at old paths). Then run the editor import check.

Done (0.3.11 relocate batch):

- `scripts/combat/debug_menu*.gd` -> `scripts/debug/debug_menu/`
- `scripts/combat/sfx.gd` -> `scripts/audio/sfx.gd`
- Sample facade folder: `scripts/ui/gear_board*.gd` -> `scripts/ui/gear_board/`

Still open for later User go: other fat facade clusters (same tool). Prefer updating call sites over wrappers when external refs are few.

## Documentation facades

Script splits stay in this file. Topic markdown door + sibling splits are `design/doc-refactor.md`. Bot session flow: `design/grok-bot-docs.md`.
