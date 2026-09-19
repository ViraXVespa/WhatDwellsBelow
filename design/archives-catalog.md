# Archives — catalog and pins

Status: binding design  
Read when: classic_2d entry, snapshot tags, week ritual freeze


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
| grok_build_w2 | Grok Build Results (Week 2) | `36fb882c9db3b6cd8a83f072d2dfec51d4acedca` |
| grok_web_w2 | Grok Web Results (Week 2) | `bb70f556108d0e09e070cfaa42260f642af3737a` |
| grok_build_w3 | Grok Build Results (Week 3) | `e7a9d2cf56965b711dc5b22eb7735a1875d96407` |
| grok_web_w3 | Grok Web Results (Week 3) | `b87bd169fb4dce839753a37cb8dbb7a837d82f48` |

After each Grok Build week ritual, also list `grok_web_w{N-1}` and `grok_build_wN` as specified in the versioning gate. Those rows use the same isolation rules as the rows above.

No hybrid mode. No shared runtime state, scenes, scripts, or saves. Local Play stamps `application/config/name` on the worktree only (`What Dwells Below — <label>`). Pages exports do the same for IndexedDB isolation.

Tags: `archive/classic-2d`, `archive/art-experiment`, `archive/full-3d-pass`, `archive/grok-build-w1`, `archive/grok-web-w1`, `archive/grok-build-w2`, `archive/grok-web-w2`, `archive/grok-build-w3`, `archive/grok-web-w3`, plus `archive/grok-web-w{N-1}` and `archive/grok-build-wN` when later pins exist.

## Creating a new archive

Core rule above still applies (no project-tree copies into `archives/`).

User-ordered archives:

1. Pick the commit to freeze. Tag it `archive/<id>`.
2. Add a catalog row (id, label, desc, commit, pages_slug, docs).
3. After Pages deploy, Play that row and confirm it is that SHA with zero live-path state. Report to the User.

Standing Grok Build week pins (no extra prompt). Week-start: `tools/week_start.ps1`. Week-label math: the versioning gate.

1. At init of week N (not a corruption resume): pin current `main` as `grok_web_w{N-1}` — Grok Web Results (Week N-1). Copy that week’s notes from `design/changelog/0.{N-1}.*.md` or `design/changelog/archive/0.{N-1}/` into `archives/docs/grok_web_w{N-1}/`. Prefer running `tools/archive_prior_changelogs.py` when series advances so the live folder stays current-series only. Attach the `design/` tree that exists **on that commit** in `docs[]`.
2. On the User’s completion commit `0.N.0`: pin it as `grok_build_wN` — Grok Build Results (Week N). Copy the **previous** week’s changelog files (flat or under `design/changelog/archive/`) into `archives/docs/grok_build_wN/` if they exist. Run `tools/archive_prior_changelogs.py` after the series seed so prior flat files are parked. Attach the `design/` tree on that commit in `docs[]`.
3. Do not move the web pin if the User later says this is a resume after corruption.
