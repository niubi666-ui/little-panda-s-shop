extends SceneTree
## Smoke test scene attachment and real pause isolation in the shop and training hosts.
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	for i in 4: await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()
func run() -> void:
	for path in ["res://app/main.tscn", "res://app/action_build_slice.tscn"]:
		var scene: Node = load(path).instantiate()
		root.add_child(scene)
		current_scene = scene
		await settle()
		var overlay: Node = scene.get_node("MapPreview")
		await key(KEY_M)
		check(overlay.opened and paused, path + ": M opens preview")
		check(current_scene == scene, path + ": host scene retained")
		if path.ends_with("action_build_slice.tscn"):
			var position: Vector3 = scene.player.position
			var hp: float = scene.player.health.current
			await key(KEY_W)
			check(scene.player.position == position and scene.player.health.current == hp, "training unchanged while modal paused")
		await key(KEY_ESCAPE)
		check(not overlay.opened and not paused, path + ": Esc restores host")
		current_scene = null
		scene.queue_free()
		await settle()
	print("MAP_PREVIEW_HOSTS failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
