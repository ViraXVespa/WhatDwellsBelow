# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | `design/grok-build.md`. Edit live files. Same-system APIs just do; a new cross-system owner or named live-module replace is propose-first. |
| **Web / chat** | You cannot write the repo | `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or a named Bot / refactor sweep | `BOT.md`, then `python tools/bot_status.py`, then one printed Job file. Refactor only, except a `tools/` runner the User approved this session. Ship via branch + PR. |

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
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Load cap (implementation): this file + the path file + (web / Build) the law pair + one writer door + one Job sibling + gates whose `when` matches. A second writer door only when the User names the owner.
Web / chat may picture-read further live scripts and design files when the thread names that system, a shot cannot be explained without that owner, a routes read_when matches, or the User asked who owns it. Budget is turns, not tokens. That is not a license to implement two writer doors in one slice.
Do not fetch this file again. Do not open the topic index or `design/load-graph.md` unless the User named routing work.

Pickup is git plus `_logs/sess/<Grok session id>/`. Fresh Build: this file, then `design/grok-build.md`. Pins are User-only.
Build tile/sheet Imagine: `design/isolated-media.md` first. Web / chat may generate non-tile images. Web does not spawn the isolated media runner and does not Imagine tiled world assets. Grok Bot does not run Imagine.
After a slice: stop and report.
