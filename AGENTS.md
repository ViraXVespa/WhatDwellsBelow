# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Edit live files. Do not dump whole files unless asked. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |

If unsure: ask once, then use **web / chat**. A missed full-file emit is worse than an extra one.

`design/sessions.md` is the **Grok Build** hand-off (leave-off + log). CLI instances read it after a Grok Build gap. Web / chat may read it for context only. It is not the web-session hand-off. Do not resume unfinished Grok Build work from it unless the User names that work.

## Shared

Design lives in `design/`. There is no single GDD. `Demo_GDD.md` is only an index.

Fresh instance: read `design/protocol.md` and `design/constraints.md`, then only the topic files for the requested work. Inspect the live tree. Do not start by archiving or rewriting. Do not read `design/changelog/` unless the requested work is versioning, a named past build, or a revert.

Grok Build after a gap: also read `design/sessions.md`, then every `design/changelog/{current epoch}.{current series}.*.md` (see `design/versioning.md`). Inspect git / the live tree (the User works between Grok Build weeks). Do not open other series or treat `scripts/data/version.json` as the version ledger.

Web / chat after the repo-review message: follow `design/web-session.md`. Do not start Phase 4 emits during Phase 1–3.

| Need | File |
|------|------|
| Workflow | `design/protocol.md` |
| Web / chat session flow | `design/web-session.md` |
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

## Script cap (10KB)

Every live `scripts/**/*.gd` that ships must stay under **10,000 bytes**.

**Grok Build (CLI)** enforces the cap while editing. If a file is over, or an edit would push it over, split in that same slice (steps below).

**Web / chat** does **not** apply the cap while drafting or emitting a file in Phase 4. Do not split, refuse, or rewrite for size until Phase 6. See `design/web-session.md`.

If a file must be split:

1. Split into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, …).
2. Keep the original path as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`. Use `load()` on one side or put shared state on the host.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first; stop after a batch so the User can paste and compile.

## Web / chat

Full conversation flow, emit rules, fetch rules, and Phase 6 sizing: `design/web-session.md`.

The tool card from a page fetch is a summary. The live body is the saved artifact plus a byte check against the GitHub `size`. One fetch per path. Ask the User to paste only when that check failed and no paste is already in the thread.

Phase 7 of a goal that shipped player-visible or agent-visible change also writes one `design/changelog/{label}.md` (see `design/versioning.md`). Do not emit `scripts/data/changelog.json` as the ledger. Do not read prior changelog files to write the new one.

Do not emit a revision assembled from a tool-card summary or a truncated artifact.

Do not claim you wrote the repo. The User pastes.

## CLI

Small diffs. Match surrounding style. After the slice, report files changed, how you verified, and what is still open. Full-file paste only when asked, or when the file does not exist on disk yet.

End of a Grok Build session: update `design/sessions.md` (leave-off + log) and write `design/changelog/{label}.md` for the completion commit when that commit is `0.N.0`. That sessions file is for the next Grok Build instance, not for web / chat.