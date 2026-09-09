# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Do not dump whole files unless asked. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Copilot** | The User named a Copilot / refactor sweep, or this agent is Copilot | Follow `design/copilot-session.md` and `design/refactor.md`. Edit the checkout. Refactor only. |

If unsure: ask once, then use **web / chat** if still uncertain. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

| Need | File |
|------|------|
| Shared workflow | `design/protocol.md` |
| Web / chat session flow | `design/web-session.md` |
| Grok Build session flow | `design/grok-build.md` |
| Copilot session flow | `design/copilot-session.md` |
| Refactor recipe | `design/refactor.md` |
| Must / must-not | `design/constraints.md` |
| Topic + code map | `design/README.md` |
| Grok Build leave-off | `design/sessions.md` |
| Grok Build session log | `design/session-log.md` |
| Version scheme, changelog, week pins | `design/versioning.md` |
| Player / I2V art door | `design/art-pipeline.md` |
| Numbers | `design/tunables.md` |

Fresh **Grok** instance: read `design/protocol.md` and `design/constraints.md`, then only the topic files for the requested work. Use the code map in `design/README.md` before walking the live tree. Do not start by archiving or rewriting. Do not read `design/changelog/` unless the requested work is versioning, a named past build, or a revert.

**Copilot** does not follow that read list. After this file, follow `design/copilot-session.md` only.

**Grok Build** after a gap: follow `design/grok-build.md`. Read `design/sessions.md` and current-series changelog files. Do not pin an archive unless the User opens the session by saying it is a **new week**. `design/session-log.md` is not part of every boot.

**Web / chat** after the repo-review message: follow `design/web-session.md`. Do not start Phase 4 emits during Phase 1–3.

`design/sessions.md` is the Grok Build leave-off. Web / chat may read it for context only. Copilot does not read it. It is not the web-session or Copilot hand-off. Do not resume unfinished Grok Build work from it unless the User names that work.

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
- Every `func` / `static func` has typed arguments and a `->` return type.
- Typed collections when the value is a collection: `Array[String]`, `Dictionary`, or `Dictionary[String, float]` when that is the truth. Not `var rows := []`.
- Copilot may add `: Type` on a line it is already moving so the file compiles. That is a compile fix, not new behavior.

## Script cap (10KB)

Every live `scripts/**/*.gd` that ships must stay under **10,000 bytes**.

- **Grok Build (CLI)** enforces the cap while editing. Split in that same slice with `design/refactor.md`. Stop once the file is under 10KB. Do not keep splitting toward Copilot’s 5KB sweep target.
- **Web / chat** does not apply the cap until Phase 6. See `design/web-session.md`.
- **Copilot** uses `design/refactor.md` on every task. 10KB is the ship floor. The under-5KB sweep target is only in `design/copilot-session.md`.