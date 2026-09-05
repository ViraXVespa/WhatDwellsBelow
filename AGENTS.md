# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Do not dump whole files unless asked. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Copilot** | The User named a Copilot / refactor sweep, or this agent is Copilot | Follow `design/copilot-session.md` and `design/refactor.md`. Edit the checkout. Refactor only. |

If unsure: ask once, then use **web / chat**. A missed full-file emit is worse than an extra one.

`design/sessions.md` is the **Grok Build** hand-off (leave-off + log). CLI instances read it after a Grok Build gap. Web / chat may read it for context only. Copilot does not read it. It is not the web-session or Copilot hand-off. Do not resume unfinished Grok Build work from it unless the User names that work.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

Fresh instance: read `design/protocol.md` and `design/constraints.md`, then only the topic files for the requested work. Inspect the live tree. Do not start by archiving or rewriting. Do not read `design/changelog/` unless the requested work is versioning, a named past build, or a revert.

Copilot is the exception to that read list. After this file, follow `design/copilot-session.md` only. Do not load the design corpus for a sweep.

Grok Build after a gap: follow `design/grok-build.md` (includes `design/sessions.md`, current-series changelog files, live tree, week pin).

Web / chat after the repo-review message: follow `design/web-session.md`. Do not start Phase 4 emits during Phase 1–3.

| Need | File |
|------|------|
| Shared workflow | `design/protocol.md` |
| Web / chat session flow | `design/web-session.md` |
| Grok Build session flow | `design/grok-build.md` |
| Copilot session flow | `design/copilot-session.md` |
| Refactor recipe | `design/refactor.md` |
| Must / must-not | `design/constraints.md` |
| Topic + code map | `design/README.md` |
| Grok Build leave-off + log | `design/sessions.md` |
| Version scheme, changelog, week pins | `design/versioning.md` |
| Numbers | `design/tunables.md` |

**Binding design** is required behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third system.

Shipping code is the repo root (`project.godot`, `scenes/`, `scripts/`, `assets/`). Patch it in place.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`. Do not copy snapshot project trees into `archives/` or onto live. Do not create a new archive unless the User asks, except the standing Grok Build week pins in `design/versioning.md`.

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

**Grok Build (CLI)** enforces the cap while editing. If a file is over, or an edit would push it over, split in that same slice with `design/refactor.md`. Stop once the file is under 10KB. Do not keep splitting toward Copilot’s 5KB sweep target.

**Web / chat** does **not** apply the cap while drafting or emitting a file in Phase 4. Do not split, refuse, or rewrite for size until Phase 6. See `design/web-session.md`. Phase 6 uses `design/refactor.md` and the 10KB cap only.

**Copilot** uses `design/refactor.md` on every task. 10KB is still the ship floor. The sweep target (under 5KB when existing code can move) is only in `design/copilot-session.md`.

Split mechanics, reuse into existing owners, and sweep “no new code”: `design/refactor.md`.

## Web / chat

Full conversation flow, emit rules, fetch rules, and Phase 6 sizing: `design/web-session.md`.

The tool card from a page fetch is a summary. The live body is the saved artifact plus a byte check against the GitHub `size`. One fetch per path. Ask the User to paste only when that check failed and no paste is already in the thread.

Phase 7 of a goal that shipped player-visible or agent-visible change also writes one `design/changelog/{label}.md` (see `design/versioning.md`). Do not emit `scripts/data/changelog.json` as the ledger. Do not read prior changelog files to write the new one.

Do not emit a revision assembled from a tool-card summary or a truncated artifact.

Do not claim you wrote the repo. The User pastes.

## Grok Build

Full session flow: `design/grok-build.md`.

Small diffs. Match surrounding style. After the slice, report files changed, how you verified, and what is still open. Full-file paste only when asked, or when the file does not exist on disk yet.

End of a Grok Build session: update `design/sessions.md` (leave-off + log) and write `design/changelog/{label}.md` for the completion commit when that commit is `0.N.0`. That sessions file is for the next Grok Build instance, not for web / chat or Copilot.

## Copilot

Full session flow: `design/copilot-session.md`. Mechanical recipe: `design/refactor.md`.

Copilot only rearranges existing code. Grok writes behavior. Do not implement features, invent systems, add helper APIs, or change player-visible behavior.

Sweep notes go in `_logs/` (gitignored, not uploaded). Do not write `design/sessions.md`. Do not write `design/changelog/`.