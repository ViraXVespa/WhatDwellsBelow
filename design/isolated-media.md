# Isolated media jobs

Status: binding design  
Read when: Grok Build is about to call Imagine (`image_gen`, `image_edit`, `image_to_video`) or stage a tile / character still / UI still / I2V unit  
Code: `tools/run_isolated_grok.py`  
Skills: `.grok/skills/imagine-isolated/SKILL.md`, `.grok/skills/i2v-isolated/SKILL.md`

This file is the Imagine **gate**. It is not an art-pipeline job. Grok Build must load it before any `image_gen`, `image_edit`, or `image_to_video` call.
CLI-only. Web / chat and Grok Bot do not run Imagine and do not spawn this runner.


## Default

Isolate. Do not call Imagine in the game-repo cwd unless a row in **In-session exceptions** matches. Project hook `.grok/hooks/wdb-pretool.json` denies Imagine/I2V when cwd is this repo.

A skill may auto-load so the **parent** follows this file. That is not permission to generate in-repo. The parent stages a scratch directory outside the git tree and runs `tools/run_isolated_grok.py`.

## In-session exceptions

Stay in the current session only when one of these is true:

- The User said to generate in this session / do not isolate.
- Cwd is already an isolated scratch job (the child must generate here).
- The call is `image_edit` on an image already attached in this thread, and re-staging would resend those pixels.
- The runner or `grok` child cannot start. Generate here only if needed, then report the miss.

Cost test: thin child system prompt + one media turn versus this thread’s the repo agent-rules file + history + attachments + one media turn. In-repo Imagine is the exception.

## Kind routing

Load `game-asset-core` plus **one** specialist. Do not load other_game_asset_specialists_on_the_same.

| `--kind` | Bundled skills | Imagine tool | WDB job |
|---|---|---|---|
| `tile` | `imagine`, `game-asset-core`, `game-tilesets` | `image_gen` once | World tile / roof / ground / wall. Seamless. Child does not open skill files, retry, or composite. Parent runs the `game-tilesets` 2×2 PIL check. |
| `character` | `imagine`, `game-asset-core`, `game-character-consistency` | `image_gen` for a new Bible / style candidate; `image_edit` after lock | Character still, facing variant, overlay-on-body. After lock, edit-chain from the locked Bible or body frame. |
| `i2v` | `imagine`, `game-asset-core`, `game-animation-frames` | `image_to_video` from the staged seed | One unit. Prompt and seed from `tools/i2v_seeds.py`. No fixed 6s/10s clock. Child does not harvest or pack. |
| `ui` | `imagine`, `game-asset-core`, `game-ui-icons` | `image_gen` / `image_edit` | HUD / menu / icon stills. No text in the art. Input glyphs stay `tools/gen_prompt_glyphs.py`. |
| `still` | `imagine`, `game-asset-core` | `image_gen` / `image_edit` | Fallback only. Prefer a tighter kind. |

Locked Bibles (`assets/sprites/player/bible_locked_male.png`, `bible_locked_female.png`) are the style / identity source for later generation. `gdd_reference_bible.jpg` is layout-only. For `tile` / `ui` / `still`, Bibles are read-only style sheets — do not draw the character into the asset. For `character`, they are the identity lock.

Do not vendor bundled skill bodies into this repo. Point at them by name. `job.md` is what stops the child from opening every bundled specialist.

## Scratch

Must resolve **outside** the git tree. A folder under `WhatDwellsBelow/` still walks up to the repo agent-rules file. `--worktree` copies the tree and is the wrong isolator.

Runner: `python tools/run_isolated_grok.py --kind <kind> …`

- Default one-shot scratch is `tempfile.TemporaryDirectory()` (OS temp). `--keep` uses `mkdtemp` and prints the path. `--no-reuse` forces that path.
- With staged reference images (Bibles, `--copy`, I2V seed) the default is a durable scratch under `%USERPROFILE%\.grok\wdb-iso\work\<ref_key>\` (or `$GROK_HOME/wdb-iso/...`). Catalog: `wdb-iso/catalog.json`. Key is SHA-256 of `--kind` plus each reference filename and file hash. Prompt text / brief is not in the key.
- `--bible-style` copies the locked Bibles.
- `--dry-run` still runs `grok inspect`; it does not run the child generate.
- Inspect proof is one line: `inspect=ok instructions=0`. The runner does not forward the skill roster. If inspect still names WhatDwellsBelow the repo agent-rules file, or instructions ≠ 0, refuse to generate.
- Child flags: `grok --prompt-file job.md --cwd <scratch> --verbatim --max-turns 8 --disable-web-search --no-subagents --always-approve --output-format plain`
- Reuse: first run is ingest (`ingest.md`, `--output-format json`) then generate. Later runs with the same key `--resume <ingest_session> --fork-session` so the ingest session stays at “after the reads.” CLI has no `rewind`; fork-from-ingest is the token win. There is no `--no-memory` flag. Do not invent one.
- `job.md` orders one media call, copy the Imagine output into scratch as the dest filename, then stop. Do not tell the child to open skill files, 2×2 composite, or retry. After a cache hit, tell it the references are already in the conversation.
- Results copied to `--out` exclude staged inputs (`job.md`, Bibles, `--copy`, seed, prompt file).

`--kind i2v` requires `--seed` and `--prompt-file` already produced in the parent by `tools/i2v_seeds.py`.

## Parent still owns

Unit pick and next-unit permission stay on the parent. Pack, review, and bible are not this gate. After the User names that unit, open art_pipeline then one job. The child only pays for the media turn (one Imagine call + copy into scratch). Ingest of the same reference set is cached and forked, not re-read. 2×2 / 4×4 seam checks and retries stay on the parent. Do not `/resume` a fat art thread to “just do one more” clip or tile. The ingest-cache `--resume` is the runner, not that ban.

Placeholdia roofs sample the full `plaza_roof.png` in `camp_build_mesh.gd` `roof_mat` (`fract` wrap). Do not put a V crop back unless a new tile bakes a cap/footer.

## Optional user config

Not repo-owned. `%USERPROFILE%\.grok\config.toml` / `~/.grok/config.toml` may `[skills] disabled` unused bundled names (`resume-claude`, `resume-codex`, `resume-cursor`, `docx`, `pdf`, `pptx`) and may set `[compat.cursor]` / `[compat.claude]` / `[compat.codex]` cells to `false` when those vendor trees are unused. Do not disable `imagine` or the five `game-*` asset skills. Catalog savings are small next to dropping the repo agent-rules file from a media turn.

## Live snapshot

`tools/run_isolated_grok.py` is the shipping runner. Isolated inspect prints `inspect=ok instructions=0` (no roster dump). Repo skills under `.grok/skills/` are CLI doors into this file. Reference ingest sessions are keyed in `~/.grok/wdb-iso/catalog.json`. After generate: `dest=ok|missing` and `modelCalls=` when usage.json exists.
