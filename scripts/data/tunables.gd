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
const MAP_ZOOM_MAX := 256.0
## Square minimap side, before HUD scale. 250 is the map that used to sit inside the 350x250 well.
const MINI_PX_MIN := 25.0
const MINI_PX_MAX := 1000.0
const MINI_PX_DEFAULT := 250.0
## 1 shows the whole floor. 8 shows one eighth on each axis. 256 is the tightest crop.
const MINI_ZOOM_MIN := 1.0
const MINI_ZOOM_MAX := 256.0
const MINI_ZOOM_DEFAULT := 8.0
const MINI_BORDER := 3.0
const MAP_DOUBLE_MS := 200
const MOVE_SPEED := 4.5
const MOVE_EPS := 0.12
const PLAYER_H := 1.55
const PLAYER_BODY := Vector3(0.42, 0.78, 0.32)
const WALK_FPS := 8.0
const FEET_LIFT := 0.03
const FLOOR_Y := -0.02
const GROUND_PX_PER_M := 128.0
const GROUND_WEAR := 0.5
const LIGHT_TORCH_RANGE := 5.5
const LIGHT_TORCH_ENERGY := 1.0
const LIGHT_CRYSTAL_RANGE := 7.5
const LIGHT_CRYSTAL_ENERGY := 0.95
const LIGHT_FIRE_RANGE := 6.0
const LIGHT_FIRE_ENERGY := 1.0
const LIGHT_SUN_RANGE := 48.0
const LIGHT_SUN_ENERGY := 0.9
const LIGHT_SOURCE_CAP := 96.0
const WARM_FRAMES_MAX := 6.0
## Hub settle only. Stays behind the loader until two frames are within 16.7 ms, a flat plateau, or this cap.
const WARM_HUB_FRAMES_MAX := 24.0
## Hub plateau reveal: after this many settle frames, the last 3 within WARM_HUB_PLATEAU_REL (+4 ms) of each other.
const WARM_HUB_PLATEAU_MIN := 4.0
const WARM_HUB_PLATEAU_REL := 0.2
const WARM_STEADY_MS := 3.0
const WARM_STEADY_N := 3.0
const DYNRES_ON := true
const DYNRES_FPS_LOW := 40.0
const DYNRES_FPS_HIGH := 55.0
const DYNRES_STEP := 0.1
const DYNRES_MIN := 0.6
const DYNRES_WINDOW_S := 1.5
const DYNRES_RECOVER_WINDOWS := 8
const DYNRES_BACKOFF_MAX := 8
const DYNRES_HITCH_S := 0.5
const FLEE_PACK_MEAN := 4.0
const RENDER_SCALE_OPTS: Array[float] = [0.0, 1.0, 0.8, 0.6]
const WALL_H := 1.45
const ARENA := 22
const PATREON_URL := "https://www.patreon.com/cw/ViraXVespa"
const ARCHIVE_ID_FULL_3D := "full_3d_pass"
const ONE_LINER := "A gamepad-first dungeon crawler where you pilot disposable spirit avatars, mail loot home, and slowly remember the skills you earned in the dark."
const BITTER_YT := "https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW"
const BITTER_SPOTIFY := "https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f"
const BITTER_LOOP_DEFAULT := 15.52
const TOUCH_TAP_WINDOW := 0.28
const TOUCH_DEAD := 0.24

## Slider t 0, 0.5, 1 maps to lo, mid, hi. Each half is geometric, so the default sits in the middle.
static func span_from_t(t: float, lo: float, mid: float, hi: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	if u <= 0.5:
		return lo * pow(mid / lo, u / 0.5)
	return mid * pow(hi / mid, (u - 0.5) / 0.5)

static func t_from_span(v: float, lo: float, mid: float, hi: float) -> float:
	var x: float = clampf(v, lo, hi)
	if x <= mid:
		return 0.5 * clampf(log(x / lo) / log(mid / lo), 0.0, 1.0)
	return 0.5 + 0.5 * clampf(log(x / mid) / log(hi / mid), 0.0, 1.0)

static func snap_mini_zoom(v: float) -> float:
	var z: float = clampf(v, MINI_ZOOM_MIN, MINI_ZOOM_MAX)
	if z >= 100.0:
		return clampf(round(z), MINI_ZOOM_MIN, MINI_ZOOM_MAX)
	if z >= 10.0:
		return clampf(snapped(z, 0.1), MINI_ZOOM_MIN, MINI_ZOOM_MAX)
	return clampf(snapped(z, 0.01), MINI_ZOOM_MIN, MINI_ZOOM_MAX)

## Design size from project.godot (display/window/size): the one place code reads it.
static func base_size() -> Vector2:
	return Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
