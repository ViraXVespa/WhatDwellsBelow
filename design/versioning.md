# Versioning and changelog

Status: current plan  
Read when: stamping a build, adding an archive pin, or the User named a pin or archive  


## Scheme

`{epoch}.{series}.{patch}`

| Field | Demo (`epoch` 0) | After 2026-11-18 (`epoch` 1+) |
| --- | --- | --- |
| **epoch** | `0` = in-dev demo | `1` = first release and later. Flip only when the User declares the release build. |
| **series** | Development week | Major update index. Restarts at `0` on `1.0.0`. Later majors (`1.1.0`, …) only when the User names them. |
| **patch** | User-commit index on `main` in that series | Same: user-commit index on `main` in that major |

Week 2 open (also `0.2.0`): `36fb882c9db3b6cd8a83f072d2dfec51d4acedca` (`Grok Build Week 2`).  
Week 3 open (also `0.3.0`): `e7a9d2cf56965b711dc5b22eb7735a1875d96407` (`Grok Build Week 3`).

Do not store a moving “this web goal is …” patch in this file. Do not invent other version fields. Save-schema key `"v"` in `save_store.gd` is unrelated.

## Source of truth

**Git history on `main` assigns the number.**  
The User’s push *is* the bump. `patch` counts only user commits after the last baked `scripts/data/version.json` change, then adds that count to the baked patch. Automated stamp commits (`chore: stamp … [skip ci]`, any `[skip ci]` subject, `github-actions[bot]` bookkeeping) must not increment `patch`. The public label never rewinds.

**`scripts/data/version.json` is the baked copy** the game, title, and changelog script read. Godot and the web export must not call `git`. CI overwrites this file from `main`; agents do not treat it as the ledger and do not hand-edit it in a web Phase 7 unless the User is seeding the file for the first time.

CI on each user push to `main` (not on `[skip ci]` stamp pushes):

1. Resolve series from the latest series-open tag (`v0.2.0`, `v1.0.0`, …) or the documented open SHA.
2. Set `patch` = baked patch + user commits since `version.json` last changed. Ignore stamp / `[skip ci]` subjects. Never go below the baked patch.
3. Write `scripts/data/version.json` (`epoch`, `series`, `patch`, `label`).
4. Create annotated tag `v{label}` if missing.
5. Run `tools/build_changelog.py`.
6. If generated outputs changed, commit them with `[skip ci]`.
7. Deploy Pages from the user push. Pages stamps the same number in the export workspace before Godot runs, because a `GITHUB_TOKEN` stamp push does not start a new workflow. Include `/changelog/`.

Never auto-bump `epoch` or `series`. Extra user pushes with no new `design/changelog/{label}.md` still get a patch number and an empty player note. `doc_patch.py next-label` is baked patch + 1 on the **current** series only. A series seed (`0.N.0`, later `1.M.0`) comes from `week_start.py` (Week sequence), not that tool.

### Merge shape (Grok Bot and multi-commit PRs)

`version.yml` counts **every** non-stamp commit reachable on `main` since `version.json` last changed, in **one** stamp run for that push. So:

| How the PR lands on `main` | Patch effect |
| --- | --- |
| **Squash and merge** (one squash commit) | `+1` — preferred |
| **Rebase and merge** (N commits) | `+N` |
| **Create a merge commit** (merge commit + N branch commits) | `+N` or `+N+1` depending on whether the merge commit’s subject is counted |

Grok Bot PRs squash-merge. A multi-commit branch is fine on the PR; it must become **one** user commit on `main`.

## Week sequence (defined once)

Series `N` is week `N`. The epoch is the User's alone; no tool changes it. In order:

1. **Week close.** A web session writes the closing week's changelog `design/changelog/0.N.0.md`. Build writes no changelog files; its notes are commit messages. The Bot keeps adding player-facing bullets in its PRs.
2. **Week start.** The User runs `tools/week_start.py` (`--dry-run` first). It pins HEAD as `grok_web_w{N}` (catalog row, local tag `archive/grok-web-w{N}`, that series' notes under `archives/docs/`), seeds `version.json` as `{epoch}.{N+1}.0` with `open_commit` = HEAD, creates the local branch `grok-build-w{N+1}` from HEAD, parks old changelogs, runs `grok worktree gc`, deletes Godot locks and clears logs.
3. **Seed commit.** The User commits the seed and pushes `main`, the branch (`git push -u origin grok-build-w{N+1}`) and the tags. That commit is `0.{N+1}.0`.
4. **Build pin.** The series change on `main` creates `grok_build_w{N+1}`: catalog row, tag `archive/grok-build-w{N+1}`, the previous series' notes under `archives/docs/grok_build_w{N+1}/`. A CI trigger does it (spec in `archives-catalog.md`); by hand: `tools/week_pin.py --build {N+1} --commit SHA`. Never invent that SHA.

Build works in worktrees cut from `grok-build-w{N}` and merges back into it (`grok-build.md`). Resume after corruption and mid-week catch-up chats pin nothing. Archive `docs` list `design/` as it is on the pinned commit plus the copied notes. No other new archives unless the User asks. `open_commit` in `version.json` is the commit the series opened from.
