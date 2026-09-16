# Changelog body and ship label

Status: binding design
Read when: writing a changelog entry, title “what’s new”, web Phase 7 ship, or Grok Bot PR close-out

Week pins and archive catalog ritual stay on `design/versioning.md`. Open that file only when the User said **new week** or named a pin.

## Changelog files

Authoring unit is **one markdown file per build** for the **current series only**, flat under:

`design/changelog/{label}.md`  
Example: `design/changelog/0.3.10.md`

Prior series are parked under:

`design/changelog/archive/{epoch}.{series}/{label}.md`  
Example: `design/changelog/archive/0.2/0.2.53.md`

Plain text, no code fence when emitted. Body shape:

## Who reads what

| Reader | Reads |
|--------|-------|
| Fresh web / chat, Phases 1–3 | Nothing under `design/changelog/`. Nothing in `version.json` unless work_is_this. |
| Web Phase 7 | This file’s **body shape** only. Writes **one** new `design/changelog/{label}.md`. `{label}` is baked `version.json` `label` with patch + 1 (ignore stamp commits). Do not read older changelog files. Do not write that number back into this file. Do not emit `changelog.json`. First heading `## {label}`, never `# {label}`. |
| Grok Build mid-week slice / catch-up | Nothing under `design/changelog/`. Leave-off + User-named work. |
| Grok Build **new week**, revert, or User asks what shipped | This file’s body shape. Leave-off only if the User asked what is next. Still not every `0.N.*` file. |
| Grok Bot | Reads baked `version.json` only to name `{label}` (patch + 1). Writes **one** new `design/changelog/{label}.md` per shipping PR. First heading `## {label}`, never `# {label}`. Does not hand-edit `changelog.json`. Optional sweep notes go in `_logs/` only. |
| Named revert / what was 0.1.4? | That one file (flat or under `design/changelog/archive/{epoch}.{series}/`). |
| Game | `version.json` + `changelog.json`. |

the changelog directory is not required. Pages `/changelog/` is the public index.

## In-game

- Title / play menu (`scripts/title.gd`) always shows `version.json` `label`.
- If `label` > saved `last_seen_game_ver`, show a gamepad-first “what’s new” overlay **before** Play is used.
- Overlay lists JSON entries with `label` > `last_seen_game_ver`.
- First launch or wiped save: show **the current build only**, then write `last_seen_game_ver`.
- Same series, older patch: show the in-between entries from JSON.
- Older series: show this series’ new entries from JSON, plus a control that opens `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`.
- A / Start or B / Esc dismisses, writes `last_seen_game_ver` = current `label`, focuses Play.
- Persist `last_seen_game_ver` through `save_store.gd` on the live slot. Do not reuse save-schema `"v"`.

## Web / chat Phase 7

After the User is satisfied with the goal’s behavior:

1. Update topic files this slice made wrong (`design/versioning.md` only if the scheme or ritual changed).
2. Author `design/changelog/{label}.md` using baked `scripts/data/version.json` `label` with patch + 1. First heading `## {label}`, never `# {label}`. After the bullets, one `Summary:` line for the in-game overlay. Do not write a `## Agent` section. Do not record that label in this file. Do not read older changelog files.
3. Do not emit `changelog.json` or `version.json` as the ledger. Seed those files only when they do not exist yet on live.

The User pastes. CI stamps the number when the files land on `main`.

## Grok Bot PR close-out

When a Grok Bot PR is ready to merge:

1. Ensure the PR includes `design/changelog/{label}.md` with `{label}` = baked patch + 1 and first heading `## {label}`.
2. Squash-merge into `main` so exactly one user commit lands.
3. CI stamps `version.json` / `changelog.json` and tags `v{label}`.
