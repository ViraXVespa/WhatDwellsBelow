# Build reference images and optional MCPs

Status: protocol
Read when: a Build task needs visual source references or a capability absent from project tools

## Choose the reference path

Use `shots.py review IMAGE --question "..."` for an isolated visual assessment. It returns a text report, not the pixels. Shape, colour and proportion review does not require OCR. Text-reading questions use local OCR first; the staged reviewer enforces the content-bound attempt receipt. Weak, failed or unavailable OCR may use vision. An OCR attempt is not a visual pass.

Use `shots.py show` to show images to the User. It does not give the modeling agent visual context. Keep before/after sheets and the wide-first review in the prove standard.

If the agent must actually see references to perform the task (for example, choosing Blender geometry), use the explicit grant below. It is a project workflow exception, not permission to bypass host security, Auto-review, secret handling or generation policy.

## Grant direct reference reads only when necessary

1. Start the named Build task normally. `slice.py start --task ID` records it in this worktree's slice state. The original session must expose `GROK_SESSION_ID`; a missing or different session id fails closed. Do not manufacture one to obtain access.
2. Select exact image files and state why a text-only review is insufficient. Allowed roots are `assets/`, `_src/`, this task's `design/refs/ID/` and `_logs/references/ID/`. No folders, globs, hidden paths, symlinks, traversal or outside files.
3. Opt in transparently:
   `python tools/slice.py references grant --task ID --reason "Need exact body proportions for the approved model" --path assets/EXACT.png`
   Repeat `--path`, or use `--manifest` from the exporter below. The command does not read images into the conversation.
4. Use the normal direct image-read tool on those files. The grant binds this worktree, original session, active Build task, current unit and file hashes. It expires after two hours. Changed contents, another task/unit/session or a closed/blocked task invalidate it. Renewal requires another explicit grant with a reason.
5. Check with `python tools/slice.py references status`; remove it when finished with `python tools/slice.py references revoke`. The ignored `_logs/reference-access.json` is the local audit record, not a shared approval or a committed policy file.

Granted images are read-only. The grant does not allow Imagine/I2V, shell image readers, arbitrary Python, installations or new permissions. Catalog image tools keep their existing contracts; use the direct read tool, not `cat`, encoding or a cwd change. Text extraction still uses the OCR review path; a visual-reference grant is not a text-review exception. An explicit OCR exception belongs to `shots.py review --why REASON` and its separate staged policy.

## Export native Bible cells and walk references

`python tools/slice.py references export --task ID --bible assets/sprites/player/bible_locked_female.png --walk-dir assets/sprites/player/female --out _logs/references/ID/native`

This copies the accepted full sheet and current `walk_DIRECTION_N.png` frames, and exports the nine named cells at native resolution using the existing sprite layout/image library. It does not key, recolour, denoise, resize, generate or alter live assets. The output folder must be new.

`manifest.json` records task, original paths, source hashes and dimensions, each crop's half-open source coordinates, output dimensions, scale 1 and output hashes. Keep it beside the images. To opt in to that exact bundle, replace `--path` with `--manifest _logs/references/ID/native/manifest.json`. Use selected cells/details rather than reading every frame repeatedly. Full sheet and walk originals remain available for context; exported walk files are frames, not an animated playback proof.

## Blender and Godot MCPs

Vira confirmed on 2026-11-07 that Blender and Godot MCPs are available in her Build environment. This is not a claim that a Bot, isolated child or other environment has those connectors.

Prefer existing repository commands. Use an MCP only when the User/task specifies it, or when an identified capability gap is covered by that MCP. First inspect the current environment's tool list and the relevant live schema; do not invent names, arguments or permissions.

- The modular voxel walk task specifies Blender MCP for modeling. The reference exporter is not a Blender runner, and the Imagine/I2V runner is not a substitute.
- In a perf task, Godot MCP may supply live scene information missing from existing summaries. Keep the repository perf runner and comparable artifacts for timing; scene inspection is not a benchmark or a performance pass.
- If a connector or capability is missing, use a documented repository equivalent when it genuinely covers the need. Otherwise report the exact gap and required setup. Do not start a runtime, install tools, change permissions or fabricate evidence merely because a connector was expected.
