# Playtest and animation browser pages for DebugMenu

static func page_playtest(host) -> void:
	host.status.text = "Live AI. Queue closes this menu so the avatar can move. Logs go to user://playtest/runs/"
	host.root_box.add_child(host._btn("Queue full-target batch (6 live runs)", func(): host._start_play(host.play.queue_batch())))
	host.root_box.add_child(host._btn("Queue 1 live — fresh Great Axe", func(): host.play.enqueue({"save": "fresh", "weapon": "great_axe", "tool": "pickaxe", "gender": "male", "scale": App.bal.playtest_scale, "limit": App.bal.playtest_limit, "cfg": {}}); host._start_play("Queued 1.")))
	host.root_box.add_child(host._btn("Queue 1 live — progressed Longbow", func(): host.play.enqueue({"save": "progressed", "weapon": "longbow", "tool": "hatchet", "gender": "female", "scale": App.bal.playtest_scale, "limit": App.bal.playtest_limit, "cfg": {}}); host._start_play("Queued 1.")))
	host.root_box.add_child(host._btn("Interrupt (keep telemetry)", func(): host.play.interrupt(); host.status.text = "Interrupt. Rows kept: %d" % host.play.history.size()))
	host.root_box.add_child(host._btn("Fast seed coefs (Medium bar math)", func(): host.status.text = host.play.run_medium()))
	host.root_box.add_child(Label.new())
	var sum := Label.new()
	sum.text = host.play.last_summary if host.play.last_summary != "" else "No run yet. Queue a live batch or run the fast seed."
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.root_box.add_child(sum)
	host.root_box.add_child(host._btn("Apply fresh ideal", func(): host.status.text = host.play.apply_rec("fresh", 0)))
	host.root_box.add_child(host._btn("Apply fresh alt A", func(): host.status.text = host.play.apply_rec("fresh", 1)))
	host.root_box.add_child(host._btn("Apply fresh alt B", func(): host.status.text = host.play.apply_rec("fresh", 2)))
	host.root_box.add_child(host._btn("Apply progressed ideal", func(): host.status.text = host.play.apply_rec("progressed", 0)))
	host.root_box.add_child(host._btn("Apply progressed alt A", func(): host.status.text = host.play.apply_rec("progressed", 1)))
	host.root_box.add_child(host._btn("Apply progressed alt B", func(): host.status.text = host.play.apply_rec("progressed", 2)))
	host.root_box.add_child(host._btn("Reset progressed save template", func(): host.status.text = host.play.reset_progressed_template()))
	var n := Label.new()
	n.text = "History rows: %d   queue: %d   live: %s" % [host.play.history.size(), host.play.queue.size(), str(host.play.live_running)]
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.root_box.add_child(n)


static func page_anim(host) -> void:
	host.status.text = "Animation Browser. Press A on Open to launch the viewer. B returns to Values."
	var hint := Label.new()
	hint.text = "This tab does not open the viewer by itself. Confirm the prompt below."
	hint.add_theme_font_size_override("font_size", 20)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.root_box.add_child(hint)
	host.root_box.add_child(host._btn("Open Animation Browser", func(): open_anim(host)))


static func open_anim(host) -> void:
	if App.anim_browser and App.anim_browser.has_method("open_browser"):
		App.anim_browser.open_browser()
