# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Edit live files. Do not dump whole files unless asked. |
| **Web / chat** | You cannot write the repo | Emit each touched source file in **full**. Never assume a disk write landed. |

If unsure: ask once, then use **web / chat**. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

Fresh instance: read `design/protocol.md` and `design/constraints.md`, then only the topic files for the requested work. Inspect the live tree. Do not start by archiving or rewriting.

| Need | File |
|------|------|
| Workflow | `design/protocol.md` |
| Must / must-not | `design/constraints.md` |
| Topic + code map | `design/README.md` |
| Numbers | `design/tunables.md` |

**Binding design** is required behavior. **Live snapshot** is current code. If they disagree, patch live toward binding or ask. Do not invent a third system.

Shipping code is the repo root (`project.godot`, `scenes/`, `scripts/`, `assets/`). Patch it in place.

`archives/classic_2d/`, `archives/art_experiment/`, and `archives/full_3d_pass/` are frozen. Do not overwrite them, copy them over live, or create a new archive unless the User asks.

Implement only what design and the User require. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op. Open numbers: invent coherent starts, expose them in the secret debug menu, record in `design/tunables.md`. Ambiguity: ask.

After a slice: stop and report.

GDScript indent: **tabs**.

## Script cap (10KB)

Every live `scripts/**/*.gd` must stay under **10,000 bytes**.

If a file is over, or an edit would push it over:

1. Split into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, …).
2. Keep the original path as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`. Use `load()` on one side or put shared state on the host.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split `archives/`.
7. Split the largest first; stop after a batch so the User can paste and compile.

## Web / chat

Do not emit a revision assembled from a truncated fetch. If a pull looks short, cut off, or older than the conversation, ask the User to paste the live file.

Label each code file (`## scripts/app.gd`) and emit the entire body, including unchanged lines. One long file per message unless the User says otherwise. New file: full body. Deleted file: say so; no body.

`.md` files (`AGENTS.md`, `design/*.md`): emit raw text only — no fence, no chat wrapping that same reply.

Do not claim you wrote the repo. The User pastes.

## CLI

Small diffs. Match surrounding style. After the slice, report files changed, how you verified, and what is still open. Full-file paste only when asked, or when the file does not exist on disk yet.