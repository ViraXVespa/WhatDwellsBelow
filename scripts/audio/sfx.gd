extends Node

## Appendix E SFX. Gendered VO uses the active character type.

var players: Dictionary = {}
var loop_player: AudioStreamPlayer
var adrenaline_loop := false
var _played := false

## Canonical cue table: id -> file. smoke 9 checks every file here exists.
const FILES := {
	"hit": "res://assets/audio/p2_hit.wav",
	"hit_alt": "res://assets/audio/sfx_hit.wav",
	"crit": "res://assets/audio/p2_crit.wav",
	"slam": "res://assets/audio/p2_slam.wav",
	"slam_alt": "res://assets/audio/sfx_slam.wav",
	"dash": "res://assets/audio/p2_dash.wav",
	"dash_alt": "res://assets/audio/sfx_dash.wav",
	"bolt": "res://assets/audio/p2_bolt.wav",
	"bow": "res://assets/audio/p2_bow.wav",
	"mine": "res://assets/audio/sfx_mine.wav",
	"wood": "res://assets/audio/p9_wood.wav",
	"smash": "res://assets/audio/sfx_smash.wav",
	"pickup": "res://assets/audio/sfx_pickup.wav",
	"ui": "res://assets/audio/sfx_ui.wav",
	"ui_cancel": "res://assets/audio/p9_ui_cancel.wav",
	"potion": "res://assets/audio/p9_potion.wav",
	"food": "res://assets/audio/p9_food.wav",
	"thud": "res://assets/audio/p9_thud.wav",
	"enter": "res://assets/audio/p9_enter.wav",
	"wake": "res://assets/audio/p9_wake.wav",
	"level": "res://assets/audio/p9_level.wav",
	"level_alt": "res://assets/audio/sfx_level.wav",
	"hurt_hit": "res://assets/audio/sfx_hurt.wav",
	"hurt_male": "res://assets/audio/p9_hurt_male.wav",
	"hurt_female": "res://assets/audio/p9_hurt_female.wav",
	"warcry_male": "res://assets/audio/p9_warcry_male.wav",
	"warcry_female": "res://assets/audio/p9_warcry_female.wav",
	"hurk_male": "res://assets/audio/p9_hurk_male.wav",
	"hurk_female": "res://assets/audio/p9_hurk_female.wav",
}
## Cues with a second recording: each play picks one at random (own RNG, so gameplay seeds are untouched).
const ALTS := {"hit": "hit_alt", "slam": "slam_alt", "dash": "dash_alt", "level": "level_alt"}
## Cues that also play an impact layer: the hurt voice plus the body hit.
const LAYERS := {"hurt": "hurt_hit"}
const LOOP_PATH := "res://assets/audio/p2_adrenaline_loop.wav"

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for sfx_id: String in FILES:
		_load(sfx_id, str(FILES[sfx_id]))
	loop_player = AudioStreamPlayer.new()
	if ResourceLoader.exists(LOOP_PATH):
		loop_player.stream = load(LOOP_PATH)
	add_child(loop_player)
	loop_player.finished.connect(_restart_adrenaline)
	_apply_vol()

func _load(sfx_id: String, path: String) -> void:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	add_child(p)
	players[sfx_id] = p

func play(sfx_id: String) -> void:
	_played = true
	_play_key(sfx_id, str(ALTS.get(sfx_id, "")))
	if LAYERS.has(sfx_id):
		_play_key(str(LAYERS[sfx_id]), "")

func _play_key(sfx_id: String, alt: String) -> void:
	var key := _pick_key(sfx_id, alt)
	if _can_play(key):
		_fire(key)
	elif _can_play(sfx_id):
		_fire(sfx_id)

## Voiced cues take the character's variant, a cue with an alt flips a coin onto it, and a missing wood cue falls back to mine.
func _pick_key(sfx_id: String, alt: String) -> String:
	if sfx_id == "hurt" or sfx_id == "warcry" or sfx_id == "hurk":
		return "%s_%s" % [sfx_id, App.character_type]
	if alt != "" and _rng.randf() < 0.5 and _can_play(alt):
		return alt
	if sfx_id == "wood" and not _can_play("wood"):
		return "mine"
	return sfx_id

func _can_play(key: String) -> bool:
	return players.has(key) and players[key].stream != null

func _fire(key: String) -> void:
	_apply_one(players[key])
	players[key].play()

func set_adrenaline(on: bool) -> void:
	if on == adrenaline_loop:
		return
	adrenaline_loop = on
	if on:
		if loop_player.stream:
			_apply_one(loop_player)
			loop_player.play()
	else:
		loop_player.stop()

func _apply_vol() -> void:
	for k in players.keys():
		_apply_one(players[k])
	if loop_player:
		_apply_one(loop_player)

func _apply_one(p: AudioStreamPlayer) -> void:
	p.volume_db = linear_to_db(maxf(0.001, App.vol_sfx * App.vol_master))

func _restart_adrenaline() -> void:
	if App.adrenaline and adrenaline_loop and loop_player.stream and not loop_player.playing:
		loop_player.play()

func _exit_tree() -> void:
	# Stop and let the mixer drain before the tree frees: a hit just before quit otherwise leaves its playback in the AudioServer (leaked at exit).
	for k in players.keys():
		players[k].stop()
	loop_player.stop()
	if _played:
		OS.delay_msec(60)
