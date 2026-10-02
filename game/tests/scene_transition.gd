extends SceneTree
const Transition = preload("res://app/scene_transition.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var failures: Array[String] = []
var measurements: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func wait_for_transition(operation: Node, capture := false) -> void:
	var frames := 0
	var worst_frame_ms := 0.0
	var deadline := Time.get_ticks_msec() + 60000
	while is_instance_valid(operation) and operation.stage not in ["complete", "failed"]:
		var stamp := Time.get_ticks_usec()
		await process_frame
		worst_frame_ms = maxf(worst_frame_ms, (Time.get_ticks_usec() - stamp) / 1000.0)
		frames += 1
		if capture and frames == 3 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("E:/ShopGame/builds/loading_progress.png")
		if Time.get_ticks_msec() > deadline:
			check(false, "transition timeout")
			quit(1)
			return
	check(not paused and not root.disable_3d, "transition restores pause and 3D rendering")
	measurements.append({"frames_during_transition":frames,"worst_frame_ms":worst_frame_ms})
	await process_frame
func run() -> void:
	var shop = load("res://app/main.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	TranslationServer.set_locale("zh_CN")
	await create_timer(0.5).timeout
	shop._enter_training()
	var operation: Node = shop._transition
	shop._enter_training()
	check(shop._transition == operation, "duplicate input keeps one transition")
	check(paused and root.disable_3d, "outgoing gameplay frozen while loading")
	await wait_for_transition(operation, true)
	check(current_scene.scene_file_path == "res://app/combat_training.tscn", "shop to battle")
	check(current_scene.builds.is_choosing(), "opening choice preserved")
	# Repeated retries must leave exactly one playable root and restore pause state.
	for i in 4:
		current_scene._retry()
		operation = current_scene._transition
		await wait_for_transition(operation)
		check(current_scene.builds.session.snapshot()["ranks"].is_empty(), "retry resets build")
		check(root.find_children("SceneTransition*", "", false, false).is_empty(), "transition owner released")
	current_scene._return()
	await wait_for_transition(current_scene._transition)
	check(current_scene.scene_file_path == "res://app/main.tscn", "battle to shop")
	var old_scene := current_scene
	operation = Transition.begin(self, "res://tests/does_not_exist.tscn", ThemeFactory.create())
	while operation.stage != "failed": await process_frame
	check(current_scene == old_scene, "failed load preserves outgoing scene")
	var status: Label = operation.view.get_node("Screen/Center/Panel/Margin/Content/Status")
	check(status.text == tr("loading.failed") and not status.text.begins_with("loading."), "Chinese error translated")
	TranslationServer.set_locale("en")
	await process_frame
	check(status.text == tr("loading.failed") and status.text.contains("Unable"), "English error translated")
	operation.view.dismiss_requested.emit()
	await process_frame
	await process_frame
	check(current_scene == old_scene and not paused and not root.disable_3d, "dismiss restores old scene")
	var report := {"failures":failures,"measurements":measurements}
	var output := FileAccess.open("E:/ShopGame/builds/loading_transition_test.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("SCENE_TRANSITION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
