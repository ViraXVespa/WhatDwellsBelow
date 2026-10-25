extends RefCounted

## Main tunables (design/tunables.md). Base of the balance vars chain (vars.gd aggregates).
const T := preload("res://scripts/data/tunables.gd")
const Pref := preload("res://scripts/data/save_store/store_data.gd")

var bitter_loop_offset := T.BITTER_LOOP_DEFAULT
var music_fade := 0.35
var playtest_scale := 6.0
var playtest_limit := 90.0

var ground_px_per_m: float = T.GROUND_PX_PER_M
var ground_wear: float = T.GROUND_WEAR
var light_torch_range: float = T.LIGHT_TORCH_RANGE
var light_torch_energy: float = T.LIGHT_TORCH_ENERGY
var light_crystal_range: float = T.LIGHT_CRYSTAL_RANGE
var light_crystal_energy: float = T.LIGHT_CRYSTAL_ENERGY
var light_fire_range: float = T.LIGHT_FIRE_RANGE
var light_fire_energy: float = T.LIGHT_FIRE_ENERGY
var light_sun_range: float = T.LIGHT_SUN_RANGE
var light_sun_energy: float = T.LIGHT_SUN_ENERGY
var light_source_cap: float = T.LIGHT_SOURCE_CAP
var cam_pitch := -58.0
var cam_height := 14.0
var look_lift := 0.42
