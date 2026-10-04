# Archives — catalog and pins

Status: current plan  
Read when: classic_2d entry, snapshot tags, week pins, the Build-pin CI trigger


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
| grok_build_w4 | Grok Build Results (Week 4) | `03fa012959474ce995f48bf76e3e7677ea379a4d` |
| grok_web_w4 | Grok Web Results (Week 4) | `313bb3e3dce29a3d75f4214c0cdadfe16ef9ba00` |
| grok_build_w5 | Grok Build Results (Week 5) | `75b3bea979bf0fc530ab9660ca177c327eb465d8` |

Each week adds `grok_web_w{N}` and `grok_build_w{N}` (sequence: `versioning.md`). Those rows use the same isolation rules as the rows above.

No hybrid mode. No shared runtime state, scenes, scripts, or saves. Local Play stamps `application/config/name` on the worktree only (`What Dwells Below — <label>`). Pages exports do the same for IndexedDB isolation.

Tags: `archive/classic-2d`, `archive/art-experiment`, `archive/full-3d-pass`, `archive/grok-build-w1`, `archive/grok-web-w1`, `archive/grok-build-w2`, `archive/grok-web-w2`, `archive/grok-build-w3`, `archive/grok-web-w3`, plus `archive/grok-web-w{N}` and `archive/grok-build-w{N}` for later weeks. The User pushes tags.

## Creating a new archive

Core rule above still applies (no project-tree copies into `archives/`).

User-ordered archives:

1. Pick the commit to freeze. Tag it `archive/<id>`.
2. Add a catalog row (id, label, desc, commit, pages_slug, docs).
3. After Pages deploy, Play that row and confirm it is that SHA with zero live-path state. Report to the User.

Weekly pins follow the week sequence in `versioning.md`: `week_start.py` writes `grok_web_w{N}`; `week_pin.py --build N --commit SHA` writes `grok_build_w{N}` (row plus local tag; `--web N` for the web row; `--dry-run` first). Do not move the web pin on a resume after corruption.

## CI trigger for the Build pin (spec for a web session)

The Bot cannot edit workflows, so a web session adds this step to the push-to-`main` workflow:

1. Read `series` from `scripts/data/version.json` at `HEAD` and at `HEAD^`. Equal: stop. Different: `N` is the new series and the pinned commit is the first commit whose `version.json` shows it (the seed commit).
2. If tag `archive/grok-build-w{N}` or catalog row `grok_build_w{N}` exists, do nothing for that part.
3. Run `python3 tools/week_pin.py --build N --commit SHA` (row, local tag, notes under `archives/docs/grok_build_w{N}/`), commit the catalog change with `[skip ci]`, push the commit and the tag.
4. Never change `epoch` or `series`. Needs `contents: write`.
