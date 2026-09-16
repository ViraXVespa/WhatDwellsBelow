# Isolated media jobs

Status: binding design  
Read when: Grok Build is about to call Imagine (`image_gen`, `image_edit`, `image_to_video`) or stage a tile / character still / UI still / I2V unit  
Code: `tools/run_isolated_grok.py`  
Skills: `.grok/skills/imagine-isolated/SKILL.md`, `.grok/skills/i2v-isolated/SKILL.md`

CLI-only. Web / chat and Grok Bot do not run Imagine and do not spawn this runner.


## Default

Isolate. Do not call Imagine in the game-repo session unless a row in **In-session exceptions** matches.

A skill may auto-load so the **parent** follows this file. That is not permission to generate in-repo. The parent stages a scratch directory outside the git tree and runs `tools/run_isolated_grok.py`.

## In-session exceptions

Stay in the current session only when one of these is true:

- The User said to generate in this session / do not isolate.
- Cwd is already an isolated scratch job (the child must generate here).
- The call is `image_edit` on an image already attached in this thread, and re-staging would resend those pixels.
- The runner or `grok` child cannot start. Generate here only if needed, then report the miss.

Cost test: thin child system prompt + one media turn versus this thread’s the repo agent-rules file + history + attachments + one media turn. In-repo Imagine is the exception.

## Kind routing

Load `game-asset-core` plus **one** specialist. Do not load the other game-asset specialists on the same job.

| `--kind` | Bundled skills | Imagine tool | WDB job |
|---|---|---|---|
| `tile` | `imagine`, `game-asset-core`, `game-tilesets` | `image_gen`; `image_edit` only to iterate or as Bible **style** ref | World tile / roof / ground / wall. Seamless. Child runs the `game-tilesets` 2×2 PIL check. |
| `character` | `imagine`, `game-asset-core`, `game-character-consistency` | `image_gen` for a new Bible / style candidate; `image_edit` after lock | Character still, facing variant, overlay-on-body. After lock, edit-chain from the locked Bible or body frame. |
| `i2v` | `imagine`, `game-asset-core`, `game-animation-frames` | `image_to_video` from the staged seed | One unit. Prompt and seed from `tools/i2v_seeds.py`. No fixed 6s/10s clock. Child does not harvest or pack. |
| `ui` | `imagine`, `game-asset-core`, `game-ui-icons` | `image_gen` / `image_edit` | HUD / menu / icon stills. No text in the art. Input glyphs stay `tools/gen_prompt_glyphs.py`. |
| `still` | `imagine`, `game-asset-core` | `image_gen` / `image_edit` | Fallback only. Prefer a tighter kind. |

Locked Bibles (`assets/sprites/player/bible_locked_male.png`, `bible_locked_female.png`) are the style / identity source for later generation. `gdd_reference_bible.jpg` is layout-only. For `tile` / `ui` / `still`, Bibles are read-only style sheets — do not draw the character into the asset. For `character`, they are the identity lock.

Do not vendor bundled skill bodies into this repo. Point at them by name. `job.md` is what stops the child from opening every bundled specialist.

## Scratch

Must resolve **outside** the git tree. A folder under `WhatDwellsBelow/` still walks up to the repo agent-rules file. `--worktree` copies the tree and is the wrong isolator.

Runner: `python tools/run_isolated_grok.py --kind <kind> …`

- Default scratch is `tempfile.TemporaryDirectory()` (OS temp). `--keep` uses `mkdtemp` and prints the path.
- `--bible-style` copies the locked Bibles.
- `--dry-run` still runs `grok inspect`; it does not run `grok -p`.
- Inspect must show **Project Instructions (0)** for this repo. If inspect still names WhatDwellsBelow the repo agent-rules file, refuse to generate.
- Child flags: `grok -p --cwd <scratch> --prompt-file job.md --verbatim --max-turns 8 --disable-web-search --no-subagents --always-approve --output-format plain`
- There is no `--no-memory` flag. Do not invent one.
- Results copied to `--out` exclude staged inputs (`job.md`, Bibles, `--copy`, seed, prompt file).

`--kind i2v` requires `--seed` and `--prompt-file` already produced in the parent by `tools/i2v_seeds.py`.

## Parent still owns

Unit pick, review gate, harvest / pack (the art pipeline / pack job), next-unit permission, week pin. The child only pays for the media turn. Do not `/resume` a fat art thread to “just do one more” clip or tile.

Live roof UV crop in Placeholdia is a seam workaround on the current `plaza_roof.png`. A new seamless tile does not by itself edit `camp` UVs. That is a later slice after the User accepts the still.

## Optional user config

Not repo-owned. `%USERPROFILE%\.grok\config.toml` / `~/.grok/config.toml` may `[skills] disabled` unused bundled names (`resume-claude`, `resume-codex`, `resume-cursor`, `docx`, `pdf`, `pptx`) and may set `[compat.cursor]` / `[compat.claude]` / `[compat.codex]` cells to `false` when those vendor trees are unused. Do not disable `imagine` or the five `game-*` asset skills. Catalog savings are small next to dropping the repo agent-rules file from a media turn.

## Live snapshot

`tools/run_isolated_grok.py` is the shipping runner. Isolated inspect in OS temp shows Project Instructions (0), no project config, bundled game-asset skills present. Repo skills under `.grok/skills/` are CLI doors into this file.
