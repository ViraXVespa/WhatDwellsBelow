# Versioning and changelog

Status: binding design  
Read when: stamping a build, writing a changelog entry, Grok Build init, title “what’s new”, or adding an archive pin  
See also: `AGENTS.md`, `design/web-session.md`, `design/protocol.md`, `design/sessions.md`, `design/archives.md`, `design/save-tech.md`, `design/ui.md`

## Scheme

`{epoch}.{series}.{patch}`

| Field | Demo (`epoch` 0) | After 2026-11-18 (`epoch` 1+) |
| --- | --- | --- |
| **epoch** | `0` = in-dev demo | `1` = first release and later. Flip only when the User declares the release build. |
| **series** | Development week | Major update index. Restarts at `0` on `1.0.0`. Later majors (`1.1.0`, …) only when the User names them. |
| **patch** | Commit index on `main` in that series | Same: commit index on `main` in that major |

Week 2 open (also `0.2.0`): `36fb882c9db3b6cd8a83f072d2dfec51d4acedca` (`Grok Build Week 2`).  
This web goal is the next commit on that series: **`0.2.11`**.

Do not invent other version fields. Save-schema key `"v"` in `save_store.gd` is unrelated.

## Source of truth

**Git history on `main` assigns the number.**  
`patch` is the number of commits on `main` after that series’ open commit (`0.2.0`, later `1.0.0`, …). The User’s push *is* the bump.

**`scripts/data/version.json` is the baked copy** the game, title, and changelog script read. Godot and the web export must not call `git`. CI overwrites this file from `main`; agents do not treat it as the ledger and do not hand-edit it in a web Phase 7 unless the User is seeding the file for the first time.

CI on each push to `main`:

1. Resolve series from the latest series-open tag (`v0.2.0`, `v1.0.0`, …) or the documented open SHA.
2. Set `patch` from commits on `main` after that open.
3. Write `scripts/data/version.json` (`epoch`, `series`, `patch`, `label`).
4. Create annotated tag `v{label}` if missing.
5. Run `tools/build_changelog.py`.
6. If generated outputs changed, commit them with `[skip ci]`.
7. Deploy Pages, including `/changelog/`.

Never auto-bump `epoch` or `series`. Extra pushes with no new `design/changelog/{label}.md` still get a patch number and an empty player note.

## Changelog files

Authoring unit is **one markdown file per build**:

`design/changelog/{label}.md`  
Example: `design/changelog/0.2.11.md`

Plain text, no code fence when emitted. Body shape:

## {label}
- Key point
-- Subpoint (optional)
- Key point

Summary: one- or two-sentence session summary

No other sections in the player-facing body. Agent-only revert hints (paths, SHA) may follow a `## Agent` heading; the game and Pages player view ignore that heading.

Do **not** keep a concatenated week file on `main`. Do **not** hand-edit `scripts/data/changelog.json`.

`tools/build_changelog.py` (also run by CI):

- Reads `version.json` for the current `epoch.series`.
- Reads `design/changelog/{epoch}.{series}.*.md`.
- Writes `scripts/data/changelog.json` — **current series only**, newest patch first, bullets + summary only.
- Does not write a week rollup into the repo. Pages week views are built in the Action from the same per-build files.

## Who reads what

| Reader | Reads |
| --- | --- |
| Fresh web / chat, Phases 1–3 | Nothing under `design/changelog/`. Nothing in `version.json` unless the work is this topic. |
| Web Phase 7 | Writes **one** new `design/changelog/{label}.md` for the version this goal already is. Does not emit `changelog.json`. |
| Grok Build init | `design/sessions.md`, then every `design/changelog/{current epoch}.{current series}.*.md`. No index. No other series. |
| Named revert / “what was 0.1.4?” | That one file. |
| Game | `version.json` + `changelog.json`. |

`design/changelog.md` is not required. Pages `/changelog/` is the public index.

## In-game

- Title / play menu (`scripts/title.gd`) always shows `version.json` `label`.
- If `label` > saved `last_seen_game_ver`, show a gamepad-first “what’s new” overlay **before** Play is used.
- Overlay lists JSON entries with `label` > `last_seen_game_ver`.
- First launch or wiped save: show **the current build only**, then write `last_seen_game_ver`.
- Same series, older patch: show the in-between entries from JSON.
- Older series: show this series’ new entries from JSON, plus a control that opens `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`.
- A / Start or B / Esc dismisses, writes `last_seen_game_ver` = current `label`, focuses Play.
- Persist `last_seen_game_ver` through `save_store.gd` on the live slot. Do not reuse save-schema `"v"`.

## Grok Build week ritual

One Grok Build session per week. The User’s single completion commit is `0.N.0` (later `1.M.0` when they name a major) and is tagged as that series open.

**Init (week N), or resume after a corrupted session:**

1. Read `design/sessions.md`.
2. Read `design/changelog/0.N.*.md` (current series only).
3. Inspect git / live tree.
4. Pin **current `main`** as `grok_web_w{N-1}` — label `Grok Web Results (Week {N-1})`. Do not move this pin on resume.
5. Do **not** pin Grok Build Results yet (`0.N.0` does not exist at init).

**User completion commit (`0.N.0`):**

- Pin that commit as `grok_build_wN` — label `Grok Build Results (Week N)`.

Archive `docs` follow `design/archives.md`. Changelog museum copies for those rows:

- Web Results Week N-1 → that week’s per-build markdown (copy under `archives/docs/grok_web_w{N-1}/` so the pin can show files that were not on the old SHA).
- Build Results Week N → previous week’s per-build markdown, if any, under `archives/docs/grok_build_wN/`.

Also attach the `design/` file tree as it exists **on the pinned commit** (`docs[]` paths that `git show` can resolve). Standing order: this ritual may create those two pins without a fresh “please archive” prompt. No other new archives unless the User asks.

## Web / chat Phase 7

After the User is satisfied with the goal’s behavior:

1. Author `design/changelog/{label}.md` for the version this goal assumed at the start (here `0.2.11`).
2. Update topic files this slice made wrong (`design/versioning.md` only if the scheme changed).
3. Do not emit `changelog.json` or `version.json` as the ledger. Seed those files only when they do not exist yet on live.

The User pastes. CI stamps the number when the files land on `main`.