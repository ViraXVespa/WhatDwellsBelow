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
	var key := sfx_id
	if sfx_id == "hurt" or sfx_id == "warcry" or sfx_id == "hurk":
		key = "%s_%s" % [sfx_id, App.character_type]
	elif alt != "" and _rng.randf() < 0.5 and players.has(alt) and players[alt].stream:
		key = alt
	elif sfx_id == "wood" and (not players.has("wood") or players["wood"].stream == null):
		key = "mine"
	if players.has(key) and players[key].stream:
		_apply_one(players[key])
		players[key].play()
	elif players.has(sfx_id) and players[sfx_id].stream:
		_apply_one(players[sfx_id])
		players[sfx_id].play()

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

func _process(_delta: float) -> void:
	if adrenaline_loop and loop_player.stream and not loop_player.playing:
		loop_player.play()

func _exit_tree() -> void:
	# Stop and let the mixer drain before the tree frees: a hit just before quit otherwise leaves its playback in the AudioServer (leaked at exit).
	for k in players.keys():
		players[k].stop()
	loop_player.stop()
	if _played:
		OS.delay_msec(60)
