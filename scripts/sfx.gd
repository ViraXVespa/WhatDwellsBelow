extends Node

var players: Dictionary = {}
var music: AudioStreamPlayer
var current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	add_child(music)
	for name in ["hit", "slam", "dash", "mine", "smash", "pickup", "ui", "level", "hurt"]:
		var p := AudioStreamPlayer.new()
		var path := "res://assets/audio/sfx_%s.wav" % name
		if ResourceLoader.exists(path):
			p.stream = load(path)
		add_child(p)
		players[name] = p
	apply_volumes()


func apply_volumes() -> void:
	var mv := 0.7
	var sv := 0.85
	if Game.save:
		mv = Game.save.music_vol
		sv = Game.save.sfx_vol
	music.volume_db = linear_to_db(maxf(0.0001, mv)) - 6.0
	if mv <= 0.01:
		music.volume_db = -80.0
	for p in players.values():
		(p as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.0001, sv))
		if sv <= 0.01:
			(p as AudioStreamPlayer).volume_db = -80.0


func play(name: String) -> void:
	apply_volumes()
	if players.has(name) and players[name].stream:
		players[name].play()


# Vira's 8-Bit.mp3: play the intro once, then loop the body.
# 14.85s is one 8-bar phrase at ~130 BPM (opening swell + first statement).
const DUNGEON_LOOP_OFFSET := 14.85


func set_music(which: String) -> void:
	if which == current_music:
		return
	current_music = which
	var path := ""
	if which == "hub":
		path = "res://assets/audio/music_hub.wav"
	elif which == "dungeon":
		if ResourceLoader.exists("res://assets/audio/music_dungeon.mp3"):
			path = "res://assets/audio/music_dungeon.mp3"
		else:
			path = "res://assets/audio/music_dungeon.wav"
	if path == "" or not ResourceLoader.exists(path):
		music.stop()
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
		(stream as AudioStreamMP3).loop_offset = DUNGEON_LOOP_OFFSET
	music.stream = stream
	apply_volumes()
	music.play()


func stop_music() -> void:
	current_music = ""
	music.stop()
