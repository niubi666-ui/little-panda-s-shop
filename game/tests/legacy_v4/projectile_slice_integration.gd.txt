extends SceneTree
var failures: Array[String] = []
var arena
var done := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	create_timer(60.0).timeout.connect(func():
		if not done:
			failures.append("integration timeout")
			finish())
	arena = load("res://app/projectile_slice.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	arena.set_physics_process(false)
	var hint: Label = arena.get_node("UIRoot/ArrowHint")
	check(hint.text != "build.test.arrow_hint", "initial hint is translated after catalog registration")
	var language := InputEventAction.new()
	language.action = "toggle_language"
	language.pressed = true
	var original_text := hint.text
	arena._unhandled_input(language)
	check(hint.text != original_text and hint.text != "build.test.arrow_hint", "hint follows bilingual refresh")
	arena._unhandled_input(language)
	check(arena.builds.catalog != null, "slice initializes catalog")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	arena.builds.handle_test_input(press)
	check(arena.builds.runtime.diagnostics().queued == 0, "modal blocks test arrow input")
	# Real button signals -> application transaction -> runtime program. No window-focus dependency.
	for i in 14:
		if not arena.builds.is_choosing(): arena.builds.request_test_offer()
		await process_frame
		await process_frame
		var buttons: Dictionary = arena.builds.choice_panel.buttons
		if buttons.has("split"):
			buttons.split.pressed.emit()
			break
		var chosen := ""
		for id in buttons:
			if id != "wave":
				chosen = id
				break
		if chosen.is_empty():
			check(false, "no non-wave progress candidate")
			break
		buttons[chosen].pressed.emit()
	var ranks: Dictionary = arena.builds.session.snapshot().ranks
	check(ranks.has("split") and not ranks.has("wave"), "slice acquires split through UI with no sword wave")
	arena.player.cancel()
	arena.player.clear_intents()
	root.gui_release_focus()
	root.push_input(press, true)
	await process_frame
	arena.builds.step(0.001)
	check(arena.builds.runtime.projectiles().size() == 1, "test input emits one arrow")
	arena.builds.refresh(0.0)
	check(arena.builds.effects.get_child_count() > 0, "presentation accepts definition snapshot and arrow mesh")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/projectile_slice.png")
	arena.builds.clear_room()
	await process_frame
	await process_frame
	finish()
func finish() -> void:
	if done: return
	done = true
	if is_instance_valid(arena): arena.queue_free()
	await process_frame
	print("PROJECTILE_SLICE_INTEGRATION ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
