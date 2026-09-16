# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Implementation is unconstrained there (same-system APIs just do; cross-system / named-architecture replace is propose-first). Do not dump whole files unless asked. Do not apply web / Bot leashes to this path. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / Cursor desktop assistant writing via GitHub PR (cloud agent when available, or GitHub connector), or the User named a Grok Bot path / Grok Bot refactor sweep | Follow `design/grok-bot-session.md` only (door). That Job table names the one flow sibling. Recipes: `design/refactor.md` / `design/doc-refactor.md`. Ship via branch + PR. Refactor only. |

If unsure: ask once, then use **web / chat** if still uncertain. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

Navigation is only `design/routes.yaml`. Do not treat `See also:` as a load list; that field is forbidden. Open a file when this Path table, a routes.yaml door / job / gate, or the User names that work.

| Need | File |
|------|------|
| Must / must-not (web / Build only) | `design/constraints.md` |
| Live code map (one system row) | `design/code-map.md` |
| Numbers (when the work changes them) | `design/tunables.md` |

Path session files are in the Path table, not here. Agent routes: `design/routes.yaml`. Topic index: `design/README.md` (one topic row; the table is not a read list). Versioning, art, isolated-media, reuse-map, sessions, session-log, protocol, and refactor: open only when `Read when` matches, a Job table names it, or the User names that work.

**Load cap (soft):** default is this file + the path session file + (web / Build only) `design/protocol.md` and `design/constraints.md` + one topic door + one Job-table sibling. `design/tunables.md` when numbers change. `design/versioning.md` at ship only. `design/code-map.md` is one system row, not the whole table. A second topic door is allowed when that file’s `Read when` matches or the User names the boundary. Ask before a third topic door. Protocol / constraints / tunables / versioning-at-ship / one code-map row are not topic doors.

Fresh **Grok** (web / Build): read `design/protocol.md` and `design/constraints.md`, then only the topic door for the requested work. Use one row in `design/code-map.md` before walking the live tree. Do not start by archiving or rewriting. Do not read `design/changelog/` on a mid-week slice. Open it only for **new week**, a revert, a named past build, or when the User asks what shipped. Do not open `design/reuse-map.md` unless this session’s goal is to write that brief or the User named the staged reuse PR.

**Grok Build (CLI):** Imagine (`image_gen`, `image_edit`, `image_to_video`) defaults to `design/isolated-media.md` and `tools/run_isolated_grok.py`. Repo skills `.grok/skills/imagine-isolated/` and `.grok/skills/i2v-isolated/` are doors into that file. Web / chat and Grok Bot do not run Imagine.

**Grok Bot** skips the web / Build read list. After this file, follow `design/grok-bot-session.md` only. Do not reopen this file for protocol or constraints. Types, warnings, tabs, and the 10KB cap in the sections below still bind; the Bot door may point at those sections if they left context. Open `design/reuse-map.md` only from `design/grok-bot-reuse.md` when that brief is not the empty template.

Path procedures (Build week pin, web phases, Bot flows) live in that path’s session file. `design/sessions.md` is the Grok Build leave-off only — not a web or Bot hand-off. Fresh Build instance: this file, then `design/grok-build.md`. Leave-off is not a boot list.

**Binding design** is required **player-facing** behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third **game** system. A new code API is not a third game system. Grok Build implementation rules: `design/grok-build.md`.

Shipping code is the repo root (`project.godot`, `scenes/`, `scripts/`, `assets/`). Patch it in place.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`. Do not copy snapshot project trees into `archives/` or onto live. Do not create a new archive unless the User asks, except the standing Grok Build week pins in `design/versioning.md` when the User has said **new week**.

Implement only the game systems design and the User require. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op. Grok Build MAY invent code shape inside those systems. Open numbers: invent coherent starts, expose them in the secret debug menu, record in `design/tunables.md`. Ambiguity about player-facing design: ask. Grok Build code structure inside one system: decide.

After a slice: stop and report.

GDScript indent: **tabs**.

## GDScript types

New or rewritten lines only. Do not convert a file for style.

- `:=` is allowed only when Godot 4.7 infers the type from a literal or a typed built-in constant/constructor: `0`, `1.5`, `true`, `false`, `"male"`, `Vector2.DOWN`, `Vector3.ZERO`, `Color.WHITE`, and the same class of built-ins.
- Otherwise write `var name: Type = ...`. Do not put a Dictionary, Array, `as` cast, `load()`, `preload()` assigned to `var`, `get_node()`, function result, or ternary on `:=`.
- Untyped helper `host` fields and helper return values are not inferable. Write `var x: Type = host.field` / `var items: Array[Control] = host._focusables()`. Do not use `:=` there.
- Every `func` / `static func` has typed arguments and a `->` return type.
- Typed collections when the value is a collection: `Array[String]`, `Dictionary`, or `Dictionary[String, float]` when that is the truth. Not `var rows := []`.
- Grok Bot may add `: Type` on a line it is already moving so the file compiles. That is a compile fix, not new behavior.

## GDScript warnings

Keep the Godot output log clean. New or rewritten lines must not introduce these warnings.

- Unused parameter or local: prefix `_` (`_host`, `_v`, `_p`). Do not delete a parameter the caller still passes.
- Do not name locals or parameters `wrap`, `mini`, `name`, `size`, `seed`, `owner`, or `show`. Those shadow built-ins or `Node` / `Control` members. Use `shell`, `mini_map`, `doc_name`, `font_px`, `rng_seed`, `parent_ctrl`, `show_ui`.
- Integer division: write `int(a / float(b))` when the discarded remainder is intended. Do not leave bare `int / int`.
- Enum fields (`JoyAxis`, `JoyButton`, `Key`, `MouseButton`): assign with `as ThatEnum`, not a raw int.
- Narrowing float → int / `Vector2i`: wrap the float in `int(...)` at the write site.
- Private facade fields used only by a sibling helper (`host._news_scroll`, `host._list_root`, HUD prompt slots): keep the var on the host. Do not delete the field. Project-wide, `unused_private_class_variable` is ignored in `project.godot` (`[debug] gdscript/warnings/unused_private_class_variable=0`) because hostify helpers read those fields via `host._...` — do not re-enable it without a new plan, and do not sprinkle per-var `@warning_ignore` for this warning.
- Do not use `@warning_ignore` to hide a real unused value or a live shadow.

## Script cap (10KB)

Every live `scripts/**/*.gd` that ships must stay under **10,000 bytes**.

- **Grok Build (CLI)** enforces the cap while editing. Split in that same slice with `design/refactor.md`. Stop once the file is under 10KB. Do not keep splitting toward Grok Bot's 5KB sweep target. A Build split MAY add a same-system helper API; a new cross-system owner is propose-first (`design/grok-build.md`). Preferred runners: `design/pc-offload.md` (`check_script_cap.ps1`, `run_build_gate.ps1`).
- **Web / chat** does not apply the cap until Phase 6. See `design/web-session.md`.
- **Grok Bot** uses `design/refactor.md` on every task. 10KB is the ship floor. The under-5KB sweep target is only in `design/grok-bot-size.md`. Shared PC offload: `design/pc-offload.md`.

## Design doc facades

Topic `design/*.md` files may use an art-pipeline **door + siblings** layout (`design/doc-refactor.md`). Agents open the door, then only the Job-table sibling. Grok Bot may split fat topics that way without changing binding meaning.
