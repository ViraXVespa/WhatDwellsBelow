# Refactor recipe: hostify, types, shared calculations

Status: protocol  
Read when: a size split or extract batch moves methods onto `static func(host, ...)` helpers, retypes moved lines, or a smoke asserts a gameplay formula

Placement, caps and the split steps are in the refactor door.

## Types

`design/gdscript-law.md`. On lines already being moved or rewritten:

- `:=` only for literals / typed built-ins Godot 4.7 infers (`0`, `1.5`, `true`, `"male"`, `Vector2.DOWN`, …).
- Otherwise `var name: Type = ...`.
- Typed `func` / `static func` args and `->` return.
- Also follow `design/gdscript-law.md` warnings (no `wrap` / `mini` / `name` / `size` locals, explicit `int()` on integer division and narrowing, enum `as` casts, `_` unused params).
- `unused_private_class_variable` is project-ignored (hostify `host._` fields). Do not add per-var `@warning_ignore` for it; see `design/gdscript-law.md`.

Do not retype a whole file for style.

## Hostify pitfalls

Facade + `static func(host, ...)` splits must keep Godot 4.7 compiling. Watch for:

1. **Bare Node props / methods on helpers** — after moving a method off a Node script, `layer`, `visible`, `process_mode`, `queue_free()`, `get_tree()`, etc. are not in scope. Use `host.layer`, `host.queue_free()`, `host.get_tree()`.
2. **Param shadowing** — never `var host := host.get_parent()` (or any `var host :=` that hides the parameter). Rename the local (`parent`, `map_host`, …).
3. **Enum / const on Object helpers** — `MOTION_MODE_FLOATING` and similar are not free names on `extends Object` helpers. Qualify: `CharacterBody3D.MOTION_MODE_FLOATING`.
4. **Facade state aliases** — if callers used `PlaytestLog.started` / `.file_name` / `.events` on the old script, the facade must still expose those names (forward to the core helper’s `static var`s). Moving state without aliases yields `Cannot find member "started" in base "..."` and a cascade `Could not resolve class` on the next preload.
5. **`:=` after `load()` / untyped `_fac`** — `const _fac = load(...)` returns untyped. Do not `var x := _fac.foo()`. Write `var x: Type = ...` (see Types above and the agents file).
6. **Blind substring rewrites** — replacing `:= n` / bare `name` can corrupt identifiers (`var nm := name` → `var nm: String = str(n)ame`). Prefer AST-aware or line-scoped edits; re-read touched lines.
7. **Broken call commas** — hostify passes must not leave `tick_pinch(host, )` or dropped args.
8. **Cross-helper renames** — if a static was renamed (`Present.present` → `present`, `Hit.mark_post`), update every call site in the cluster in the same batch.
9. **Keep facade wrappers smoke / `call` can reach** — phase smokes still hit private names like `_pressure_spawn` / `_buy_snack` via `host.call` or `ui._…`. After moving the body to a helper, leave a one-line facade (`func _pressure_spawn() -> int: return DungeonPack.pressure_spawn(self)`) or update the smoke in the same batch.

After a hostify batch, run the **editor import** compile check via `design/pc-offload.md` (`--headless --editor --import --path <WDB_ROOT> --quit`). Plain `--quit` alone is not sufficient — it can miss `:=` inference errors the editor surfaces on reload.

Optional advisory scan: `lint_hostify.py`, always exit 0; it is not a compile substitute. After a size-split batch: Bot, `bot_warnscan.py --non-leak-diff` per BOT.md; PC, `run_post_split_gate.py` (`-WithSmokes` when coverage matters). Tool details: design/tools.md.

## Shared calculations (gameplay + smoke)

When gameplay uses a formula (gather interval, forge→hold, damage, etc.), put it in **one** static helper and call that helper from every consumer — live systems, UI, **and** phase smokes. Do not re-derive or hardcode the same numbers in the phase smokes (`scripts/debug/smoke*/`).

Rules:

1. Prefer a small `extends Object` helper next to the owner (example: `scripts/world/gather/rules.gd` for gather timing; `ForgeP.forge_hold` for programmatic forge→hold).
2. Before asserting in a smoke, search for an existing helper (`interval_for`, `forge_hold`, …). If none exists, **extract** it from the live code first, then assert against the helper’s result. Grok Build may write that helper as a same-system API.
3. When hostifying, keep smoke-reachable facades (see Hostify pitfall 9) **and** keep smokes on the shared calc route — updating only the smoke’s hardcoded constants is a regression waiting to happen.
4. Search for duplicated literals of the same feature (example: `2.4` / `mine_time`) during size sweeps; fold them into the helper in the same batch when safe.

