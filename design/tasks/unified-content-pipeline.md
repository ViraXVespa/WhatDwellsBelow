# WDB Unified Art & Content Pipeline – Standing Task
id: unified-content-pipeline
owner: build
status: open
done-when: All deliverables are complete, the entire system works as described, and the existing.
door: art_pipeline

## Goal
Build a single, project-wide art and content authoring system that every asset type in WhatDwellsBelow flows through. Users must be able to create, edit, and implement every aspect of a subject (visuals + structured data + behavior hooks + audio references) directly through one pipeline. Final outputs obey the art bible (128×128 integer grid, nearest-neighbor, palette snapping, clean alpha) and become the single source of truth for the game via JSON/YAML export. The mobile ComfyUI interface already in the repo is updated to serve as the clean primary UI for the entire system.

Users can also start from loose external references (image upload, URL, or X/Twitter post) and be walked through the full review/adjustment flow until a usable in-game character is produced. The pipeline can use local LLMs (including vision models) to automatically tune generations toward the locked female character artstyle.

**This outline is a baseline recommendation only.** Sections may be expanded, split, merged, or restructured during implementation as real usage reveals better shapes. Improvements are expected on the fly rather than treated as scope changes. You have complete design control over this system until the task is closed.

The final system should be feature complete and user friendly when accessed via the web on a mobile or desktop browser. The workflow should be logical and easy to follow.

This system should also be able to track what files/assets still need to be updated for the game to be feature complete.

## Context & Constraints from Prior Discussion
This task is the culmination of an extended design discussion. The following context is required for a clean implementation and is **not** fully discoverable from the repo alone:

- **Target hardware**: The user’s local machine has 16 GB VRAM. All generation paths must stay inside this limit via staging, INT8/GGUF weights, and explicit model unloading. Previous explorations of heavy Wan 2.2 14B animation workflows were rejected for this reason.
- **Repo anchors** (read these first):
  - The content pipeline door (`design/art-pipeline.md`, then one sibling). Ship frames stay 128×128, nearest-neighbor, clean alpha, 8 directions.
  - `python tools/media.py pipeline` is the CLI. Pack and rekey stay for the strips already in the game. Do not use them for new art.
  - The mobile UI (`tools/lib/media/mobile_ui/` + `tools/lib/media/mobile_ui_server.py`, served on :8189, proxies ComfyUI on :8188). The pipeline studio job is `design/content-pipeline-ui.md`.
- **Models on this PC** (16 GB, one family at a time):
  - Qwen Image 2.1 int8 writes stills. Qwen3-VL (`qwen3-vl:8b`) checks the prompt that was sent, four clauses at a time.
  - Hunyuan3D 2.1 builds the body from a passing text-only front still. The shape graph is image-only.
  - Pixal3D int8, Pixal3D multiview int8, and TRELLIS.2 int8 (plus both VAEs) are on disk. They copy the plate.
  - A text edit is a Qwen still plus Hi3D v1.0 INT8 refining the kept mesh. Hi3D does not read text. It will not invent detail the still does not show. Its encoders are public DINOv2 Large and CLIP ViT-L/14.
  - MotionBricks SOMA FP16 is on disk and is not wired. Stable Audio was measured and is not the character path. Wan 2.2 14B stays out.
- **Green-field game systems**: Many features the pipeline must support do not yet exist (full character customization/paperdoll, Enemy Log, multiple biomes, Vylenheim city buildings, conditional dialog, weapon skills, etc.). Gear/inventory and basic enemy systems do exist. “Reconfigure the game” includes making data-driven paths live.
- **Mannequin vs equipped-first rationale**:
  - Characters use a clean mannequin as the locked source of truth for modularity (paperdoll, 8-dir, animation, 3D). Equipped default-loadout is reference only.
  - Enemies use the fully equipped look as primary source. Enemy weapons stay hardcoded to that design.
  - New body/gender types are added by locking a new mannequin front+side pair.
