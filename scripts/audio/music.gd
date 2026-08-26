extends Node

## Bitter in the dungeon: full intro (including two-measure fade-in) once,
## then loop from measure 10 beat 1 (~15.52s on the supplied master).

var player: AudioStreamPlayer
var kind := ""
var passed_intro := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	player.finished.connect(_on_finished)
	_apply_vol()


func play_dungeon() -> void:
	kind = "dungeon"
	passed_intro = false
	var path := "res://assets/audio/music_dungeon.mp3"
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music_dungeon.wav"
	if not ResourceLoader.exists(path):
		return
	var s: Resource = load(path)
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	player.stream = s
	_apply_vol()
	player.play(0.0)


func play_hub() -> void:
	kind = "hub"
	passed_intro = true
	var path := "res://assets/audio/music_hub.wav"
	if not ResourceLoader.exists(path):
		return
	var s: Resource = load(path)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = s
	_apply_vol()
	player.play(0.0)


func stop_music() -> void:
	kind = ""
	if player:
		player.stop()


func _apply_vol() -> void:
	if player == null:
		return
	player.volume_db = linear_to_db(maxf(0.001, App.vol_music * App.vol_master))


func loop_offset() -> float:
	return maxf(0.0, App.bal.bitter_loop_offset)


func _on_finished() -> void:
	if kind != "dungeon":
		if kind == "hub" and player.stream:
			player.play(0.0)
		return
	passed_intro = true
	player.play(loop_offset())


func _process(_delta: float) -> void:
	if kind != "dungeon" or player == null or not player.playing:
		return
	if player.get_playback_position() + 0.05 >= loop_offset():
		passed_intro = true
