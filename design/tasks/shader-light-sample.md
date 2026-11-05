# Simplify ground/wall light sample (16 fetches → 1 bilinear)

id: shader-light-sample
owner: web
status: open
done-when: ground and wall shaders read the already-baked light texture with a single hardware bilinear sample (or at most a 2×2) instead of the 16-texelFetch loop; hub and dungeon lighting look acceptable to the User; gates pass
resume: start a web session and open the shader-light-sample task

## Background
Hub and dungeon lighting are baked once into a light texture (`light_tex`). The runtime is only supposed to sample that texture.

The ground shader (`scripts/graphics/ground_shader.gd`) and the wall shader (`scripts/graphics/wall_shader.gd`, which calls the same path) currently re-filter the baked texture every fragment:

- A 4-iteration loop over the cell.
- Each iteration does 4 `texelFetch` + manual bilinear mix (`TAP_BODY` / `TAP_MIX`).
- Total: 16 texture operations per fragment, plus extra `hub_sun` / `pool_light` work.

This is the largest remaining fill-rate cost on phone web exports (Compatibility + WebGL). Render-scale experiments already showed that extra blits make things slower, so the per-pixel cost itself must come down.

`HUB_SUB = 16` only controls the hub light-map resolution at bake/load time. Do not change it and do not re-bake. The dungeon uses `SUB = 4`. The sampling waste is independent of those densities.

## Current code locations
- `scripts/graphics/ground_shader.gd` — `TAP_BODY` string and the `for (int t = 0; t < 4; t++)` accumulation into `lit`.
- `scripts/graphics/wall_shader.gd` — uses the same tap.
- Uniforms already present: `light_tex`, `light_origin`, `light_span`.

## Required change
Replace the 16-fetch box-average with one hardware bilinear `texture(light_tex, luv)` (or a minimal 2×2 if a tiny amount of extra softness is still required for acceptance).

Keep `hub_sun`, `pool_light`, feather, and wear unless they are trivial to simplify in the same pass and doing so does not change the look.

Do not alter light-map resolution or the bake pipeline.

## Visual acceptance
- Hub and dungeon must look essentially the same, or only negligibly softer/harder.
- No new light leaks, no missing occlusion, no obvious banding or swimming.
- User must explicitly confirm the look before the task is considered done.

## Prove
- `gate.py` load / import check on the touched shader materials.
- Before/after shots of the hub with a heatmap comparison.
- Scratch prints `RESULT checker=PASS` only after the runner returns 0.
