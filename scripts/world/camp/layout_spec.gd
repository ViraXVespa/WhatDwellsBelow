extends Object

## The hub layout data: every placement, size, asset, light and draw-order number of the camp. Layout (layout.gd) serves
## it; the camp build, the props, the hub bake and the bake overlay (bake_dbg lines) all derive from it. Change a
## number here and everything follows; a box or light change needs a rebake (design/hub-bake.md). design/hub.md.

## Yard in whole tiles (1 m): the fenced slab, the grass pad around it, the packed-dirt yard and the two path arms.
const GROUND := Rect2i(-2, -2, 36, 32)
const GRASS_PAD := 16
const YARD := Rect2i(2, 4, 29, 21)
const PATHS: Array[Rect2i] = [Rect2i(6, 13, 21, 4), Rect2i(15, 8, 3, 15)]
## Fence along the slab edge: run centre height, height, thickness, inset; posts (width, y, spacing, end trim) and the
## two rails (body-local y, thickness x height); art and fallback colour. The bake projects it from the post tops
## (Layout.fence_shadow_top).
const FENCE := {
	"y": 0.58, "h": 1.05, "t": 0.22, "inset": 0.08, "post": 0.18, "post_y": 0.02, "post_step": 2.0, "trim": 0.2,
	"rails": [-0.12, 0.22], "rail": Vector2(0.1, 0.12), "tex": "res://assets/sprites/props/fence.png",
	"col": Color(0.45, 0.32, 0.2),
}
## Ground art: tile texture and fallback colour; feather: fade metres into the surface below (dirt over grass, paths
## over dirt).
const SURFACE := {
	"grass": ["res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24)],
	"dirt": ["res://assets/tiles/packed_dirt.png", Color(0.46, 0.42, 0.30), 1.1],
	"path": ["res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28), 0.8],
}
## Roof tile width (metres per sheet repeat).
const TILE_W := 3.2

## Buildings. pos: body centre (y is reseated from the face art); box: walls; face: front art, crop_top cut off its top;
## rise: gable ridge; lamps: lantern texels in the face art (flame + halo + baked pool); awning: depth (m), valance (fraction of wall height).
const HALL := {
	"pos": Vector3(8.2, 1.7, 6.0), "box": Vector3(5.6, 3.4, 4.2), "face": "res://assets/sprites/buildings/guild.png",
	"crop": 0.32, "rise": 0.55, "wall": Color(0.45, 0.32, 0.22), "awning": Vector2(0.42, 0.16),
	"lamps": [Vector2(99.0, 95.0), Vector2(219.0, 95.0)],
}
## The wing sits on the hall's east end (overlap metres into it), back walls flush. Its crop shows the painted lantern
## above the window (the shingles stay cut off).
const WING := {
	"overlap": 0.12, "box": Vector3(3.8, 3.8, 3.2), "face": "res://assets/sprites/buildings/guild_reception.png",
	"crop": 0.245, "rise": 0.48, "wall": Color(0.5, 0.38, 0.28), "awning": Vector2(0.36, 0.16),
	"lamps": [Vector2(179.5, 101.0)],
}
const TIMBER := Color(0.42, 0.28, 0.16)
## Building face art plane: this fraction of box depth in front of the body centre (stall front posts share it).
const FACE_Z := 0.52
## The awning hem drops this far (m) below the line that meets the face top from the gameplay pitch: no wall shows.
const AWNING_TUCK := 0.03
## Stall: posts at +-posts.x of box.x, front posts.y / rear posts.z of box.z (also the walls, collision, bake lid);
## tarp eave at eave * box.y, ridge rise above it, front drop; counter collision (x, h, z fractions/metres, y);
## plank_m: metres per plank texture repeat on the timber walls.
const STALL := {
	"pos": Vector3(25.0, 1.2, 8.0), "box": Vector3(4.6, 2.4, 3.4), "face": "res://assets/sprites/buildings/stall.png",
	"face_w": 0.96, "wall": Color(0.55, 0.35, 0.2), "post_col": Color(0.36, 0.22, 0.12),
	"posts": Vector3(0.48, FACE_Z, 0.48), "post_half": 0.08, "eave": 0.42, "rise": 0.92, "drop": 0.22,
	"counter": Vector4(0.72, 1.05, 0.46, 0.52), "plank_m": 0.5,
}

## Interact and actor spots (ground points). The vendor stands vendor_gap in front of the stall; the receptionist at
## the wing face (reception offset), reception_h tall.
const SPOTS := {
	"Crystal": Vector3(16.475, 0.0, 10.2), "Anvil": Vector3(21.2, 0.0, 11.4), "Board": Vector3(16.1, 0.0, 6.2),
	"Dumpster": Vector3(5.2, 0.0, 9.4), "Billboard": Vector3(20.5, 0.0, 16.5), "Dummy": Vector3(8.5, 0.0, 15.5),
	"Spawn": Vector3(16.5, 0.0, 16.0), "Banner": Vector3(16.5, 0.0, 22.0),
}
const VENDOR_GAP := 0.5
const RECEPTION := Vector3(0.027, 0.763, 0.07)
const RECEPTION_H := 1.32
## Reception window opening in guild_reception.png px (inside the frame: lintel underside to sill top).
const RECEPTION_WINDOW := Rect2(121, 131, 116, 62)
const RECEPTION_LABEL_Y := 1.5
## Welcome banner: art height; pole feet at +-pole_x (opaque post columns of welcome_banner.png centre at -2.21 / +2.22 m
## at 4.4 m tall); pole collision box.
const BANNER := {"tex": "res://assets/sprites/props/welcome_banner.png", "h": 4.4, "pole_x": 2.2, "pole": Vector3(0.28, 2.2, 0.28)}

## Light: guild lamp flame/halo sizes and the baked warm pool (radius, metres ahead of the lamp, colour); crystal glow
## radius in the bake; the camp environment and sun (EnvKit.apply).
const LAMP := {"flame": Vector2(0.16, 0.28), "halo": 1.2, "pool_r": 1.8, "pool_ahead": 0.6, "pool": Color(1.0, 0.8, 0.5)}
const CRYSTAL_GLOW_R := 4.2
const SUN := {"bg": Color(0.45, 0.58, 0.62), "ambient": Color(0.95, 0.86, 0.7), "ambient_energy": 1.15, "rot": Vector3(-18.0, 34.0, -42.0), "energy": 0.9}

## Draw order (render_priority / sorting_offset) of the hub pieces that are not sorted by Depth.
const DRAW := {"player": 18, "receptionist": 1, "lamp": 2, "tarp": 3, "tarp_sort": 20.0, "post": -1, "post_sort": -5.0}
