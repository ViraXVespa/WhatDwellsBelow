extends Object

const Cat := preload("res://scripts/data/archives_catalog.gd")


static func run(host: Node, id: String) -> void:
	host.archive_cancel = false
	host.archive_job_pid = -1
	var e := Cat.by_id(id)
	var label := str(e.get("label", id))
	if host.loader:
		host.loader.begin(label, "Preparing snapshot…  (B to cancel)")
		host.loader.set_progress(0.02)
	await host.get_tree().process_frame
	if e.is_empty():
		await fail(host, "Unknown archive.")
		return
	if OS.has_feature("web") or not can_spawn_local() or not git_repo() or not have_git():
		await open_pages(host, e)
		return
	var wt := worktree_dir(id)
	var sha := str(e.get("commit", ""))
	if host.archive_cancel:
		await cancel(host)
		return
	if not worktree_ready(wt, sha):
		set_status(host, "Checking out %s…  (B to cancel)" % sha.substr(0, 7), 0.08)
		var ok := await ensure_worktree(host, wt, sha)
		if host.archive_cancel:
			await cancel(host)
			return
		if not ok:
			await fail(host, "Checkout failed.")
			return
	else:
		set_status(host, "Opening snapshot…", 0.4)
		await beat(host, 0.2)
	if host.archive_cancel:
		await cancel(host)
		return
	set_status(host, "Isolating save data…", 0.45)
	stamp_name(wt, label)
	await host.get_tree().process_frame
	if not imported(wt):
		set_status(host, "Importing archived project…  (B to cancel)", 0.48)
		var ok2 := await run_wait(host, OS.get_executable_path(), PackedStringArray(["--headless", "--path", wt, "--import"]), 0.48, 0.9)
		if host.archive_cancel:
			await cancel(host)
			return
		if not ok2 or not imported(wt):
			await fail(host, "Import failed.")
			return
	if host.archive_cancel:
		await cancel(host)
		return
	set_status(host, "Launching…", 1.0)
	await beat(host, 0.15)
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", wt]))
	if pid == -1:
		await fail(host, "Could not launch archive.")
		return
	if host.loader:
		host.loader.finish()
	host._menu_loading = false


static func can_spawn_local() -> bool:
	return not OS.has_feature("web")


static func git_repo() -> bool:
	var root := project_root()
	return DirAccess.dir_exists_absolute(root.path_join(".git")) or FileAccess.file_exists(root.path_join(".git"))


static func have_git() -> bool:
	var out: Array = []
	return OS.execute("git", PackedStringArray(["--version"]), out, true, false) == 0


static func project_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


static func worktree_dir(id: String) -> String:
	return project_root().path_join(".archive_worktrees").path_join(id)


static func imported(wt: String) -> bool:
	return DirAccess.dir_exists_absolute(wt.path_join(".godot"))


static func worktree_ready(wt: String, sha: String) -> bool:
	if not FileAccess.file_exists(wt.path_join("project.godot")):
		return false
	var got := head_sha(wt)
	return got == sha or (got != "" and sha.begins_with(got)) or (got != "" and got.begins_with(sha))


static func head_sha(wt: String) -> String:
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", wt, "rev-parse", "HEAD"]), out, true, false)
	if code != 0 or out.is_empty():
		return ""
	return str(out[0]).strip_edges()


static func ensure_worktree(host: Node, wt: String, sha: String) -> bool:
	var parent := wt.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var root := project_root()
	if DirAccess.dir_exists_absolute(wt):
		OS.execute("git", PackedStringArray(["-C", root, "worktree", "remove", "--force", wt]), [], true, false)
		if DirAccess.dir_exists_absolute(wt):
			rm_dir(wt)
	var args := PackedStringArray(["-C", root, "worktree", "add", "--detach", wt, sha])
	return await run_wait(host, "git", args, 0.08, 0.4) and FileAccess.file_exists(wt.path_join("project.godot"))


static func stamp_name(wt: String, label: String) -> void:
	var p := wt.path_join("project.godot")
	if not FileAccess.file_exists(p):
		return
	var t := FileAccess.get_file_as_string(p)
	var named := "What Dwells Below — " + label
	var re := RegEx.new()
	re.compile("config/name=\"[^\"]*\"")
	t = re.sub(t, "config/name=\"%s\"" % named, false)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(t)


static func run_wait(host: Node, exe: String, args: PackedStringArray, lo: float, hi: float) -> bool:
	var pid := OS.create_process(exe, args)
	if pid == -1:
		return false
	host.archive_job_pid = pid
	var start := Time.get_ticks_msec()
	var span := 120000.0
	while OS.is_process_running(pid):
		if bool(host.archive_cancel):
			OS.kill(pid)
			host.archive_job_pid = -1
			return false
		var u := clampf(float(Time.get_ticks_msec() - start) / span, 0.0, 1.0)
		set_progress(host, lerpf(lo, hi - 0.01, u))
		await host.get_tree().process_frame
	host.archive_job_pid = -1
	return not bool(host.archive_cancel)


static func open_pages(host: Node, e: Dictionary) -> void:
	var url := Cat.pages_url(e)
	if url == "":
		await fail(host, "Could not launch archive.")
		return
	set_status(host, "Opening archived build in a new tab…", 0.55)
	await beat(host, 0.35)
	if host.archive_cancel:
		await cancel(host)
		return
	OS.shell_open(url)
	set_status(host, "Launching…", 1.0)
	await beat(host, 0.2)
	if host.loader:
		host.loader.finish()
	host._menu_loading = false


static func fail(host: Node, msg: String) -> void:
	push_warning(msg)
	host.toast(msg)
	set_status(host, msg, 1.0)
	await beat(host, 0.45)
	if host.loader:
		host.loader.finish()
	host._menu_loading = false
	reopen_browser(host)


static func cancel(host: Node) -> void:
	kill_job(host)
	set_status(host, "Cancelled.", 1.0)
	await beat(host, 0.2)
	if host.loader:
		host.loader.finish()
	host._menu_loading = false
	host.archive_cancel = false
	reopen_browser(host)


static func reopen_browser(host: Node) -> void:
	if host.archives_ui and host.archives_ui.has_method("show_browser"):
		host.archives_ui.show_browser()


static func kill_job(host: Node) -> void:
	var pid := int(host.archive_job_pid)
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	host.archive_job_pid = -1


static func set_status(host: Node, text: String, p: float) -> void:
	if host.loader:
		host.loader.set_status(text)
		host.loader.set_progress(p)


static func set_progress(host: Node, p: float) -> void:
	if host.loader:
		host.loader.set_progress(p)


static func beat(host: Node, sec: float) -> void:
	await host.get_tree().create_timer(sec, true, false, true).timeout


static func rm_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != "..":
			var p := path.path_join(n)
			if d.current_is_dir():
				rm_dir(p)
			else:
				DirAccess.remove_absolute(p)
		n = d.get_next()
	DirAccess.remove_absolute(path)
