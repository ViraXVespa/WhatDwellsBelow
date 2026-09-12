# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Do not dump whole files unless asked. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / Cursor desktop assistant writing via GitHub PR (cloud agent when available, or GitHub connector), or the User named a Grok Bot path / Grok Bot refactor sweep | Follow `design/grok-bot-session.md` and `design/refactor.md`. Ship via branch + PR. Refactor only. |

If unsure: ask once, then use **web / chat** if still uncertain. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

| Need | File |
|------|------|
| Shared workflow | `design/protocol.md` |
| Web / chat session flow | `design/web-session.md` |
| Grok Build session flow | `design/grok-build.md` |
| Grok Bot session flow | `design/grok-bot-session.md` |
| Refactor recipe | `design/refactor.md` |
| Must / must-not | `design/constraints.md` |
| Topic + code map | `design/README.md` |
| Grok Build leave-off | `design/sessions.md` |
| Grok Build session log | `design/session-log.md` |
| Version scheme, changelog, week pins | `design/versioning.md` |
| Player / I2V art door | `design/art-pipeline.md` |
| Numbers | `design/tunables.md` |

Fresh **Grok** instance: read `design/protocol.md` and `design/constraints.md`, then only the topic files for the requested work. Use the code map in `design/README.md` before walking the live tree. Do not start by archiving or rewriting. Do not read `design/changelog/` unless the requested work is versioning, a named past build, or a revert.

**Grok Bot** does not follow that read list. After this file, follow `design/grok-bot-session.md` only.

**Grok Build** after a gap: follow `design/grok-build.md`. Read `design/sessions.md` and current-series changelog files. Do not pin an archive unless the User opens the session by saying it is a **new week**. `design/session-log.md` is not part of every boot.

**Web / chat** after the repo-review message: follow `design/web-session.md`. Do not start Phase 4 emits during Phase 1–3.

`design/sessions.md` is the Grok Build leave-off. Web / chat may read it for context only. Grok Bot does not read it. It is not the web-session or Grok Bot hand-off. Do not resume unfinished Grok Build work from it unless the User names that work.

**Binding design** is required behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third system.

Shipping code is the repo root (`project.godot`, `scenes/`, `scripts/`, `assets/`). Patch it in place.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`. Do not copy snapshot project trees into `archives/` or onto live. Do not create a new archive unless the User asks, except the standing Grok Build week pins in `design/versioning.md` when the User has said **new week**.

Implement only what design and the User require. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op. Open numbers: invent coherent starts, expose them in the secret debug menu, record in `design/tunables.md`. Ambiguity: ask.

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
- Private facade fields used only by a sibling helper (`host._news_scroll`, `host._list_root`, HUD prompt slots): keep the var on the host. Put `@warning_ignore("unused_private_class_variable")` on that declaration. Do not delete the field.
- Do not use `@warning_ignore` to hide a real unused value or a live shadow.

## Script cap (10KB)

Every live `scripts/**/*.gd` that ships must stay under **10,000 bytes**.

- **Grok Build (CLI)** enforces the cap while editing. Split in that same slice with `design/refactor.md`. Stop once the file is under 10KB. Do not keep splitting toward Grok Bot’s 5KB sweep target.
- **Web / chat** does not apply the cap until Phase 6. See `design/web-session.md`.
- **Grok Bot** uses `design/refactor.md` on every task. 10KB is the ship floor. The under-5KB sweep target is only in `design/grok-bot-session.md`.
