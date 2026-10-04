extends Object

## Human-like touches for the playtester: reaction delay, small aim wobble, no strafe flicker, dodge when hit.
## Every random draw comes from pt.rng, seeded from the run seed, and never touches the global RNG, so a seed replays the same.
## State lives in pt.hum (cleared per run by sim.reset_ai_state).

const REACT := Vector2(0.18, 0.34)  # s from first seeing a foe to acting on it
const RETARGET := Vector2(0.06, 0.14)  # s when switching to another foe mid-fight
const DWELL := 0.9  # s a strafe side is kept before it may flip
const NEAR_NOW := 2.6  # a foe this close is answered at once

static func _seed(pt: Node) -> void:
	if int(pt.hum.get("seed", -1)) != int(App.run_seed):
		pt.hum["seed"] = int(App.run_seed)
		pt.rng.seed = int(App.run_seed) * 7919 + 17

static func reacting(pt: Node, foe: Node, d: float) -> bool:
	_seed(pt)
	var h: Dictionary = pt.hum
	var id: int = foe.get_instance_id()
	if id != int(h.get("foe", 0)):
		var fresh: bool = pt.sim_t - float(h.get("seen_t", -9.0)) > 1.2
		var r: Vector2 = REACT if fresh else RETARGET
		h["foe"] = id
		h["until"] = pt.sim_t + pt.rng.randf_range(r.x, r.y)
	h["seen_t"] = pt.sim_t
	return pt.sim_t < float(h.get("until", 0.0)) and d > NEAR_NOW

static func blur_aim(pt: Node, d: float) -> void:
	# Up to ~3 deg up close, ~4 deg at range, a new wobble every 0.45 s (not per-frame noise).
	var h: Dictionary = pt.hum
	if pt.sim_t >= float(h.get("aim_t", 0.0)):
		h["aim_t"] = pt.sim_t + 0.45
		h["aim_err"] = pt.rng.randf_range(-1.0, 1.0)
	pt.aim = pt.aim.rotated(deg_to_rad((2.5 + minf(d, 8.0) * 0.2) * float(h.get("aim_err", 0.0))))

static func flip_strafe(pt: Node) -> void:
	if pt.sim_t - float(pt.hum.get("flip_t", -9.0)) >= DWELL:
		pt.hum["flip_t"] = pt.sim_t
		pt.strafe_sign *= -1.0

static func dodge(pt: Node, p: Node, foe: Node, d: float) -> void:
	# A hit just landed with the foe on top of us: step away with a dash (cooldown shared with the unstick/crowd dashes).
	var hp: float = float(p.hp) if p.get("hp") != null else 0.0
	var fresh: bool = pt.sim_t - float(pt.hum.get("hp_t", -9.0)) < 0.4
	var lost: float = float(pt.hum.get("hp", hp)) - hp if fresh else 0.0
	pt.hum["hp"] = hp
	pt.hum["hp_t"] = pt.sim_t
	if lost >= 0.07 * maxf(1.0, float(p.max_hp)) and d < 3.2 and not pt.dash:
		var away: Vector2 = pt._safe_step(p, -pt._xz_to(p, foe))
		if away != Vector2.ZERO:
			pt.move = away
			load("res://scripts/debug/playtest_ai/ai_util.gd").want_dash(pt)