- **Prompt philosophy**: Character-specific details + reusable operational/“skill-like” prompts. Shared prompt updates warn rather than silently invalidate.
- **Dirty-flag philosophy**: Never silently invalidate work. Immediate propagation on Local save. Flag re-shown on next regen attempt then cleared.
- **Preview expectation**: Heavy pack-to-worktree + in-game capture should reuse existing tooling (`shots.py`, `release.py`, etc.) where possible.
- **Export format**: JSON/YAML chosen for readability and pipeline ownership.
- **Artstyle target**: The current locked female character art is the style reference. The pipeline must be able to drive automatic tuning loops (via local LLMs + vision) so generations converge on that style with minimal manual prompt work.
- **Companion work**: An open-code-skills task is establishing Qwen3-VL as default eyes plus programmatic Ollama tool wrappers. This pipeline should consume that vision capability (and the same unload/reload discipline) rather than reinventing it. If the skills task has not landed, implement the minimal Qwen3-VL vision calls needed here and note the overlap.

## First-Slice Decisions & Explicit Deferrals
These close the gaps identified by a fresh-session review of the prior draft:

1. **Model & VRAM**: Treat listed models as starting recommendations. First slice includes a verification pass (load at INT8/GGUF, measure peak VRAM on 16 GB card, confirm native nodes, document staging/unload order). Substitute and note if any fail the budget. No heavy orchestration before this pass. Include Qwen3-VL in the verification set.
2. **Mobile UI**: Stay with existing vanilla HTML/JS/CSS + Python proxy. Add lightweight state (client-side or JSON-file-backed via Python). No framework in first slice.
3. **WIP store**: Versioned JSON files under a new `pipeline/` (or `data/pipeline/`) directory. One file per subject + index. Dirty flags live in the subject record. Git is history.
4. **Condition system**: Pipeline emits simple explicit JSON rule lists (action, scenario, plain-language condition, target). Thin Godot importer turns them into AnimationTree conditions/parameters or dialog checks. JSON is the stable contract.
5. **Paperdoll contract**: Pipeline emits per body type / piece: slot, relative offset (x, y), layering order, optional scale/rotation. Game only consumes the numbers. Placeholder offsets acceptable in first slice; schema required.
6. **Skeletons**: Enemy Items, detailed Biome layout params, Building internal layout, VFX attachment details, Resource recipes, etc. are intentional skeletons. Ship navigation hooks + empty section shells so “Edit this” jumps work. Fill when building real examples. Mark in code.
7. **Export hand-off**: Produce intermediates (or call functions) that current `media.py` key/fit/palette path expects, then invoke existing pack/rekey entry points. Prefer calling existing code.
8. **Heavy preview**: First slice wires existing `shots.py` / `release.py` (or closest) into one “Preview in game” action (temp worktree, pack current set, launch, capture). If messy, ship stills + spritesheet preview first and document the gap; do not block.
9. **Schemas**: First versioned JSON schemas (minimal but explicit) for every subject type, living next to the WIP store. These are the Godot importer contract.
10. **Green-field boundary**: First slice delivers JSON loading, basic paperdoll composition from offsets, condition-driven AnimationTree (or equivalent), and data-driven enemy/item/biome records. Full screens (Enemy Log UI, complete dialog UI, Vylenheim placement logic, etc.) may be stubbed. Success = data-driven and visually correct, old hardcodes no longer required for pipeline assets.
11. **Loose-reference verification**: Successfully ingesting the X post https://x.com/TheKingOfStank/status/2122638614454575113 (or its direct image) and walking it through the full Character flow to a packed, in-game-usable result is part of the done-when criteria.
12. **Style auto-tune**: Include a local-LLM-driven tuning loop that can compare generations against the locked female character artstyle (via Qwen3-VL or equivalent) and iteratively adjust prompts/operational parameters. This loop must be invocable automatically so Grok Build sessions are not required for routine style matching.

