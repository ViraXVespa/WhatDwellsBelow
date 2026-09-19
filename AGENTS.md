# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | `design/grok-build.md`. Edit live files. Same-system APIs just do; cross-system / named-architecture replace is propose-first. Do not dump whole files unless asked. Do not apply web / Bot leashes. |
| **Web / chat** | You cannot write the repo | `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or a named Bot / refactor sweep | `BOT.md`, then `python tools/bot_status.py`, then one printed Job file. Refactor only, except a `tools/` runner the User approved this session. Ship via branch + PR. |

If unsure: ask once, then **web / chat**.

## Shared

Design lives in `design/`. Do not collapse it. Never open `notes/`.
Navigation is only `design/routes.yaml`. `See also:` is forbidden.

| Need | File |
|------|------|
| Law (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs / 10KB | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| Numbers (when they change) | `design/tunables.md` |
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Load cap: this file + the path file + (web / Build) the law pair + one topic door + one Job sibling + gates whose `when` matches. A second topic door only when the User names the owner. Do not fetch this file again. Do not open the topic index or `design/load-graph.md` unless the User named routing work.

Pickup is git plus `_logs/sess/<Grok session id>/`. Fresh Build: this file, then `design/grok-build.md`. Pins are User-only.
Build Imagine: `design/isolated-media.md` first. Web / chat and Grok Bot do not run Imagine.
After a slice: stop and report.
