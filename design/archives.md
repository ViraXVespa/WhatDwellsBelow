# Archived builds

Status: binding design
Read when: touching Archives UI, Pages exports, or catalog pins
Code: `scripts/ui/archives_ui.gd`, `scripts/data/archives_catalog.gd`, `scripts/data/archives_launch.gd`, `scripts/data/archive_catalog.json`, `scripts/ui/loader.gd`
See also: `design/protocol.md`, `design/save-tech.md`

## Core rule

Archived builds are **pinned git commits**, not folders copied into the live tree.

- Do not copy snapshot projects into `archives/`.
- Do not copy them onto the live path.
- Do not back-port live changes into a pinned commit.
- Do not create a new archive unless the User explicitly asks.

`scripts/data/archive_catalog.json` is the catalog. Slim museum markdown that is **not** in a pin lives under `archives/docs/<id>/`.

## Selectable builds

Title **Play** always launches live.

The Archives browser lists every catalog row. Play on a row launches **that commit** as its own Godot project (local worktree) or opens its Pages export (web).

| Id | Label | Commit |
|----|-------|--------|
| classic_2d | Classic 2D | `e26b7e26296b21e4eabedd8f3a077fff1a78bab4` |
| art_experiment | Art experiment | `6139229acc681f2a3045f128dead7564e5af153f` |
| full_3d_pass | Full 3D Pass | `71ea80a42cb4fd09cafd7b5a0327709541aa309c` |
| grok_build_w1 | Grok Build Results (Week 1) | `49a3018247628545df8690a8d52ff334cda342a2` |
| grok_web_w1 | Grok Web Results (Week 1) | `205c5c3e6397ba08c21eede1ba19eb2c94d02487` |

No hybrid mode. No shared runtime state, scenes, scripts, or saves. Local Play stamps `application/config/name` on the worktree only (`What Dwells Below — <label>`). Pages exports do the same for IndexedDB isolation.

Tags: `archive/classic-2d`, `archive/art-experiment`, `archive/full-3d-pass`, `archive/grok-build-w1`, `archive/grok-web-w1`.

## Play

**Web:** loader overlay, then `OS.shell_open` the catalog `pages_url`. The archive is a pre-exported Godot Web build under GitHub Pages. Never spawn Godot or checkout in the browser.

**Editor / desktop with git:** reuse `scripts/ui/loader.gd`. Checkout `.archive_worktrees/<id>` (gitignored) if needed, stamp the project name, headless `--import` if `.godot/` is missing, then spawn Godot `--path` that worktree. Keep frames pumping. B / Esc cancels before spawn.

**No git / packaged exe:** same as web (Pages URL).

Cached worktree + existing import: short “Opening snapshot…” beat, no re-import.

## Pages

Live site root is the current HEAD export. Each archive is `https://viraxvespa.github.io/WhatDwellsBelow/<pages_slug>/`.

GitHub Actions (`.github/workflows/pages.yml`) exports HEAD plus every catalog SHA. Binaries are not stored on `main`. Local preview: `powershell -File tools/export_web.ps1 -Archives` → `_pages/`.

Repo setting: Pages source = GitHub Actions.

## Creating a new archive (User-ordered only)

1. Pick the commit to freeze. Tag it `archive/<id>`.
2. Add a catalog row (id, label, desc, commit, pages_slug, docs).
3. Do not copy the project tree into `archives/`.
4. After Pages deploy, Play that row and confirm it is that SHA with zero live-path state. Report to the User.

## Archives browser UI

Opened from Pause → System.

- Left: vertical list of catalog rows.
- Right: info panel — description, Video (disabled if missing), Documents, Play.
- Documents: `archives/docs/<id>/` first, else `git show <sha>:<path>` locally, else GitHub raw on web. Truncate long files.

List MUST include Classic 2D, Art experiment, Full 3D Pass, Grok Build Results (Week 1), and Grok Web Results (Week 1). Videos do not exist yet; the Video button stays disabled until they do.
