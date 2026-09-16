# Audio, visual, splash

Status: binding design + live snapshot  
Read when: music, SFX, splash stills, presentation rules
Code: `scripts/audio/music.gd`, `scripts/audio/sfx.gd`, `scripts/ui/splash.gd`, `scripts/ui/fs_gate.gd`, `scripts/boot.gd`, `scripts/title.gd`, `scripts/world/sprite_filter.gd`, `tools/enable_texture_mips.py`, `.github/workflows/pages.yml`  


## Music

- The primary dungeon music track is the piece titled “Bitter”.
- Authoritative links MUST be referenced in the project for attribution and replacement:
  - YouTube: https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW
  - Spotify: https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f
- First playthrough starts at the beginning of the track, including the full intro.
- The loop point is the **1st beat of the 10th measure**. After that point is reached, subsequent loops MUST start there and MUST NOT replay anything before it.
- The equivalent timestamp of that beat MUST be measured from the supplied master and exposed in the secret debug menu as the loop offset. If the measured time and the score disagree, the score rule (1st beat of measure 10) wins until the User locks a timestamp.
- Volume and crossfade / fade behavior remain tunable.
- Hub music may be any warm, slightly hopeful, lightly comedic stand-in until final assets are created.
- Credit line “Bitter — ViraXVespa” MUST appear on the title screen and in the pause menu where appropriate.

Live default loop offset: `BITTER_LOOP_DEFAULT = 15.52`.

## SFX – minimum required set (Appendix E)

All volumes are controlled by the SFX slider. Additional short UI, weapon-specific, and ambient sounds may be added.

| SFX | Notes |
|-----|-------|
| Melee hit | |
| Player hurt | Separate male and female VO performances of equal scope |
| Special / Slam impact | |
| Dash | |
| Mining hit | |
| Woodcutting hit | |
| Breakable smash | |
| Item pickup | |
| UI click / confirm / cancel | |
| Level-up | |
| Adrenaline Rush start (warcry) | Separate male and female performances of equal scope |
| Adrenaline Rush loop (woosh / crackle) | |
| Critical hit | |
| Potion use | Instant heal; distinct from food |
| Food use | Heal-over-time start; distinct from potion |
| Deathrattle “hurk” | Separate male and female performances of equal scope |
| Comedic thud (“Dispel”) | |
| Consciousness-transfer (enter dungeon) | Short presentation beat |
| Wake-up (return to Placeholdia) | Short presentation beat |

Live files under `assets/audio/` include `sfx_dash`, `sfx_hit`, `sfx_hurt`, `sfx_level`, `sfx_mine`, `sfx_pickup`, `sfx_slam`, `sfx_smash`, `sfx_ui`, plus dungeon/hub music.

## Visual and art rules

- Base resolution for characters and most props: 64×64 pixels.
- Player-facing Sprite3D filter is nearest-neighbor only. System cycles Nearest / Nearest + mips / Nearest + mips + aniso. Default is nearest + mips + anisotropic (`App.sprite_filter = 2`).
- Linear Sprite3D filters exist only on the secret debug Settings tab. They are off-spec for the shipped System menu.
- `project.godot` `default_texture_filter = 0` (nearest) is the **canvas / HUD** default. It does not set Sprite3D filter. Live Sprite3D filter is applied by `sprite_filter.gd` on `node_added` and when the setting changes.
- Mipmaps for 3D world textures (`assets/sprites/`, `assets/tiles/`, `assets/props/`, `assets/fx/`) MUST be baked at import for any web PCK. `tools/enable_texture_mips.py` sets `mipmaps/generate=true` on those texture `.import` files in the **export workspace**. `tools/export_web.ps1` and Pages (`.github/workflows/pages.yml`) run that tool before headless `--import` so the PCK ships the chains. Tracked `.import` files on `main` stay `mipmaps/generate=false`. Do not commit the workspace flip. The script is idempotent. `assets/ui/` stays generate-off (canvas nearest; not Sprite3D).
- Runtime `ensure_mips` is a fallback only. If the texture already has mipmaps, return it. Do not `get_image()` / rebuild on the apply hot path when `has_mipmaps()` is true. `apply_sprite` only calls `ensure_mips` when the current filter uses mips.
- Mip blend Sharp / Smooth is a debug Settings toggle (`use_nearest_mipmap_filter`). Default is Smooth.
- Mip bias is stored for later; Sprite3D has no lod-bias hook yet.
- All characters use Y-billboard so they remain upright under the orthographic camera.
- Character art, 8-dir Bible layout, male/female parity, paper-doll overlays, required body states, and I2V plate law: art_pipeline. Body-state list and idle-still rule: player. Voice-over sets: player and the SFX table above.
- Wall height, tile size (1 unit = 64 px), and depth-sorting SHOULD produce correct layering. Arbitrary popping MUST be avoided wherever possible, but it is not a hard failure if a small amount remains after best-effort sorting.
- Buildings in Placeholdia MUST have actual depth and realistic dimensions.
- Lighting, fog color/density, and void plane MUST create a clear visual contrast between the warmer Placeholdia hub and the colder, darker dungeon floors.
- Consciousness-transfer VFX on dungeon enter and wake-up VFX on return to Placeholdia are required presentation beats.

Live world art (2026-09-09 pass): Placeholdia and dungeon tiles, building facades, hub/dungeon props, hub NPCs, ghost shopkeep, dummy, boss door, and cracked wall were replaced to match the locked player Bibles. Installer `tools/process_world_pass.py`. Key native-resolution stills, then nearest-neighbor fit; do not downscale before chroma key. Player I2V, enemy stills, and UI icons were not in that pass. Placeholder policy below still applies.

## Credit splash → title sequence

- Web export: `boot.tscn` → `fs_gate.tscn` (once per browser session when the gate still wants to show) → `splash.tscn` → title. Desktop and Xbox feature-tag builds skip the gate.
- Existing splash timing may be used as a baseline.
- The credit line MUST be modified so that the word “Proudly” is crossed out and the word “Shamelessly” is written above it in a graffiti style. The final readable phrase is “Shamelessly Vibecoded with Grok.” The graffiti treatment MUST look intentional and vandalized.

Live `splash.gd`: fade in 0.7 s, hold until t = 4.0 s, fade out 0.7 s. Skip with interact / pause / accept / click, then `App.go_title()`.

Live `fs_gate.gd`: title-card layout, platform copy, action + Continue. See ui.

## Placeholder policy

The only assets considered final are:

- The designer’s profile picture
- Official Grok / xAI logos and related assets

Every other sprite, animation, tileset, prop, UI graphic, music track (except the identified “Bitter” reference), and sound effect is placeholder and MUST be replaced or massively updated before the demo is considered shippable.
