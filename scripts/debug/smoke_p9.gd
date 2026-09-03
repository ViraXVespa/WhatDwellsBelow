extends Object

const Roster := preload("res://scripts/combat/roster.gd")
const EnemyS := preload("res://scripts/combat/enemy.gd")
const AnimS := preload("res://scripts/debug/anim_browser.gd")
const T := preload("res://scripts/data/tunables.gd")
const CatS := preload("res://scripts/data/archives_catalog.gd")


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func p9(host: Node) -> void:
	var player: Variant = host.get("player")
	printerr("P9: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P9: bitter_loop=" + str(App.bal.bitter_loop_offset))
	printerr("P9: bitter_yt=" + str(T.BITTER_YT != ""))
	printerr("P9: bitter_spotify=" + str(T.BITTER_SPOTIFY != ""))
	var mus: bool = false
	if App.music:
		mus = str(App.music.get("kind")) == "dungeon"
	printerr("P9: dungeon_music=" + str(mus))
	var sfx_need: PackedStringArray = PackedStringArray(["p9_potion.wav", "p9_food.wav", "p9_wood.wav", "p9_thud.wav", "p9_enter.wav", "p9_wake.wav", "p9_hurt_male.wav", "p9_hurt_female.wav", "p9_warcry_male.wav", "p9_warcry_female.wav", "p9_hurk_male.wav", "p9_hurk_female.wav"])
	var sfx_ok: bool = true
	for n: String in sfx_need:
		if not ResourceLoader.exists("res://assets/audio/" + n) and not FileAccess.file_exists("res://assets/audio/" + n):
			sfx_ok = false
	printerr("P9: sfx_ok=" + str(sfx_ok))
	var models: Array = AnimS.catalog_models()
	printerr("P9: anim_models=" + str(models.size()))
	var need_ids: PackedStringArray = PackedStringArray(["player_male", "player_female", "slime", "guardian", "gate_master"])
	var model_ok: bool = true
	for id: String in need_ids:
		var found: bool = false
		for m: Variant in models:
			if str(m.id) == id:
				found = true
		if not found:
			model_ok = false
	printerr("P9: anim_browser_ok=" + str(models.size() >= 16 and model_ok))
	if App.anim_browser and App.anim_browser.has_method("open_browser"):
		App.anim_browser.open_browser()
		printerr("P9: anim_open=" + str(App.anim_browser.open) + " focus=" + str(App.anim_browser.back_btn != null))
		App.anim_browser.close_browser()
	if App.archives_ui and App.archives_ui.has_method("show_browser"):
		App.archives_ui.show_browser()
		printerr("P9: archives_ui=" + str(App.archives_ui.open) + " entries=" + str(App.archives_ui.entries.size()))
		App.archives_ui.hide_browser()
	printerr("P9: arch_n=" + str(CatS.all().size()))
	printerr("P9: arch_full=" + str(not CatS.by_id("full_3d_pass").is_empty()))
	printerr("P9: arch_classic=" + str(not CatS.by_id("classic_2d").is_empty()))
	printerr("P9: arch_art=" + str(not CatS.by_id("art_experiment").is_empty()))
	var sum: String = App.debug.play.run_medium()
	printerr("P9: playtest=" + sum.replace("\n", " | "))
	var extra: int = 0
	if player:
		for i: int in 24:
			var e: Node = EnemyS.new()
			e.position = player.position + Vector3(float(i % 6) * 0.7, 0.0, float(int(i) / 6) * 0.7)
			host.add_child(e)
			e.setup(Roster.IDS[i % Roster.IDS.size()], App.floor_n)
			extra += 1
	printerr("P9: load_extra=" + str(extra))
	if App.playtest and App.playtest.has_method("begin_smoke"):
		App.playtest.begin_smoke()
	var skills: int = App.prog.SKILLS.size()
	printerr("P9: skills=" + str(skills) + " sets=" + str(App.prog.SETS.size()))
	printerr("P9: splash=" + str(ResourceLoader.exists("res://scenes/splash.tscn")))
	tree(host).create_timer(1.2, true, false, true).timeout.connect(func():
		var fps: float = Engine.get_frames_per_second()
		printerr("P9: fps=" + str(fps))
		printerr("P9: fps_ok=" + str(fps >= 55.0 or fps <= 5.0 or fps > 200.0))
		printerr("P9: bitter_ok=" + str(App.bal.bitter_loop_offset > 15.0 and App.bal.bitter_loop_offset < 16.0))
		printerr("P9: checklist_skills=" + str(skills == 11))
		printerr("P9: checklist_sets=" + str(App.prog.SETS.size() == 8))
		printerr("P9: archives_ok=" + str(CatS.ok()))
		if App.playtest:
			printerr("P9: playtest_live=" + str(App.playtest.live_running))
			printerr("P9: playtest_moved=" + str(App.playtest.moved))
			printerr("P9: playtest_sim=" + str(snapped(App.playtest.sim_t, 0.01)))
			printerr("P9: playtest_live_ok=" + str(App.playtest.moved or App.playtest.sim_t > 0.2))
		tree(host).quit()
	)
