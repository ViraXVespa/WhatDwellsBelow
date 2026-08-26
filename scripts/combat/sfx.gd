extends Node

## Appendix E SFX. Gendered VO uses the active character type.

var players: Dictionary = {}
var loop_player: AudioStreamPlayer
var adrenaline_loop := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load("hit", "res://assets/audio/p2_hit.wav")
	_load("crit", "res://assets/audio/p2_crit.wav")
	_load("slam", "res://assets/audio/p2_slam.wav")
	_load("dash", "res://assets/audio/p2_dash.wav")
	_load("bolt", "res://assets/audio/p2_bolt.wav")
	_load("bow", "res://assets/audio/p2_bow.wav")
	_load("mine", "res://assets/audio/sfx_mine.wav")
	_load("wood", "res://assets/audio/p9_wood.wav")
	_load("smash", "res://assets/audio/sfx_smash.wav")
	_load("pickup", "res://assets/audio/sfx_pickup.wav")
	_load("ui", "res://assets/audio/sfx_ui.wav")
	_load("ui_cancel", "res://assets/audio/p9_ui_cancel.wav")
	_load("potion", "res://assets/audio/p9_potion.wav")
	_load("food", "res://assets/audio/p9_food.wav")
	_load("thud", "res://assets/audio/p9_thud.wav")
	_load("enter", "res://assets/audio/p9_enter.wav")
	_load("wake", "res://assets/audio/p9_wake.wav")
	_load("level", "res://assets/audio/p9_level.wav")
	_load("hurt_male", "res://assets/audio/p9_hurt_male.wav")
	_load("hurt_female", "res://assets/audio/p9_hurt_female.wav")
	_load("warcry_male", "res://assets/audio/p9_warcry_male.wav")
	_load("warcry_female", "res://assets/audio/p9_warcry_female.wav")
	_load("hurk_male", "res://assets/audio/p9_hurk_male.wav")
	_load("hurk_female", "res://assets/audio/p9_hurk_female.wav")
	if not players.has("hurt_male"):
		_load("hurt_male", "res://assets/audio/sfx_hurt.wav")
	if not players.has("warcry_male"):
		_load("warcry_male", "res://assets/audio/p2_warcry.wav")
	loop_player = AudioStreamPlayer.new()
	var lp := "res://assets/audio/p2_adrenaline_loop.wav"
	if ResourceLoader.exists(lp):
		loop_player.stream = load(lp)
	add_child(loop_player)
	_apply_vol()


func _load(name: String, path: String) -> void:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	add_child(p)
	players[name] = p


func play(name: String) -> void:
	var key := name
	if name == "hurt" or name == "warcry" or name == "hurk":
		key = "%s_%s" % [name, App.character_type]
	elif name == "wood" and (not players.has("wood") or players["wood"].stream == null):
		key = "mine"
	if players.has(key) and players[key].stream:
		_apply_one(players[key])
		players[key].play()
	elif players.has(name) and players[name].stream:
		_apply_one(players[name])
		players[name].play()


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
