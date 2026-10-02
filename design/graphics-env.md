# Graphics env

Status: binding design + live snapshot
Read when: hearth-warm hole-cold Environment, abyss-plinth, caller redirect

`scripts/graphics/env_kit.gd` owns WorldEnvironment plus DirectionalLight3D. Callers: `camp_build.world`, `dungeon_geo.world`, `foundation.gd`.

Live palettes stay. Hub: background (0.45, 0.58, 0.62), warm ambient (0.95, 0.86, 0.7) at 1.15, sun energy 0.9. Dungeon: background (0.03, 0.035, 0.05), cool ambient (0.62, 0.68, 0.74) at 0.85, sun (0.82, 0.88, 0.95) at 0.65. Foundation keeps its own kit literals. Filmic tonemap. `shadow_enabled` stays false.

Depth fog and void color on the two play palettes. Hub haze warm, dungeon pit black. Invented fog numbers go in tunables and the secret debug menu.

Hub daylight in the RT is a wide sun disc (buffer job), not this DirectionalLight casting shadows. Dungeon RT has no sun. Hub lids are unshaded by this kit. Ambient and sun must not second-light a roof or tarp. The bake is the yard light only.

Map reveal is not render fog. Foundation smoke: kit only, no torches, no actor RT.

Do not add OmniLight3D shadow maps here.
