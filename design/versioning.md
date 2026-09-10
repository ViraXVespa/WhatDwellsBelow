# Versioning and changelog

Status: binding design  
Read when: stamping a build, writing a changelog entry, Grok Build init, title “what’s new”, or adding an archive pin  
See also: `AGENTS.md`, `design/web-session.md`, `design/grok-build.md`, `design/copilot-session.md`, `design/protocol.md`, `design/sessions.md`, `design/session-log.md`, `design/archives.md`, `design/save-tech.md`, `design/ui.md`

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
7. Deploy Pages from the user push. Pages stamps the same number in the export workspace before Godot runs (`design/save-tech.md`), because a `GITHUB_TOKEN` stamp push does not start a new workflow. Include `/changelog/`.

Never auto-bump `epoch` or `series`. Extra user pushes with no new `design/changelog/{label}.md` still get a patch number and an empty player note.

## Changelog files

Authoring unit is **one markdown file per build**:

`design/changelog/{label}.md`  
Example: `design/changelog/0.2.53.md`

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
|--------|-------|
| Fresh web / chat, Phases 1–3 | Nothing under `design/changelog/`. Nothing in `version.json` unless the work is this topic. |
| Web Phase 7 | Writes **one** new `design/changelog/{label}.md`. `{label}` is baked `version.json` `label` with patch + 1 (ignore stamp commits). Do not write that number back into this file. Do not emit `changelog.json`. |
| Grok Build after a gap | `design/sessions.md`, then every `design/changelog/{current epoch}.{current series}.*.md`. No index. No other series. Do not follow git commit links into web-session conversations. |
| Copilot | Nothing under `design/changelog/`. Nothing in `version.json`. Sweep notes go in `_logs/` only. |
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

One Grok Build session family per week. The User’s single completion commit is `0.N.0` (later `1.M.0` when they name a major) and is tagged as that series open.

Run the **init pin** only when the User opens the CLI session by saying **new week**. Token refresh counts only if they say that. A mid-week new CLI chat is a catch-up: no pin. Resume after corruption does not move the web pin and does not create a second Grok Build pin for that week.

**Init (week N), only after the User said new week:**

1. Read `design/sessions.md`.
2. Read `design/changelog/0.N.*.md` (current series only).
3. Inspect git / live tree from the code map.
4. Pin **current `main`** as `grok_web_w{N-1}` — label `Grok Web Results (Week {N-1})`.
5. Do **not** pin Grok Build Results yet (`0.N.0` does not exist at init).

**User completion commit (`0.N.0`):**

- Pin that commit as `grok_build_wN` — label `Grok Build Results (Week N)`.

Archive `docs` follow `design/archives.md`. Changelog museum copies for those rows:

- Web Results Week N-1 → that week’s per-build markdown (copy under `archives/docs/grok_web_w{N-1}/` so the pin can show files that were not on the old SHA).
- Build Results Week N → previous week’s per-build markdown, if any, under `archives/docs/grok_build_wN/`.

Also attach the `design/` file tree as it exists **on the pinned commit** (`docs[]` paths that `git show` can resolve). Standing order: when the User has said **new week**, this ritual may create those two pins without a fresh “please archive” prompt. No other new archives unless the User asks.

## Web / chat Phase 7

After the User is satisfied with the goal’s behavior:

1. Update topic files this slice made wrong (`design/versioning.md` only if the scheme or ritual changed).
2. Author `design/changelog/{label}.md` using baked `scripts/data/version.json` `label` with patch + 1. Do not record that label in this file.
3. Do not emit `changelog.json` or `version.json` as the ledger. Seed those files only when they do not exist yet on live.

The User pastes. CI stamps the number when the files land on `main`.
