# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Implementation is unconstrained there (same-system APIs just do; cross-system / named-architecture replace is propose-first). Do not dump whole files unless asked. Do not apply web / Bot leashes to this path. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or the User named a Grok Bot path / refactor sweep | One product. `BOT.md`, then `python tools/bot_status.py`, then exactly one printed Job file. Refactor only, except a new `tools/` runner the User approved this session. Ship via branch + PR. |

If unsure: ask once, then use **web / chat** if still uncertain. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. Do not collapse `design/` into one document.
Never open `notes/`. Files there are human scratch, not binding, not a door.

Navigation is only `design/routes.yaml`. Do not treat `See also:` as a load list; that field is forbidden. Open a file when this Path table, a routes.yaml door / job / gate, or the User names that work.

| Need | File |
|------|------|
| Law (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs / 10KB | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| Numbers (when the work changes them) | `design/tunables.md` |
| Local inventory / verify / Windows write | pc-offload skill + `design/pc-offload.md` |

Path procedures live in the Path table session file. Do not open the topic index or the load-graph sketch unless the User named the index or routing work.

**Load cap (soft):** this file + the path session file + (web / Build only) `design/protocol.md` and `design/constraints.md` + one topic door + one Job-table sibling. Gates whose `when` matches, including `design/gdscript-law.md` when editing GDScript and `design/pc-offload.md` when measuring, inventorying, or writing on Windows. `design/tunables.md` when numbers change. `design/versioning.md` when the User named a pin or archive. `design/versioning-log.md` at ship label. `design/code-map.md` is one system row. A second topic door only when the User names the owner. Law / gates / one code-map row are not topic doors.

Web / Build: the path file loads the law pair if they are missing, then only the topic door for named work. Bot: `BOT.md` + `python tools/bot_status.py` + one Job file. Do not fetch this file again.

Pickup is git plus `_logs/sess/<Grok session id>/` postcards. Fresh Build instance: this file, then `design/grok-build.md`. A new session in the same instance is not a new week. Pins are User-only.

Build Imagine: `design/isolated-media.md` before any Imagine call. Details stay on the Build path file. Web / chat and Grok Bot do not run Imagine.

After a slice: stop and report.
