# Refactor recipe

Status: protocol  
Read when: splitting a live script for size; Grok Bot every task; Grok Build when an edit is over 10KB; web / chat Phase 6  
See also: `AGENTS.md`, `design/grok-bot-session.md`, `design/README.md`

This file is the mechanical recipe. Session flow lives in the path files. Grok Bot uses this file on every task. Other paths use it only when they must split.

## Caps

| Rule | Who |
|------|-----|
| Ship floor: every live `scripts/**/*.gd` under **10,000 bytes** | Every path that ships a `.gd` |
| Sweep target: each resulting file under **5,000 bytes** when existing code can move | Grok Bot only (`design/grok-bot-session.md`) |

Grok Build and web / chat stop once the file is under 10KB. They do not keep splitting toward 5KB.

Do not split a file that is already under the cap that applies to the current path, except Grok Bot extract / reuse work (new shared module or fitting existing owner).

## No new code

Grok writes behavior. A refactor only rearranges what already exists.

- Do not add features, tunables, comments, docs-of-taste, renames, reformats, or “while I’m here” cleanups.
- Do not invent a better API. Do not generalize two vaguely similar features into a new one.
- Do not add a helper function that was not already in the tree, except Grok Bot’s shared-module extract of **near-identical** existing bodies (same control flow; renamed locals OK).
- Grok Build / web / chat size-splits MUST NOT invent new shared modules unless following the Grok Bot path.
- Edits are the minimum needed to relocate existing lines and keep the project compiling.

Adding `: Type` on a line already being moved, a `load()` / `preload()`, a one-line facade delegate, or `host` / `pt` / `ui` / `p` on a moved `static func` is wiring, not new behavior.

## Size split

If a file must be split:

1. Split into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, …).
2. Keep the original path as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`. Use `load()` on one side or put shared state on the host.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first. One cluster per batch. Stop so the User can compile (web / chat: so the User can paste; Grok Bot: ship the PR, report, and follow `design/grok-bot-session.md` before the next cluster).

The only new path a **size** split may create is that sibling helper. Its body is **moved code**, not newly written logic.

Grok Bot: after the split, each resulting live `.gd` should be under 5KB when whole existing functions can move. If one existing function is itself over 5KB, leave it whole and report it. Never leave a touched file over 10KB if a legal split can fix it.

## Grok Bot — new shared modules

Grok Bot **MAY** create shared owners when near-identical behavior spans places.

- Prefer a **NEW shared module** over growing an existing owner (example: tooltip placement / behavior across Anvil / Analyze / Forge / Inventory).
- Near-identical = same control flow (renamed locals OK), not vaguely similar features.
- Point at an existing owner only if it already **is** that concern **and** the addition will not blow the size cap.
- Never grow an owner just to avoid a new file.
- Grok Build / web / chat size-splits still do not invent new shared modules unless following this Grok Bot path.

## Reuse (existing owners)

Hunt for copied logic only after size work on the current cluster, or when the cluster *is* a reuse / extract item.

1. If the copy only lives inside one system, it belongs in a sibling of that facade — the size-split shape above. Not a new global owner.
2. If the copy is the same concern as an **existing** shared script **and** routing call sites there keeps that owner under the size cap, change the copies to call that script. Live owners include:
   - menu tab / confirm / back / page: `scripts/ui/menu_pad.gd`
   - bottom prompt / hint strip: `scripts/ui/prompt_view.gd`
   - other existing shared scripts already in the tree (`theme.gd`, `pause_menu_util.gd`, `gear_board_tip.gd`, …) when they already expose the function
3. If nothing existing owns it, or the owner would blow the size cap: **Grok Bot** prefers a new shared module for near-identical spanning copies; otherwise leave the copies and report them. Do not add a new method on an existing owner just so the copies can fit.

Reuse against an existing owner is call-site edits plus using a function that already exists. Grok Bot extract to a new shared module is moved bodies into a new file, not invented logic.

## Types

`AGENTS.md` → GDScript types. On lines already being moved or rewritten:

- `:=` only for literals / typed built-ins Godot 4.7 infers (`0`, `1.5`, `true`, `"male"`, `Vector2.DOWN`, …).
- Otherwise `var name: Type = ...`.
- Typed `func` / `static func` args and `->` return.
- Also follow `AGENTS.md` → GDScript warnings (no `wrap` / `mini` / `name` / `size` locals, explicit `int()` on integer division and narrowing, enum `as` casts, `_` unused params).

Do not retype a whole file for style.



## Hostify pitfalls

Facade + `static func(host, ...)` splits must keep Godot 4.7 compiling. Watch for:

1. **Bare Node props / methods on helpers** — after moving a method off a Node script, `layer`, `visible`, `process_mode`, `queue_free`, `get_tree()`, etc. are not in scope. Use `host.layer`, `host.queue_free()`, `host.get_tree()`.
2. **Param shadowing** — never `var host := host.get_parent()` (or any `var host :=` that hides the parameter). Rename the local (`parent`, `map_host`, …).
3. **Enum / const on Object helpers** — `MOTION_MODE_FLOATING` and similar are not free names on `extends Object` helpers. Qualify: `CharacterBody3D.MOTION_MODE_FLOATING`.
4. **Facade state aliases** — if callers used `PlaytestLog.started` / `.file_name` / `.events` on the old script, the facade must still expose those names (forward to the core helper’s `static var`s). Moving state without aliases yields `Cannot find member "started" in base "..."` and a cascade `Could not resolve class` on the next preload.
5. **`:=` after `load()` / untyped `_fac`** — `const _fac = load(...)` returns untyped. Do not `var x := _fac.foo()`. Write `var x: Type = ...` (see Types above and `AGENTS.md`).
6. **Blind substring rewrites** — replacing `:= n` / bare `name` can corrupt identifiers (`var nm := name` → `var nm: String = str(n)ame`). Prefer AST-aware or line-scoped edits; re-read touched lines.
7. **Broken call commas** — hostify passes must not leave `tick_pinch(host, )` or dropped args.
8. **Cross-helper renames** — if a static was renamed (`Present.present` → `present`, `Hit.mark_post`), update every call site in the cluster in the same batch.

After a hostify batch, run the **editor import** compile check in `design/grok-bot-session.md` (`--headless --editor --import --path <WDB_ROOT> --quit`). Plain `--quit` alone is not sufficient — it can miss `:=` inference errors the editor surfaces on reload.

## Token rules

- Do not load the design corpus for a split. Code map row + the cluster is enough.
- Measure on-disk byte length (Get-Item Length / dir). Do not guess. Do not ReadAllText + GetByteCount just to size-check.
- Do not dump whole files on Grok Build or Grok Bot when a diff / PR is enough.
- Do not restyle, do not rewrite comments, do not rename for taste.
- Do not combine a refactor with a feature.
- Web / chat still emits full files in Phase 4 / Phase 6 as `design/web-session.md` requires. This recipe does not change emit shape.

## After a split

Update the `design/README.md` code map when a new sibling or shared module must be listed. Do not update topic design files unless behavior changed (a legal sweep does not change behavior).

Grok Bot sweep notes: optional `_logs/grok-bot-sweep.md` per `design/grok-bot-session.md`. Not `design/sessions.md`. Not `design/changelog/`.

## Parked folder moves

Do **not** do these during a size split. They need their own session / batch: every `preload` / `load` path plus `design/README.md` code-map rows. Grok Bot treats these (and User-named deeper relocates) as their own clusters; no behavior change.

- Move `scripts/combat/debug_menu*.gd` (and the input / profile / val helpers added beside them) to `scripts/debug/`. The secret debug menu is not combat.
- Move `scripts/combat/sfx.gd` out of combat to a sound-facing folder (`scripts/audio/` or `scripts/debug/` only if it is debug-only; live SFX belong with audio).
- When a facade already has several sibling helpers, put that cluster in a dedicated subdir named for the facade (`scripts/ui/gear_board/`, `scripts/debug/debug_menu/`, …) so the scripts tree does not stay a flat dump. Update every preload after the move. Facade path can stay as a one-line wrapper at the old location if call sites are wide.
