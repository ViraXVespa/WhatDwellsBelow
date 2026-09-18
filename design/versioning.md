# Versioning and changelog

Status: binding design  
Read when: stamping a build, adding an archive pin, or the User said **new week**  


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
The User’s push *is* the bump. `patch` counts only user commits after the last baked `scripts/data/version.json` change, then adds that count to the baked patch. Automated stamp commits (`chore: stamp … [skip ci]`, any `[skip ci]` subject, `github-actions[bot]` bookkeeping) MUST NOT increment `patch`. The public label MUST never rewind.

**`scripts/data/version.json` is the baked copy** the game, title, and changelog script read. Godot and the web export must not call `git`. CI overwrites this file from `main`; agents do not treat it as the ledger and do not hand-edit it in a web Phase 7 unless the User is seeding the file for the first time.

CI on each user push to `main` (not on `[skip ci]` stamp pushes):

1. Resolve series from the latest series-open tag (`v0.2.0`, `v1.0.0`, …) or the documented open SHA.
2. Set `patch` = baked patch + user commits since `version.json` last changed. Ignore stamp / `[skip ci]` subjects. Never go below the baked patch.
3. Write `scripts/data/version.json` (`epoch`, `series`, `patch`, `label`).
4. Create annotated tag `v{label}` if missing.
5. Run `tools/build_changelog.py`.
6. If generated outputs changed, commit them with `[skip ci]`.
7. Deploy Pages from the user push. Pages stamps the same number in the export workspace before Godot runs, because a `GITHUB_TOKEN` stamp push does not start a new workflow. Include `/changelog/`.

Never auto-bump `epoch` or `series`. Extra user pushes with no new `design/changelog/{label}.md` still get a patch number and an empty player note. `tools/next_changelog_label.py` is baked patch + 1 on the **current** series only. A series seed (`0.N.0`, later `1.M.0`) is the User’s named completion commit, not that tool.

### Merge shape (Grok Bot and multi-commit PRs)

`version.yml` counts **every** non-stamp commit reachable on `main` since `version.json` last changed, in **one** stamp run for that push. So:

| How the PR lands on `main` | Patch effect |
| --- | --- |
| **Squash and merge** (one squash commit) | `+1` — preferred |
| **Rebase and merge** (N commits) | `+N` |
| **Create a merge commit** (merge commit + N branch commits) | `+N` or `+N+1` depending on whether the merge commit’s subject is counted |

Grok Bot PRs MUST squash-merge. A multi-commit branch is fine on the PR; it must become **one** user commit on `main`.

## Grok Build week ritual

Several concurrent Grok Build CLI sessions may share one week. The User’s single completion commit is `0.N.0` (later `1.M.0` when they name a major) and is tagged as that series open.

Run the **init pin** only when the User opens a CLI session by saying **new week**. Token refresh counts only if they say that. A mid-week new CLI chat (including a concurrent role) is a catch-up: no pin. Resume after corruption does not move the web pin and does not create a second Grok Build pin for that week.

**Init (week N), only after the User said new week:**

1. Run `powershell -File tools/week_start.ps1` (pins `grok_web_w{current series}` at HEAD, seeds the next series).
2. This file’s body shape. Do not ingest every `design/changelog/0.N.*.md`.
3. Inspect git / live tree from one `design/code-map.md` row.
4. Pin **current `main`** as `grok_web_w{N-1}` — label `Grok Web Results (Week {N-1})`.
5. Do **not** pin Grok Build Results yet (`0.N.0` does not exist at init).

**User completion commit (`0.N.0`):**

- Pin that commit as `grok_build_wN` — label `Grok Build Results (Week N)`.

Archive `docs` follow archives. Changelog museum copies for those rows:

- Web Results Week N-1 → that week’s per-build markdown from `design/changelog/` or `design/changelog/archive/0.{N-1}/` (copy under `archives/docs/grok_web_w{N-1}/` so the pin can show files that were not on the old SHA).
- Build Results Week N → previous week’s per-build markdown, if any, under `archives/docs/grok_build_wN/`.

Also attach the `design/` file tree as it exists **on the pinned commit** (`docs[]` paths that `git show` can resolve). Standing order: when the User has said **new week**, this ritual may create those two pins without a fresh “please archive” prompt. No other new archives unless the User asks.
