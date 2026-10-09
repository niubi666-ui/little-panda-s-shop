extends SceneTree
## Real viewport inputs exercise the modal against the actual route composition root.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
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
func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()

func run() -> void:
	root.size = Vector2i(1280, 800)
	TranslationServer.set_locale("zh_CN")
	var scene: Node = load("res://app/run_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await settle()
	var overlay: Node = scene.get_node("MapPreview")
	var session_before: String = JSON.stringify(scene.session.snapshot())
	check(not overlay.opened and overlay.plan.is_empty(), "lazy preview has no effect before M")
	await key(KEY_M)
	check(overlay.opened and paused and not overlay.plan.is_empty(), "M opens preview and pauses")
	var plan_before: String = JSON.stringify(overlay.plan)
	var graph: Control = overlay.view.graph
	check(graph.positions.size() == overlay.plan.nodes.size(), "all nodes have displayed positions")
	var bottom: Dictionary = overlay.plan.nodes[0]
	for node in overlay.plan.nodes:
		if node.layer == 0: bottom = node; break
	await click(graph.global_position + graph.positions[bottom.id])
	check(graph.selected == bottom.id, "real click inspects node")
	check(JSON.stringify(scene.session.snapshot()) == session_before and scene.room == null, "inspection leaves session and room unchanged")
	await key(KEY_ESCAPE)
	check(not overlay.opened and not paused and not scene._pause._opened, "Escape closes preview without opening settings")
	await key(KEY_M)
	check(JSON.stringify(overlay.plan) == plan_before, "reopening preserves map")
	await click(overlay.view.new_button.get_global_rect().get_center())
	check(JSON.stringify(overlay.plan) != plan_before, "new map button changes plan")
	check(overlay.generate_seed("panda-preview"), "explicit seed succeeds")
	await settle()
	var fixed: String = JSON.stringify(overlay.plan)
	overlay.new_map()
	overlay.generate_seed("panda-preview")
	check(JSON.stringify(overlay.plan) == fixed, "seed regenerates same plan")
	check(not overlay.generate_seed("   ") and JSON.stringify(overlay.plan) == fixed, "invalid seed preserves previous plan")
	var valid_rules: Dictionary = overlay.rules
	var impossible: Dictionary = valid_rules.duplicate(true)
	impossible.max_attempts = 1
	for kind in impossible.room_types: kind.min_count = 64
	overlay.rules = impossible
	check(not overlay.generate_seed("fail") and JSON.stringify(overlay.plan) == fixed, "failed generation preserves previous plan")
	overlay.rules = valid_rules
	overlay.generate_seed("panda-preview")
	await settle()
	root.size = Vector2i(1440, 900)
	await settle()
	check(JSON.stringify(overlay.plan) == fixed, "viewport resize changes no gameplay plan")
	var entry: Dictionary = overlay.plan.nodes[0]
	for node in overlay.plan.nodes:
		if node.layer == 0: entry = node; break
	overlay.view.scroll.scroll_vertical = int(overlay.view.scroll.get_v_scroll_bar().max_value)
	await settle()
	await click(graph.global_position + graph.positions[entry.id])
	check(graph.selected == entry.id, "real click follows displaced node after resize")
	root.size = Vector2i(1280, 800)
	await settle()
	overlay.view.scroll.scroll_vertical = int(overlay.view.scroll.get_v_scroll_bar().max_value)
	await key(KEY_L)
	check(TranslationServer.get_locale().begins_with("en") and overlay.view._labels.title.text == "Adventure map", "English labels refresh")
	check(overlay.view.close_button.get_global_rect().end.x <= root.size.x, "English toolbar fits viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../builds/map_preview_en.png")
	await key(KEY_L)
	check(overlay.view._labels.title.text == "冒险地图", "Chinese labels refresh")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../builds/map_preview_zh.png")
		overlay.view.scroll.scroll_vertical = 0
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../builds/map_preview_zh_top.png")
		overlay.view.scroll.scroll_vertical = int(overlay.view.scroll.get_v_scroll_bar().max_value / 2.0)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../builds/map_preview_zh_middle.png")
	await click(overlay.view.seed_edit.get_global_rect().get_center())
	await key(KEY_M)
	check(overlay.opened, "typing M in seed does not close map")
	await key(KEY_ESCAPE)
	check(not overlay.opened and not paused, "Escape closes with seed focused")
	await key(KEY_ESCAPE)
	check(scene._pause._opened and paused, "existing settings still opens")
	await key(KEY_M)
	check(not overlay.opened and paused, "M cannot override existing pause modal")
	await key(KEY_ESCAPE)
	check(not scene._pause._opened and not paused, "settings restores state")
	await key(KEY_M)
	check(JSON.stringify(scene.session.snapshot()) == session_before, "preview never mutates RunSession")
	# Destroying an open scene-owned preview must not leave the next scene paused.
	current_scene = null
	scene.queue_free()
	await settle()
	check(not paused, "scene teardown releases owned pause")
	print("MAP_PREVIEW_UI checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