## Core Principles
- One pipeline, many subject types and templates
- Staged, 16 GB VRAM-friendly (prefer INT8 / GGUF / sequential unloading)
- Visual generation + structured data + audio references live together
- Templates own default settings and workflow routing
- Everything editable later through the same system
- Immediate dirty-flag propagation and dependency awareness
- Local WIP saves (full working-set snapshots + autosave) vs Export saves (commit to game)
- Full preview path always available (stills, spritesheets, approval queue, and pack-to-worktree + in-game capture). Reuse existing repo tooling.
- Reuse existing repo tools (pack/rekey, media.py, etc.) wherever possible
- Graceful failure reporting (with expandable debug details) and abort handling
- Modular navigation: home “What do you want to work on?” picker; hold-tap/right-click any linked object → “Edit this …” jumps directly into the correct scoped view
- Loose external references are first-class entry points
- Local vision + LLM loops can drive style convergence without constant human micro-management

## Autosave, Save Modes & Review
- Autosave triggers whenever something is generated or changed **and** focus moves elsewhere.
- Local save: full working-set snapshot (current subject + all linked dirty items). Pipeline-only; never touches the game.
- Export save: commits selected changes to the game as the new source of truth.
- Standardized Review step appears at the end of **every** section on save.
- “Potentially dirty” flags are stored and re-displayed (then cleared) the next time the user attempts to regenerate that specific asset.

## Subject Types
Character, NPC, Enemy, Sub-boss, Boss, Equipment, Item, Projectile, Decoration, Resource, UI, Biome, Building, VFX.

### Shared Patterns Across All Subjects
- Selection (create new or template from existing) → Details (name required gate) → domain sections → standardized Review on save → Export (Select / Review / Run).
- Export Select lists every area edited since last export and lets the user pick subsets.
- Bidirectional links everywhere.
- Operational prompts in three layers (Global → Subject-type → Step-specific). All editable in-pipeline. Broad changes show impact warnings.
- Additional prompt layering (especially Characters): character-specific details slot + reusable operational/skill prompt. Per-step override allowed; generic prompt change flags warning (not hard regen).
- Dependency / dirty flagging propagates immediately on Local save.
- Front + side approval lock + programmatic proportion checks where multi-view is used.
- All models configurable/swappable.
- Style-reference images (especially the locked female character set) can be attached to any generation step for conditioning or auto-tune comparison.

## Visual Generation Stack (16 GB staged)
- Stills: Qwen Image 2.1 int8. A reference image can condition the still.
- Body: Hunyuan3D 2.1 from one passing front still. The shape graph is image-only.
- Text edit: `pipeline edit ID --text` draws the change in a Qwen still of the whole body, then Hi3D v1.0 INT8 refines a copy of the kept mesh from that still. The kept body file stays. Hi3D reads the mesh and the image. It does not read the prompt. It will not invent detail the still does not show. Encoders are public DINOv2 Large and CLIP ViT-L/14. Generated meshes can ship. The weights stay on this machine.
- Direct3D-V3 INT8 shape weights for stage 1536 are on disk. Its image encoder is Meta DINOv3. Access is awaiting author review. Leave that node unloaded.
- Pixal3D and TRELLIS.2 are on disk. They rebuild from images and copy the plate.
- Motion: MotionBricks SOMA FP16 is on disk and is not wired.
- Pixel finish is a post step. Ship frames stay 128. Sub-boss default base generation size 2×, Boss 4× (user-adjustable). Final pixel output remains 128×128.
- Vision: Qwen3-VL (`qwen3-vl:8b`) checks the sent prompt, four clauses at a time. The review context is 65536. The reply cap is 16384. A vision pass does not override proportion.
- Tune: `pipeline tune` reviews with Qwen3-VL, restates a miss, and regenerates until the checklist passes or the turn limit.

## Audio
- Placeholder SFX via Stable Audio 3 Small-SFX (native, light, swappable).
- Explicit “placeholder vs recorded” flags.

