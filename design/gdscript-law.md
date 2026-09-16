# GDScript law

Status: protocol
Read when: editing or emitting GDScript

Tabs. Types, warnings, and the 10KB cap live only here. Do not copy these rules back into the agents file.

## Types

New or rewritten lines only. Do not convert a file for style.

- `:=` is allowed only when Godot 4.7 infers the type from a literal or a typed built-in constant/constructor: `0`, `1.5`, `true`, `false`, `"male"`, `Vector2.DOWN`, `Vector3.ZERO`, `Color.WHITE`, and the same class of built-ins.
- Otherwise write `var name: Type = ...`. Do not put a Dictionary, Array, `as` cast, `load()`, `preload()` assigned to `var`, `get_node()`, function result, or ternary on `:=`.
- Untyped helper `host` fields and helper return values are not inferable. Write `var x: Type = host.field` / `var items: Array[Control] = host._focusables()`. Do not use `:=` there.
- Every `func` / `static func` has typed arguments and a `->` return type.
- Typed collections when the value is a collection: `Array[String]`, `Dictionary`, or `Dictionary[String, float]` when that is the truth. Not `var rows := []`.
- Grok Bot may add `: Type` on a line it is already moving so the file compiles. That is a compile fix, not new behavior.

## Warnings

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

- Grok Build enforces the cap while editing. Split in that same slice with the refactor recipe. Stop once the file is under 10KB. Do not keep splitting toward the Bot 5KB sweep target. A Build split MAY add a same-system helper API; a new cross-system owner is propose-first.
- Web / chat does not apply the cap until Phase 6.
- Grok Bot uses the refactor recipe on every task. 10KB is the ship floor. The under-5KB sweep target is only the Bot size job.
