# Grok Build leave-off

Status: working notes  
Read when: starting a fresh Grok Build instance after a gap  
See also: `design/session-log.md`, `design/protocol.md`, `design/grok-build.md`, `design/art-pipeline.md`, `design/player.md`

This is the Grok Build leave-off. It is **not** binding game design. Binding behavior stays in the topic files. The live tree is still the source of truth for shipping code.

Keep this file short. History goes in `design/session-log.md`.

The User does other work between weeks (git commits, stills, systems). **Image-to-video and complex animation packing stay in Grok Build** unless the User says otherwise.

Do not resume unfinished work from this file unless the User names that work. A listed next-work line is a hint, not a start order.

## Leave-off

**Last closed session:** 2026-09-09  
**Closed because:** User asked for the `0.3.0` changelog and week-3 close. Grok Build Week 3 is complete pending the User’s git commit. `grok_build_w3` is **not** pinned until they send that SHA.

### Pickup checklist

1. Read this leave-off.
2. Inspect git / `git status` and the code-map row for the named work. Do not assume this file matches disk.
3. After a gap: read current-series `design/changelog/*.md`. After `0.3.0` lands, current series is `0.3.*`. Do not follow git commit links into web-session conversations.
4. Read `design/protocol.md`, `design/constraints.md`, then only the topic files for the requested work.
5. For sprite / I2V / walk work: `design/art-pipeline.md` first, then only `design/art-i2v.md` or `design/art-pack.md` as that door says, plus `tools/i2v_seeds.py`.
6. Read `design/session-log.md` only if this leave-off is not enough to name the next unit, or when writing it at close.

### Likely next (only if the User names it)

1. User commits this tree, then sends the SHA. Write that SHA into `design/versioning.md` (Week 3 open), `design/archives.md`, and `scripts/data/archive_catalog.json` as `grok_build_w3`. Tag `archive/grok-build-w3` if not already tagged.
2. **Next CLI that the User opens by saying new week is week 4 init.** Pin then-current `main` as `grok_web_w3`. Do not pin `grok_build_w4` until `0.4.0`.
3. **First named Grok Build work next week: replace all live attack I2V.** Every Down `atk_great_axe` / `atk_staff` / `atk_longbow` on male and female is a **placeholder**. User will bring a new I2V pipeline. Detail: `design/session-log.md` (2026-09-09 animation handoff).
4. User packs walks from `_src/walk_final/` when they choose. Special / gather / death / Dispel / overlays / remaining attack facings still later.

### Do not redo unless asked

- Mid-action video-extract as an I2V seed.
- Prompting I2V with pack-slot / frame-index language.
- Rewriting great-axe MOTION into geometry-only / no-haft / belly-fist language (destroyed motion).
- Re-keying idle with remap + `spill_flood=False`.
- Replacing dungeon clerks with Extraction Gates.
- Splash graffiti treatment (Proudly struck, Shamelessly tag).
- Playtest think-script parse errors (`playtest_ai_think.gd` local helpers).
- Downscaling world stills before chroma key (hurts plate detection). Key at native size, then nearest-neighbor fit.
- 50% quadrant crops of single-subject world stills.
- Consolas / TTF on the Welcome banner.
- Inventing a `grok_build_w3` SHA before the User sends one.

## How to maintain

**Session start** (including mid-week catch-up):

- Read this leave-off.
- Diff live vs git.
- Ask once if between-week work conflicts with a *named* next slice.
- Do not run the week pin ritual unless the User said **new week**.

**Session end:**

- Rewrite this leave-off (date, why we stopped, pickup, likely next, do-not-redo).
- Prepend a factual entry to `design/session-log.md`. Name I2V units: gender, facing, action, seed/path. Do not narrate clips.
- Binding behavior changes still go in the matching topic file, not only here.
