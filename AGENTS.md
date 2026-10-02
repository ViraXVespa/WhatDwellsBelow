# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | `design/grok-build.md`. Edit live files. Same-system APIs just do; a new cross-system owner or named live-module replace is propose-first. |
| **Web / chat** | You cannot write the repo | `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or a named Bot / refactor sweep | `BOT.md`, then `python3 tools/bot_status.py`, then one printed Job file. Refactor only, except a `tools/` runner the User approved this session. Approved smoke runner: `python3 tools/bot_smokes.py` (headless phases only; setup if the Linux pin is missing). Ship via branch + PR. |

If unsure: ask once, then **web / chat**.

## Shared

Design lives in `design/`. Do not collapse it. Never open `notes/`.
Navigation is only `design/routes.yaml`. `See also:` is forbidden.

| Need | File |
|------|------|
| Law (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| Numbers (when they change) | `design/tunables.md` |
| Tools (what runs where, allowlist) | `design/tools.md` |
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Load cap (implementation): this file + the path file + (web / Build) the law pair + one writer door + one Job sibling + gates whose `when` matches. A second writer door only when the User names the owner.
Web / chat, User present: picture-read is uncapped inside `design/` and the live tree the thread is on. Load-graph, topic index, and extra code-map rows are allowed on a docs or routing pass. That is not a license to implement two writer doors in one slice.
Do not fetch this file again. Open `design/load-graph.md` or the topic index when the User named routing work, or on a web docs/routing pass.
Web default after boot is brainstorm. Goal names are memory. Directed-goal starts when the User asks for the list / Phase 3 / emit.

Build pickup is git plus `_logs/<job>/summary.txt`. Those files are PC job output, not web-chat memory. Fresh Build: this file, then `design/grok-build.md`. Pins are User-only.
Web build-coop / build-week gather with pack_grok_sessions / report_grok_sessions; the paste is the packet.
Build tile/sheet Imagine: `design/isolated-media.md` first. Web / chat may generate non-tile images. Web does not spawn the isolated media runner and does not Imagine tiled world assets. Grok Bot does not run Imagine.
After a slice: stop and report, with the rough edges you hit (`design/tools.md` rule 9).
