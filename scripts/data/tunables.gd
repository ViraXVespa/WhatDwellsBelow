extends Object

## Phase 1 starting values. Later phases expose these in the secret debug menu.
const TILE := 1.0
const PX := 64.0
const CAM_PITCH := -58.0
const CAM_HEIGHT := 14.0
const LOOK_LIFT := 0.42
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const HUD_SCALE_MIN := 0.7
const HUD_SCALE_MAX := 1.4
const UI_TEXT_FLOOR := 14.0
const UI_TEXT_FLOOR_MIN := 8.0
const UI_TEXT_FLOOR_MAX := 24.0
const UI_TEXT_REF := 18.0
const UI_TEXT_SCALE_MIN := 1.0
const UI_TEXT_SCALE_MAX := 2.5
const LOOK_WHEEL_STEP := 0.08
const LOOK_PINCH_GAIN := 1.15
const LOOK_STICK_ZOOM := 0.9
const LOOK_STICK_HUD := 0.35
const LOOK_STICK_PAN := 520.0
const MAP_ZOOM_MIN := 1.0
const MAP_ZOOM_MAX := 10.0
const MOVE_SPEED := 4.5
const MOVE_EPS := 0.12
const PLAYER_H := 1.55
const PLAYER_BODY := Vector3(0.42, 0.78, 0.32)
const WALK_FPS := 8.0
const FEET_LIFT := 0.03
const FLOOR_Y := -0.02
const GROUND_PX_PER_M := 128.0
const GROUND_HASH_M := 4.0
const GROUND_VARIANTS := 3.0
const GROUND_WEAR := 0.22
const LIGHT_TORCH_RANGE := 5.5
const LIGHT_TORCH_ENERGY := 1.0
const LIGHT_CRYSTAL_RANGE := 7.5
const LIGHT_CRYSTAL_ENERGY := 0.95
const LIGHT_FIRE_RANGE := 6.0
const LIGHT_FIRE_ENERGY := 1.0
const LIGHT_SUN_RANGE := 48.0
const LIGHT_SUN_ENERGY := 0.9
const LIGHT_SOURCE_CAP := 24.0
const WALL_H := 1.45
const ARENA := 22
const PATREON_URL := "https://www.patreon.com/cw/ViraXVespa"
const ARCHIVE_ID_FULL_3D := "full_3d_pass"
const ARCHIVE_LABEL_FULL_3D := "Full 3D Pass"
const ONE_LINER := "A gamepad-first dungeon crawler where you pilot disposable spirit avatars, mail loot home, and slowly remember the skills you earned in the dark."
const BITTER_YT := "https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW"
const BITTER_SPOTIFY := "https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f"
const BITTER_LOOP_DEFAULT := 15.52
const TOUCH_TAP_WINDOW := 0.28
const TOUCH_DEAD := 0.24


static func archive_catalog() -> Array:
	return load("res://scripts/data/archives_catalog.gd").all()
