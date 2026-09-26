# Graphics env

Status: binding design + live snapshot
Read when: hearth-warm hole-cold Environment, abyss-plinth, caller redirect

One helper owns WorldEnvironment plus DirectionalLight3D for Placeholdia, the dungeon, and foundation.

Live palettes stay. Hub: background (0.45, 0.58, 0.62), warm ambient (0.95, 0.86, 0.7) at 1.15, sun energy 0.9. Dungeon: background (0.03, 0.035, 0.05), cool ambient (0.62, 0.68, 0.74) at 0.85, sun (0.82, 0.88, 0.95) at 0.65. Foundation uses the dungeon kit. Filmic tonemap. `shadow_enabled` stays false.

Callers: `camp_build.world`, `dungeon_geo.world`, `foundation.gd`. After reuse they call `scripts/graphics/` instead of copying the block.

Map reveal is not render fog. Depth fog and void color on these two palettes are the first visible env add. Invented fog numbers go in tunables and the secret debug menu.

Do not add OmniLight3D shadow maps here.
