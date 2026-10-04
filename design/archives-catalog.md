# Archives — catalog and pins

Status: current plan  
Read when: classic_2d entry, snapshot tags, week pins, the week-close archive workflow


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

Each week adds `grok_web_w{N}` and `grok_build_w{N}` (sequence: `versioning.md`). Both pin the week-close merge commit, so the two builds are identical on purpose. Those rows use the same isolation rules as the rows above. Rows up to week 5 come from the older flow (web = end of week, build = seed commit) and stay as they are.

No hybrid mode. No shared runtime state, scenes, scripts, or saves. Local Play stamps `application/config/name` on the worktree only (`What Dwells Below — <label>`). Pages exports do the same for IndexedDB isolation.

Tags: `archive/classic-2d`, `archive/art-experiment`, `archive/full-3d-pass`, `archive/grok-build-w1`, `archive/grok-web-w1`, `archive/grok-build-w2`, `archive/grok-web-w2`, `archive/grok-build-w3`, `archive/grok-web-w3`, plus `archive/grok-web-w{N}` and `archive/grok-build-w{N}` for later weeks. CI creates and pushes the weekly tags.

## Creating any other archive

Core rule above still applies (no project-tree copies into `archives/`). User-ordered archives:

1. Pick the commit to freeze. Tag it `archive/<id>`.
2. `python3 tools/week_pin.py --id ID --label L --desc D --commit SHA` (row, no tag).
3. After Pages deploy, Play that row and confirm it is that SHA with zero live-path state. Report to the User.

Weekly pins are automatic (below). `week_pin.py --web N` / `--build N [--commit SHA]` (`--dry-run` first) is the same code by hand: row, notes, local tag; a rerun adds nothing and only fills in a missing tag. Do not move a pin on a resume after corruption.

## Week-close archives (CI)

`.github/workflows/archive.yml` runs on every push to `main` that is not `[skip ci]`. It waits for the Version stamp of that push to finish, then runs `tools/ci_archive.py --before <push base> --commit <pushed sha> --commit-changes --push origin`:

1. **Detect.** The push adds `design/changelog/{epoch}.{N}.0.md` (patch 0, a new file directly in that folder). Moves into `archive/`, `chore: stamp` and other `[skip ci]` commits never match. No such file: stop.
2. **Pin both.** For `grok_web_wN` and `grok_build_wN`, independently: add the missing catalog row at the pushed commit (an existing tag keeps its commit), copy series `N` notes to `archives/docs/<id>/`, create the missing tag `archive/grok-web-wN` / `archive/grok-build-wN`. Row and tag both present: nothing happens, so reruns are safe.
3. **Commit and push.** `chore: archive week N [skip ci]` touches only the catalog and `archives/docs/`. New tags are pushed first, then the commit; a rejected push fetches, rebases that one commit and retries (3 times). Never forced, nothing deleted. The `[skip ci]` commit starts no Version, Pages or archive run.
4. **Pages.** That commit starts no Pages deploy, so the job dispatches `pages.yml` once when something changed; the new rows then export.

Recovery: Actions, Archive, Run workflow, input `week` = N (skips detection; `commit` optional, default the branch tip). Local proof with no GitHub: `python3 tools/ci_archive.py --selftest` (temp origin, squash-merge, stamp commit, rerun, tag repair, push race) and `--dry-run`. If a week is closed without CI, `week_start.py` pins the missing rows at HEAD as catch-up.
