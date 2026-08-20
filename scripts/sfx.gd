extends Node

var players: Dictionary = {}
var music: AudioStreamPlayer
var current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	add_child(music)
	for name in ["hit", "slam", "dash", "mine", "smash", "pickup", "ui", "level"]:
		var p := AudioStreamPlayer.new()
		var path := "res://assets/audio/sfx_%s.wav" % name
		if ResourceLoader.exists(path):
			p.stream = load(path)
		add_child(p)
		players[name] = p


func play(name: String) -> void:
	if players.has(name) and players[name].stream:
		players[name].play()


func set_music(which: String) -> void:
	if which == current_music:
		return
	current_music = which
	var path := ""
	if which == "hub":
		path = "res://assets/audio/music_hub.wav"
	elif which == "dungeon":
		path = "res://assets/audio/music_dungeon.wav"
	if path == "" or not ResourceLoader.exists(path):
		music.stop()
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream = stream
	music.volume_db = -8.0
	music.play()


func stop_music() -> void:
	current_music = ""
	music.stop()