## Condition System (Animations & Dialog)
Plain-language rules → JSON rule lists → thin Godot importer → AnimationTree conditions/parameters (or dialog checks).  
- Action = shared behavior grouping  
- Scenario = conditional variant  
Examples: “when two-handed axe equipped”, “when health < 30%”, “when quest X complete”, “when player has item Y”.  
Same system for dialog. Non-technical UI.

## Subject Flow Baselines

### Character
Mannequin-first (clean T-pose front+side lock → full views → 3D).  
Sections: Base (Details, Body Shape, Model, Portrait), Customization (Traits with shared categories + relative placement, Defaults, Equipment), Animation (Direction, Picker with Actions+Scenarios, Specialization, Keyframes, Generation), Export.  
8-dir walk minimum. Paperdoll pre-computation in pipeline. Defaults from current art bibles.

#### Loose Reference Ingestion
Users can start from imperfect external references:
- Direct image upload
- Image URL
- X/Twitter post URL (extract attached media)

**Flow**:
1. User supplies the reference (upload, URL, or X post such as https://x.com/TheKingOfStank/status/2122638614454575113).
2. System extracts image(s) (and/or searches for relevant desciption/prompt text in the link) and runs a vision pass (Qwen3-VL) to produce a structural description, suggested mannequin adjustments, and visible traits.
3. User enters the normal Character flow with the reference pinned for side-by-side comparison.
4. Guided (skippable) steps: edit extracted description → generate conditioned front+side mannequin → proportion tweaks → feature extraction into traits → continue through Model, Customization, Animation, Export.
5. Original reference is stored in the subject record.
6. Auto-tune loop may be invoked at any generation step to pull results toward the locked female character artstyle.
7. Dirty-flag and Review behavior identical to standard generation.

Output is always a normal pipeline Character.

Note: This section is intended to be used as a robustness test of the pipeline after everything else has been implemented to test how cleanly the system works with a baseline goal of making a usable character from a vague reference. The supplied link is meant to be the reference to test with.

### NPC
Optional directional + walk (pre-skipped for stationary but reachable). Richer idles, speaking close-ups, facial expressions. Dialog editor with condition system. Loose-reference entry optional.

### Enemy
Equipped-first. Weapons hardcoded.  
Sections: Design, Configuration (Behavior, Stats), Animation (simpler Picker), Items (skeleton), Variants (Alternates, Diversity, Named), Export.  
Loose-reference entry supported.

### Sub-boss / Boss
Separate types. 2× / 4× default base size. Higher detail, states/transformations as described.

### Equipment
Skins, Skills (link to Character scenarios), Compatibility/offsets (Characters only), Stats, Animation Hooks. Enemies excluded.

### Item / Projectile / Decoration / Resource / UI / Biome / Building / VFX
As previously specified. Biome must support future extensibility (e.g. Sky City parallax + open boundaries). Building has first-class Dimensions & Layout. Several detailed subsections are intentional skeletons. Loose-reference ingestion available where it adds value (e.g. Item, Equipment, Decoration).

## Export & Godot Integration (in scope)
- JSON/YAML source of truth + versioned schemas.
- Selective export.
- First-slice consumption: loading, paperdoll from offsets, condition-driven animation, data-driven records. Full new screens may be stubbed.
- Reuse existing pack/rekey/`media.py` by producing expected intermediates or calling existing functions.
- Preview reuses `shots.py` / `release.py` where possible.

## Interface Requirements
Extend existing mobile UI (vanilla JS) into primary modular interface with:
- Home picker
- “Start from reference” action (upload / URL / X post) on Character and other relevant subjects
- Scoped views, “Edit this” jumps
- Always-available Preview
- Standardized Review
- Local vs Export distinction
- Dirty/regen filters
- One-click “Auto-tune to female artstyle” on generation steps

## Constraints
- 16 GB VRAM via staging
- 128×128 integer grid, nearest-neighbor, palette snap, clean alpha
- Prefer native ComfyUI nodes
- Baseline — improve on the fly
- First slice follows the explicit decisions above
- Only one Ollama model active at a time when using the local agent path (unload/reload discipline shared with open-code-skills)

## Deliverables
- Verified model staging notes (including Qwen3-VL)
- Working workflows/orchestration for subject types (skeletons marked)
- Versioned JSON schemas + WIP store
- Updated mobile interface with loose-reference entry and auto-tune controls
- Godot data-consumption path (per first-slice boundary)
- Integration with existing pack/rekey tools
- Test examples of each subject type
- **Female walk proof, before the X post**: an 8-direction female walk generated by this pipeline and presented for review. Compare it with `assets/sprites/player/female/walk_DIRECTION_N.png`. The walk should read as the current in-game female, on model, and continuous instead of the choppy live frames. The modular voxel walk is not part of this pipeline.
- **Verified end-to-end, after the walk proof**: the X post https://x.com/TheKingOfStank/status/2122638614454575113 successfully ingested and walked through the full Character flow to a packed, game-usable result that has been auto-tuned toward the female character artstyle
- Documented deferrals
- Notes on overlap / hand-off with the open-code-skills Qwen3-VL work

## Session

Approved plan: the session `plan.md` for this Build session. Resume from this task, then the art_pipeline door and the job file for the work.

The live rules are `design/art-pipeline.md`, `design/content-pipeline.md`, `design/content-pipeline-mesh.md`, and `design/content-pipeline-ui.md`. A gitignored session log is a local pointer and is not required.

WIP is local until export. `data/pipeline/wip/` is gitignored, including subject JSON. Export (`data/pipeline/export/` plus the sheets it names) is what enters Git. Schemas and the tool code are the system and are committed.

Proof order: female 8-direction walk, presented for review, then the X-post character. Do not start the X-post proof first.

## Live

The kept body is `data/pipeline/wip/gen/female-hunyuan-body.glb` (prompt `bb26c107`, 52936 verts, 1915824 bytes). Do not overwrite it. The female front head minimum on her subject record is 0.73. The edit still `data/pipeline/wip/review/female-edit-head.png` is in that band and its checklist failed, including separated fingers. Do not queue a mesh refine on it. Do not present it. `female-hunyuan-body-edit.glb` does not exist.

The open implementation is the pipeline studio on port 8189. Build that shell from `design/content-pipeline-ui.md`. Do not run `pipeline edit`, `pipeline body`, or `pipeline smooth` on id `female` while building it.

## Progress

- 2026-11-25: Plan approved. Weights are linked and visible to the headless ComfyUI on `127.0.0.1:8188` (local `comfy-mcp`). `python tools/media.py pipeline` is the store CLI. Measure pass is in `design/content-pipeline.md`. A Qwen front still of the locked woman is at `data/pipeline/wip/gen/female-front_00001_.png`. Four keyed bible views produced an equipped Pixal3D body (`female-pixal-4view-tex_00001_.glb`). That mesh is the default loadout reference. The character root is a clean mannequin; hair, neckband, armor, and boots stay modular pieces. The neckband has no tail. The locked mannequin front is the blank `data/pipeline/wip/gen/female-mannequin-front.png` (prompt `43a41238`): eyes may stay, and eyebrows, the nose, and the mouth are later pieces. Block feet fail. `pipeline tune` is the turn-limited review and regenerate loop. Both side tunes passed on turn 1. The four-view featureless rebuild (`918e696e`) has an empty neck band and is not the root. Front and back alone connect into one pillar. Widening only the side necks (`004e9412`) opened a larger gap. A 64-grid pass (`ffec9ef8`) still had an empty neck. A speck above the front head had shortened that plate. `pipeline frame` now keeps the largest mass, and `pipeline mesh` fails a coarse glb with an empty height band. The aligned 32-grid mesh (`a89468e1`) passes that check. It is not a look approval. Shape and texture on those plates finished as prompt `1e889747`. The shape is a standing figure. It is not the walk proof. The painted mannequin mesh failed feet and is not the root. The 32-grid structure path is paused. Four-view Hunyuan surface net (`07176358`) is a fragment cloud and is not the root. `pipeline mesh` fails a fragmented mesh. `pipeline body` builds a Hunyuan3D surface-net mesh from the locked front plate. Prompt `ef7de895` is rejected for those notes. Ears are a later piece. `pipeline smooth` passed a smooth still on turn 2 and built prompt `75f81c41`. That mesh is rejected for the bind pose: the upper arms are bent, the thighs and the feet are together, the abdomen is thick, and the hourglass is missing. The bind pose for every character and enemy is a shared T-pose. Idle is a later animation, not the rest pose. `pipeline smooth` tunes four T-pose bible stills and builds the body from the front only. Prompt `c5f67d50` kept the T-pose and was rejected for scale: the head was too large, and the thighs and calves were too thick. `pipeline proportion` is the size gate. Front and back share head/ribcage 0.75 to 1.20, thigh 0.50, calf 0.32. A lower-head lobe fails as ears. A vision pass does not override it. Prompt `bb26c107` passed that gate and replaced the body (`female-hunyuan-body.glb`, 52936 verts, one piece). It is not a look approval and it is not the walk. Her left side still pointed an arm forward and is not the side lock. Pixel-art stays a post step. The live rules are the art_pipeline job files.
- 2026-11-26: Proportion and the T-pose prompt no longer assume the female body. A subject lists its own measures. Head, thigh, calf, and ears are body measures. Aspect is a general one. Breasts and the hourglass are optional vision checks the subject opts into. The female shape, bands, and checks live on the local female subject until export. The kept mesh was not rebuilt for this.
- 2026-11-26: Qwen3-VL checks the prompt that was sent. Positive sentences must be visible. Comma-separated negative tags must be absent. The asks go out four at a time, then a miss goes back through `pipeline tune`. The clauses are that prompt, so a building does not inherit a body checklist. The kept mesh was not rebuilt for this.
- 2026-11-26: The Bible, I2V, pack, review, and attack-keyframe docs are removed. New art is this pipeline. TRELLIS.2 and both Pixal3D int8 weights were already on disk. A text change is a Qwen still plus a Hi3D v1.0 refine of the kept mesh. Programmatic digits are not the method. The modular voxel walk task and its WIP folder are deleted. The kept body file is not overwritten. Direct3D-V3 shape weights are on disk, and its DINOv3 encoder access is awaiting author review.
- 2026-11-26: `pipeline edit ID --text` is the text-edit command. It writes one Qwen whole-body still, then Hi3D v1.0 refines a copy of the kept mesh into `{id}-hunyuan-body-edit.glb`. The kept body file stays. A failed mesh stays in the review report.
- 2026-11-26: Qwen3-VL review calls use context 8192. One review image and a four-check batch fit in that window. The ask is the checks.
- 2026-11-26: Qwen3-VL review calls use context 65536 and a reply cap of 16384. That uses part of the free VRAM and the model stays on the GPU. A short reply is asked again for the check ids it left out.
- 2026-11-26: The closest female edit still measured front head 0.74, 103 px on a 140 px chest. Later seeds of the same head line measured 0.64 to 0.71. A stronger head line measured 0.70 and failed the thigh maximum.
- 2026-11-26: The female front head minimum is 0.73. The 0.74 still is in band. Its checklist failed the separated-fingers sentence, the head-width sentence, and four other lines. Hi3D has not run. The kept body file stays unchanged.
- 2026-11-27: A back still uses the measures listed for the back view. A later-piece sentence is not a visibility check. A review JSON object in the think trace is parsed when the content has none. The female edit still was not regenerated. The kept body file stays.
- 2026-11-27: The live rules from the session log are in the art_pipeline job files. The open implementation is the pipeline studio (`design/content-pipeline-ui.md`). Weights, the WIP store, Qwen stills, Hunyuan body, the text-edit command, and Qwen3-VL review and tune are in the tool. MotionBricks is on disk and the pipeline does not call it. Capture, pixel finish, the Godot sheet, and the other subject shells are still open. The export index lists no subjects. The finger still stays in review.

## First Actions for a New Session
1. Read this task's Live section, then `design/art-pipeline.md` and the job file for the work.
2. The open implementation is the pipeline studio. Do not rerun a finished phase, and do not refine the female edit still.
3. Update this Live section and Progress when a fact lands.

## Next Steps (User Only)
python tools/slice.py open art_pipeline --task unified-content-pipeline

## UI gaps for Build
Generated by `python tools/media.py studio --gaps` from `tools/lib/media/studio/registry.py`. The full list per type, step and action, with commands, inputs, outputs and setups: [studio-build-gaps](../refs/unified-content-pipeline/studio-build-gaps.md). In real mode each gap answers 501 `not_wired=<seam>` and the page says "not set up yet"; simulate fakes it.

- Actions not wired (13): `reference`, `generate`, `variant`, `icon`, `overlay`, `tile`, `keyframes`, `animate`, `flatanim`, `pixel`, `sheet`, `sound`, `preview`.
- Default recipes to write: 34 type/step pairs.
- Model setups to build or finish (7):
  - `qwen-still` Picture from a description (partial): Qwen Image 2.1 int8, text encoder staged on CPU.
  - `qwen-edit` Change an existing picture (partial): Qwen Image 2.1 int8 edit graph.
  - `motion-8dir` Animate a 3D model in 8 directions (missing): MotionBricks SOMA FP16 (on disk, not wired) + a render pass per facing.
  - `frames-2d` Frames for a flat effect or object (missing): To pick (Wan 2.2 14B stays out).
  - `overlay-fit` Worn and held pictures per facing (missing): Qwen Image edit on the character's facings, or a 3D fit and render.
  - `tile-seamless` Seamless ground and wall tiles (missing): Qwen Image 2.1 int8 with a tiling pass.
  - `stable-audio` Placeholder sound effect (missing): Stable Audio 3 Small-SFX.
- Seams:
  - `dirty-clear`: Clear one hard or soft flag: `store.clear_flag(repo, id, kind, reason)` or `pipeline clear ID --hard|--soft REASON --json` returning `{subject}`.
  - `soft-dirty-clear`: Clear the soft flags a regenerate acknowledged: the same call with `--soft --all`.
  - `export-bypass`: Export with hard flags held: `pipeline export ID --bypass-hard` returning `{path, sections, bypassed:[reasons]}`.
  - `safe-cancel`: Stop a model job at a safe point without killing a pid: a cancel file or `pipeline cancel JOB` that calls `stop_comfyui`.
  - `model-lock`: `pipeline lock --json` returning `{family, holder, since}` so a CLI run and the studio share one model slot, and a `stop_comfyui` hook.
  - `step-locks`: Adopt the studio's step rules in the CLI: `pipeline step ID STEP --finish|--reopen`; actions and section saves need every earlier step Done (a group opens together) and their own step open; a step is Done only when its needs below are met; export needs every step Done and the bypass skips neither gate. Record keys: `studio.steps`, `studio.approvals {path: {state, view, step}}` (state also `hidden`).
  - `step-overrides`: `generate`, `tune`, `smooth`, `body`, `edit` read `studio.overrides[step]` (prompt, negative, seed, strength, steps, width, height) or take the same flags, and echo what they used.
  - `artifacts`: Every command lists what it wrote in `RESULT`/`--json` with the step: `{stills:[], glbs:[], clips:[], sounds:[], review, step}`.
  - `review-latest`: `pipeline review-latest ID --json` returning `[{path, image, role, verdict, checks}]`.
  - `json-lists`: `--json` on `pipeline list`, `show`, `status`, and `coverage`.
  - `export-sections`: Export maps section fields into the contract: `stats`, `dialog`, `audio`, `rules`, `paperdoll`, and `frames`/`sheets` from packed clips; today they are written empty and the fields ride under `sections`.
