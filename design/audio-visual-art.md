# Visual and art rules

Status: current plan  
Read when: nearest filter modes, mipmap bake, upright actors, lighting contrast, world art  
Code: `scripts/world/sprite_filter.gd`, `tools/release.py mips`, `.github/workflows/pages.yml`

- Base resolution for characters and most props: 64×64 pixels.
- Player-facing Sprite3D filter is nearest-neighbor only. System cycles Nearest / Nearest + mips / Nearest + mips + aniso. Default is nearest + mips + anisotropic (`App.sprite_filter = 2`).
- Linear Sprite3D filters exist only on the secret debug Settings tab. They are off-spec for the shipped System menu.
- `project.godot` `default_texture_filter = 0` (nearest) is the **canvas / HUD** default. It does not set Sprite3D filter. Live Sprite3D filter is applied by `sprite_filter.gd` on `node_added` and when the setting changes.
- Mipmaps for 3D world textures (`assets/sprites/`, `assets/tiles/`, `assets/props/`, `assets/fx/`) MUST be baked at import for any web PCK. `tools/release.py mips` sets `mipmaps/generate=true` on those texture `.import` files in the **export workspace**. `tools/release.py export-web` and Pages (`.github/workflows/pages.yml`) run that tool before headless `--import` so the PCK ships the chains. Tracked `.import` files on `main` stay `mipmaps/generate=false`. Do not commit the workspace flip. The script is idempotent. `assets/ui/` stays generate-off (canvas nearest; not Sprite3D). Detect 3D is off for every texture (`detect_3d/compress_to=0` in each sidecar and in `project.godot` `[importer_defaults]` for new imports), so editor imports never rewrite sidecars; `tools/gate.py gd-load` fails (d3d=) on one that has it on.
- Runtime `ensure_mips` is a fallback only. If the texture already has mipmaps, return it. Do not `get_image()` / rebuild on the apply hot path when `has_mipmaps()` is true. `apply_sprite` only calls `ensure_mips` when the current filter uses mips.
- Mip blend Sharp / Smooth is a debug Settings toggle (`use_nearest_mipmap_filter`). Default is Smooth.
- Mip bias is stored for later; Sprite3D has no lod-bias hook yet.
- All characters use Y-billboard so they remain upright under the orthographic camera.
- Character art, 8 directions, male/female parity, and the shipped paper-doll overlays: content_pipeline. New frames are that pipeline. Body-state list and idle-still rule: player. Voice-over sets: player and the SFX table above.
- Wall height, tile size (128 px per metre), and depth-sorting SHOULD produce correct layering. Arbitrary popping MUST be avoided wherever possible, but it is not a hard failure if a small amount remains after best-effort sorting.
- Buildings in Placeholdia MUST have actual depth and realistic dimensions.
- Lighting, fog color/density, and void plane MUST create a clear visual contrast between the warmer Placeholdia hub and the colder, darker dungeon floors. That contrast is product law. World env, ground shader, wall volume, light RT, and actor shadows belong to the graphics owner.
- Consciousness-transfer VFX on dungeon enter and wake-up VFX on return to Placeholdia are required presentation beats.

World art (Placeholdia and dungeon tiles, facades, props, hub NPCs, ghost shopkeep, dummy, boss door, cracked wall) matches the locked player Bibles. `tools/media.py world` installs it: key native-resolution stills, then nearest-neighbor fit, never downscale before the chroma key. Player I2V, enemy stills and UI icons are separate.
