# Camera and presentation

Status: binding design + live snapshot
Read when: touching Camera3D, zoom, HUD scale, renderer, or depth sorting
Code: `scripts/data/tunables.gd`, `scripts/world/camera_rig.gd`, `project.godot`
See also: `design/player.md`, `design/archives.md`

## Camera (live 3D path)

- Orthographic Camera3D
- Fixed pitch approximately –58°
- Camera height and ortho size calculated so that 64×64 sprites remain clearly readable
- Player-adjustable zoom range 1.0–1.75 (persisted in save)
- Separate independent HUD scale setting
- Look-at point offset slightly above the player origin
- Depth sorting SHOULD respect implied real-world positions of the player, enemies, walls, and props. Arbitrary front/back popping MUST be avoided wherever possible, but perfect freedom from popping is not required.

## Presentation switcher

The demo MUST ship with the existing presentation switcher (live / classic_2d / art_experiment) plus the Archives system. This is required for the Patreon development narrative. Selecting “Play” always launches the live path. The Archives browser also includes **`full_3d_pass`** (on-screen label **Full 3D Pass**), the isolated snapshot of the previous live path already stored under `archives/full_3d_pass/`. classic_2d, art_experiment, and full_3d_pass remain standalone archives per `design/archives.md`.

## Renderer

Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.

## Live snapshot

| Key | Value |
|-----|-------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 1.75 |
| `TILE` / `PX` | 1.0 / 64 |

`project.godot`: viewport 1920×1080, `canvas_items` stretch, aspect `expand`, `default_texture_filter = 0` (nearest), renderer `gl_compatibility`.