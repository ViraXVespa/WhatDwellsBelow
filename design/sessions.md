# Grok Build leave-off

Status: working notes  
Read when: starting a fresh Grok Build instance after a gap  
See also: `design/session-log.md`, `design/protocol.md`, `design/grok-build.md`, `design/art-pipeline.md`, `design/player.md`

This is the Grok Build leave-off. It is **not** binding game design. Binding behavior stays in the topic files. The live tree is still the source of truth for shipping code.

Keep this file short. History goes in `design/session-log.md`.

The User does other work between weeks (git commits, stills, systems). **Image-to-video and complex animation packing stay in Grok Build** unless the User says otherwise.

Do not resume unfinished work from this file unless the User names that work. A listed next-work line is a hint, not a start order.

## Leave-off

**Last closed session:** 2026-09-02  
**Closed because:** User approaching usage limit. Walk re-pack had just finished.

### Pickup checklist

1. Read this leave-off.
2. Inspect git / `git status` and the code-map row for the named work. Do not assume this file matches disk.
3. After a gap: read current-series `design/changelog/*.md`. Do not follow git commit links into web-session conversations.
4. Read `design/protocol.md`, `design/constraints.md`, then only the topic files for the requested work.
5. For sprite / I2V / walk work: `design/art-pipeline.md` first, then only `design/art-i2v.md` or `design/art-pack.md` as that door says, plus `tools/i2v_seeds.py`.
6. Read `design/session-log.md` only if this leave-off is not enough to name the next unit, or when writing it at close.

### Likely next (only if the User names it)

1. **Walk cycle quality.** Packer (`tools/pack_locomotion.py`) still picks weak periods on some facings (see `design/session-log.md`). Fix detection before regenerating I2V.
2. **Remaining body I2V** (one clip per unit): attack / special / gather / death / Dispel. Unarmed body. Accepted walk units: female Down, male Down-Left.
3. **Extraction Gate world lighting.** Gen/interact are in.

### Do not redo unless asked

- Re-keying idle with remap + `spill_flood=False`.
- Replacing dungeon clerks with Extraction Gates.
- Splash graffiti treatment (Proudly struck, Shamelessly tag).
- Playtest think-script parse errors (`playtest_ai_think.gd` local helpers).

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
