# Camera and presentation

Status: binding design + live snapshot  
Read when: touching Camera3D, zoom, HUD scale, renderer, or depth sorting  
Code: `scripts/data/tunables.gd`, `scripts/world/camera_rig.gd`, `scripts/input/look_ctrl.gd`, `scripts/app.gd`, `project.godot`  
See also: `design/player.md`, `design/input.md`, `design/archives.md`, `design/audio-visual.md`

## Camera (live 3D path)

- Orthographic Camera3D
- Fixed pitch approximately –58°
- Camera height and ortho size calculated so that 64×64 sprites remain clearly readable
- Player-adjustable zoom range 1.0–4.0 (persisted in save)
- Default zoom 1.75
- Zoom applies live from the System slider (`App.set_zoom` + `camera_rig.follow`)
- World zoom also applies live from mouse wheel, touch pinch (walk stick not claimed), and look-mode right-stick Y
- Separate independent HUD scale setting (System slider and look-mode right-stick X)
- Large-map zoom/pan is a separate view; it MUST NOT change `App.cam_zoom`
- Look-at point offset slightly above the player origin
- Depth sorting SHOULD respect implied real-world positions of the player, enemies, walls, and props. Arbitrary front/back popping MUST be avoided wherever possible, but perfect freedom from popping is not required.

## Presentation switcher

The demo MUST ship with the Archives browser. This is required for the Patreon development narrative. Selecting title “Play” always launches the live path. Catalog rows include Classic 2D, Art experiment, Full 3D Pass, Grok Build Results (Week 1), and Grok Web Results (Week 1). Each row is a pinned commit per `design/archives.md`.

## Renderer

Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.

Sprite3D filter is not the project canvas default. Live default is nearest + mips + anisotropic. System may cycle nearest / nearest+mips / nearest+mips+aniso. Linear modes live only on the secret debug Settings tab. See `design/audio-visual.md` and `design/debug.md`.

## Live snapshot

| Key | Value |
|-----|-------|
| `CAM_PITCH` | -58 |
| `CAM_HEIGHT` | 14 |
| `LOOK_LIFT` | 0.42 |
| `ZOOM_MIN` / `ZOOM_MAX` | 1.0 / 4.0 |
| Default `cam_zoom` | 1.75 |
| `HUD_SCALE_MIN` / `HUD_SCALE_MAX` | 0.7 / 1.4 |
| `LOOK_WHEEL_STEP` | 0.08 |
| `LOOK_PINCH_GAIN` | 1.15 |
| `LOOK_STICK_ZOOM` / `LOOK_STICK_HUD` / `LOOK_STICK_PAN` | 0.9 / 0.35 / 520 |
| `MAP_ZOOM_MIN` / `MAP_ZOOM_MAX` | 1.0 / 10.0 |
| `TILE` / `PX` | 1.0 / 64 |

`project.godot`: viewport 1920×1080, `canvas_items` stretch, aspect `expand`, `default_texture_filter = 0` (nearest, canvas/HUD only), renderer `gl_compatibility`.