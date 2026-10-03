# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

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
| Law (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| New or moved script placement (cluster folders) | `design/refactor.md` (Cluster folders section only) |
| Numbers (when they change) | `design/tunables.md` |
| Tools (what runs where, allowlist) | `design/tools.md` |
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Load cap (implementation): this file + the path file + (web / Build) the law pair + one writer door + one Job sibling + gates whose `when` matches. A second writer door only when the User names the owner.
Do not fetch this file again. Open `design/load-graph.md` or the topic index when the User named routing work, or on a web docs/routing pass.

Build pickup is git plus `_logs/<job>/summary.txt`. Those files are PC job output, not web-chat memory. Fresh Build: this file, then `design/grok-build.md` (its first step classifies the request as new feature or change). Pins are User-only.
Imagine (Build only): `design/isolated-media.md` first. Web / chat and Grok Bot never run the isolated runner.
After a slice: stop and report, with the rough edges you hit (`design/tools.md` rule 9).
