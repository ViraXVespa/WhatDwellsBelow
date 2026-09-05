# Grok Build session flow

Status: protocol  
Read when: Grok Build (CLI) path; every CLI instance after a gap  
See also: `AGENTS.md`, `design/protocol.md`, `design/versioning.md`, `design/sessions.md`, `design/refactor.md`

This file is binding for **Grok Build (CLI)** only. Web / chat and Copilot ignore it.

The agent can write the checkout. Prefer small diffs on disk. Full-file paste only when the User asks, or when the file does not exist on disk yet.

## Recognize

You can write the live tree. If you cannot, you are not on this path — use `design/web-session.md`.

One session per development week. If the User says the session is a resume after corruption, keep the first `grok_web_w{N-1}` pin and do not create a second Grok Build pin for that week.

## Read order

1. `AGENTS.md`, `design/protocol.md`, `design/constraints.md`.
2. After a gap: `design/sessions.md` (leave-off + log).
3. After a gap: every `design/changelog/{current epoch}.{current series}.*.md` per `design/versioning.md`. Do not open other series. Do not treat `scripts/data/version.json` as the version ledger.
4. Only the topic files that match the requested work (`design/README.md`).
5. Inspect git and the live tree (`project.godot`, `scenes/`, `scripts/`, `assets/`). The User works between Grok Build weeks.
6. Apply the standing week ritual in `design/versioning.md`.

Do not start by archiving or rewriting the live path. Do not read `design/changelog/` except the current-series files above, or when the named work is versioning, a named past build, or a revert.

`design/sessions.md` is this path’s hand-off. It is not the web / chat or Copilot hand-off. Do not resume unfinished Grok Build work from it unless the User names that work.

## Week ritual

Follow `design/versioning.md`. In short:

- Pin current `main` as `grok_web_w{N-1}` (Grok Web Results for the completed week).
- Do not pin `grok_build_wN` until the User’s completion commit (`0.N.0`).
- Resume-after-corruption does not move the web pin.
- Do not create any other archive unless the User asks.

Archived builds are pinned commits in `scripts/data/archive_catalog.json`, not project trees under `archives/`. Do not copy a snapshot into `archives/` or onto live.

## Work

Implement the requested work by patching the live path in place.

- MUST extend, patch, and reuse live scenes, scripts, and architectural decisions unless they contradict binding design or the User’s request.
- MUST NOT replace the live tree with a greenfield rewrite.
- MUST NOT copy archive scripts or scenes over live files as a default strategy.
- The live path remains the orthographic Camera3D system in `design/camera.md`.
- Match surrounding style. GDScript indent is tab characters. Types follow `AGENTS.md` → GDScript types.
- Implement only what design and the User require. Do not invent skills, rarities, hub upgrades, meta-progression, or co-op.
- Open numbers: invent coherent starts, expose them in the secret debug menu, record in `design/tunables.md`. Ambiguity: ask.
- Sprite / I2V / paper-doll work stays on this path unless the User says otherwise. Start at `design/art-pipeline.md`.

## Script cap

Every live `scripts/**/*.gd` that ships must stay under **10,000 bytes**.

Enforce the cap while editing. If a file is over, or an edit would push it over, split in that same slice using `design/refactor.md`. Stop once the file is under 10KB. Do not keep splitting toward Copilot’s 5KB sweep target.

## Archives

The Archives browser MUST ship. Selecting title “Play” always launches the current live path.

Catalog rows (each a pinned commit, isolated per `design/archives.md`):

- **classic_2d** — Classic 2D
- **art_experiment** — Art experiment
- **full_3d_pass** — Full 3D Pass
- **grok_build_w1** — Grok Build Results (Week 1)
- **grok_web_w1** — Grok Web Results (Week 1)
- Plus `grok_web_w{N-1}` and `grok_build_wN` rows required by `design/versioning.md` after each Grok Build week ritual.

## After a slice

Stop and report: files changed, how you verified, what is still open. Do not chain an unrelated goal.

## End of session

Update `design/sessions.md` (leave-off + log).

Write `design/changelog/{label}.md` for the completion commit when that commit is `0.N.0` (see `design/versioning.md`). Do not emit `scripts/data/changelog.json` as the ledger. Do not read prior changelog files to write the new one.

That sessions file is for the next Grok Build instance, not for web / chat or Copilot.

## Do not

- Do not dump whole files unless asked, or the file does not exist on disk yet.
- Do not claim a paste-emit workflow. This path writes the checkout.
- Do not use `design/web-session.md` phases.
- Do not run a Copilot full-repo sweep. If house-wide size/reuse cleanup is the job, that is Copilot.
- Do not write `_logs/` (Copilot only).
- Do not invent a third system when binding design and live code disagree — patch live toward binding or ask.