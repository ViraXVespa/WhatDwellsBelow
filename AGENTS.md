# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

**Intent (Build).** Vira is the conduit for design; Grok Build is the conduit for implementation. Make her vision real with little friction. Design docs are the living plan, the road we are building and not the route we have to take; the game is an evolving ecosystem. Defer to her on design, and suggest improvements or ask in the moment with a question prompt (nothing to write down). Hard rules stay: gates before a PR, no hand-edited PNGs, no gate loops, never push `main`.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | `design/grok-build.md`. Edit live files. Same-system APIs just do; design decisions, a new cross-system owner or a named live-module replace are asked first (`ask_user_question`, even under always-allow). |
| **Web / chat** | You cannot write the repo | `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or a named Bot / refactor sweep | `BOT.md`, then `python3 tools/bot_status.py`, then one printed Job file. Refactor only, except a `tools/` runner the User approved this session. Smokes, shots and gates: `BOT.md`. Ship via branch + PR. |

If unsure: ask once, then **web / chat**.

## Shared

Design lives in `design/`. Do not collapse it. Never open `notes/`.
Navigation is only `design/routes.yaml`. `See also:` is forbidden.

| Need | File |
|------|------|
| Plan (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| New or moved script placement (cluster folders) | `design/refactor.md` (Cluster folders section only) |
| Numbers (when they change) | `design/tunables.md` |
| Tools (what runs where, new-tool rule) | `design/tools.md` |
| Prove a change (any surface), extend a tool instead of working around it | `design/prove.md` |
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Reading (implementation): this file + the path file + (web / Build) the plan pair + the topic doc and gates whose `when` matches. **A job that touches several systems: read first.** List every system, then read each one's doc and code-map row before changing anything (no tunnel vision).
Do not fetch this file again. Open `design/load-graph.md` or the topic index when the User named routing work, or on a web docs/routing pass.

Build pickup is git plus `read_summary.py --job <name>` (`_logs/` is PC job output, not web-chat memory). Fresh Build: this file, then `design/grok-build.md` (its first step classifies the request as new feature or change). Archive pins are CI-only (`ci_archive.py`); agents never pin. A doc and its code disagree: compare their history (`list_changed.py --history`, `design/prove.md`), trust the newer, ask if unclear.
Imagine (Build only): `design/isolated-media.md` first. Web / chat and Grok Bot never run the isolated runner.
Chain related steps; report when the work is done, with the rough edges you hit (`design/tools.md` rule 9). Build and Web may add a tool that will help later (rule 5) and tell the User afterward.
