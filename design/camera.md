# Camera and presentation

Status: current plan  
Read when: Camera3D, zoom, renderer, depth sorting
Code: `scripts/data/tunables.gd`, `scripts/world/camera_rig.gd`, `scripts/world/camp/warm.gd`, `scripts/input/look_ctrl.gd`, `scripts/app.gd`, `project.godot`  

## Camera (live 3D path)

- Orthographic Camera3D
- Fixed pitch approximately –58°
- Camera height and ortho size calculated so that 64×64 sprites remain clearly readable
- Player-adjustable zoom range 1.0–4.0 (persisted in save)
- Default zoom 1.75
- Zoom applies live from Pause → Settings → Graphics (`App.set_zoom` + `camera_rig.follow`)
- World zoom also applies live from mouse wheel, touch pinch (walk stick not claimed), and look-mode right-stick Y
- Separate independent HUD scale setting (Settings → Graphics slider and look-mode right-stick X)
- Large-map zoom/pan is a separate view; it MUST NOT change `App.cam_zoom`
- Look-at point offset slightly above the player origin
- Depth sorting SHOULD respect implied real-world positions of the player, enemies, walls, and props. Arbitrary front/back popping MUST be avoided wherever possible, but perfect freedom from popping is not required.

Title → Play hub warmup MAY set `cam.size` wider than `ZOOM_MIN` so the full Placeholdia slab plus `GRASS_PAD` is on screen under the loader sheet. That size MUST NOT write `App.cam_zoom`. `camera_rig.warm_hold` MUST ignore player `follow` until restore. Restore the user’s zoom and follow target before `loader.finish()`. The player MUST NOT see the pulled-back view.
- Debug camp shots re-apply pose in `_arm_capture` (`capture.gd`) after settle. Zoom `0.69` is the roof-judge crop. It MUST NOT write `App.cam_zoom` for play. The player never keeps that view.
 Extract-wake does not run this.

## Archives

Title-only Archives browser and its rules: archives.

## Renderer

Prefer the Compatibility renderer for the final shippable build if it does not compromise the web export. Mobile renderer is acceptable only if required for web stability.
World env palettes, ground lighting, wall volume, the light RT, and actor sprite shadows are not this door.

Sprite3D filter is not the project canvas default. Live default is nearest + mips + anisotropic. Settings → Graphics exposes Mipmaps and Anisotropic checkboxes (nearest implied; aniso off when mips is off). Linear modes live only on the secret debug Settings tab. See audio_visual and debug.
