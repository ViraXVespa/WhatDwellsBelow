extends Object

## Shared steps of the scene legs (title -> Placeholdia, Placeholdia -> dungeon, dungeon -> Placeholdia).
## Owner: app_flow.gd / app_run.gd. Only the steps the legs really repeat live here.

## Deferred scene change (packed when loaded, else by path), then wake the web pad on the new scene.
static func change_scene(host: Node, packed: PackedScene, path: String) -> void:
	if packed != null:
		host.get_tree().call_deferred("change_scene_to_packed", packed)
	else:
		host.get_tree().call_deferred("change_scene_to_file", path)
	host.call_deferred("wake_web_pad")

## Wait (at most 240 frames) until the current scene is ready and is `stem` (file path contains it, or the
## node is named `node_name`). on_wait runs before each waited frame. Returns the frames counted.
static func wait_scene(host: Node, stem: String, node_name: String, on_wait: Callable = Callable()) -> int:
	var guard: int = 0
	while guard < 240:
		guard += 1
		var s: Node = host.get_tree().current_scene
		if s and s.is_node_ready() and (str(s.scene_file_path).find(stem) >= 0 or str(s.name) == node_name):
			break
		if on_wait.is_valid():
			on_wait.call()
		await host.get_tree().process_frame
	return guard
